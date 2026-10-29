import Foundation
import llama

public enum EngineError: LocalizedError {
    case modelLoadFailed, contextFailed, promptTooLong, decodeFailed

    public var errorDescription: String? {
        switch self {
        case .modelLoadFailed: "The model couldn't be loaded. It may need more memory than this phone has free."
        case .contextFailed: "Couldn't set up the model's working memory. Try the Battery saver preset."
        case .promptTooLong: "That message is too long for the current settings."
        case .decodeFailed: "The model stopped unexpectedly."
        }
    }
}

/// Runs one GGUF model with llama.cpp. Generation blocks its executor, so one answer is
/// produced at a time; cancel the stream's task to stop early.
public actor LlamaEngine {
    nonisolated(unsafe) private let model: OpaquePointer
    nonisolated(unsafe) private let context: OpaquePointer
    nonisolated(unsafe) private let sampler: UnsafeMutablePointer<llama_sampler>
    nonisolated(unsafe) private let vocab: OpaquePointer
    private let contextLength: Int
    private let batchSize = 512

    private static let backendReady: Void = {
        llama_backend_init()
        llama_log_set({ _, _, _ in }, nil)
    }()

    /// Loads off the main thread, since reading a large model takes seconds.
    public static func load(modelURL: URL, contextLength: Int, useGPU: Bool) async throws -> LlamaEngine {
        try await Task.detached(priority: .userInitiated) {
            try LlamaEngine(modelURL: modelURL, contextLength: contextLength, useGPU: useGPU)
        }.value
    }

    private init(modelURL: URL, contextLength: Int, useGPU: Bool) throws {
        _ = Self.backendReady
        var modelParams = llama_model_default_params()
        modelParams.n_gpu_layers = useGPU ? 99 : 0
        guard let model = llama_model_load_from_file(modelURL.path, modelParams) else {
            throw EngineError.modelLoadFailed
        }

        var contextParams = llama_context_default_params()
        contextParams.n_ctx = UInt32(contextLength)
        contextParams.n_batch = UInt32(batchSize)
        let threads = Int32(max(2, min(6, ProcessInfo.processInfo.activeProcessorCount - 2)))
        contextParams.n_threads = threads
        contextParams.n_threads_batch = threads
        guard let context = llama_init_from_model(model, contextParams) else {
            llama_model_free(model)
            throw EngineError.contextFailed
        }

        let chain = llama_sampler_chain_init(llama_sampler_chain_default_params())!
        llama_sampler_chain_add(chain, llama_sampler_init_top_k(20))
        llama_sampler_chain_add(chain, llama_sampler_init_top_p(0.8, 1))
        llama_sampler_chain_add(chain, llama_sampler_init_temp(0.5))
        llama_sampler_chain_add(chain, llama_sampler_init_dist(UInt32.random(in: 0...UInt32.max)))

        self.model = model
        self.context = context
        self.sampler = chain
        self.vocab = llama_model_get_vocab(model)!
        self.contextLength = contextLength
    }

    deinit {
        llama_sampler_free(sampler)
        llama_free(context)
        llama_model_free(model)
    }

    /// Streams the reply text as it is produced.
    public nonisolated func generate(messages: [ChatMessage], maxTokens: Int) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            let task = Task.detached(priority: .userInitiated) {
                do {
                    try await self.run(messages, maxTokens: maxTokens, output: continuation)
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    private func run(_ messages: [ChatMessage], maxTokens: Int,
                     output: AsyncThrowingStream<String, Error>.Continuation) throws {
        var history = messages
        var tokens = try tokenize(ChatFormat.prompt(for: history))
        let budget = contextLength - maxTokens
        // Drop the oldest turns until the prompt leaves room for the answer.
        while tokens.count > budget, history.count > 1 {
            history.removeFirst()
            tokens = try tokenize(ChatFormat.prompt(for: history))
        }
        guard tokens.count <= budget else { throw EngineError.promptTooLong }

        llama_memory_clear(llama_get_memory(context), true)
        llama_sampler_reset(sampler)

        var offset = 0
        while offset < tokens.count {
            if Task.isCancelled { return }
            let count = min(batchSize, tokens.count - offset)
            let status = tokens.withUnsafeMutableBufferPointer { buffer in
                llama_decode(context, llama_batch_get_one(buffer.baseAddress! + offset, Int32(count)))
            }
            guard status == 0 else { throw EngineError.decodeFailed }
            offset += count
        }

        var pending = Data()
        for _ in 0..<maxTokens {
            if Task.isCancelled { break }
            var token = llama_sampler_sample(sampler, context, -1)
            if llama_vocab_is_eog(vocab, token) { break }
            pending.append(piece(for: token))
            let text = ChatFormat.takeValidUTF8(from: &pending)
            if !text.isEmpty { output.yield(text) }
            guard llama_decode(context, llama_batch_get_one(&token, 1)) == 0 else {
                throw EngineError.decodeFailed
            }
        }
        if !pending.isEmpty { output.yield(String(decoding: pending, as: UTF8.self)) }
    }

    private func tokenize(_ text: String) throws -> [llama_token] {
        let utf8 = Array(text.utf8)
        var tokens = [llama_token](repeating: 0, count: utf8.count + 16)
        var count = utf8.withUnsafeBufferPointer { bytes in
            bytes.withMemoryRebound(to: CChar.self) { chars in
                llama_tokenize(vocab, chars.baseAddress, Int32(chars.count), &tokens, Int32(tokens.count), false, true)
            }
        }
        if count < 0 { throw EngineError.promptTooLong }
        tokens.removeLast(tokens.count - Int(count))
        return tokens
    }

    private func piece(for token: llama_token) -> Data {
        var buffer = [CChar](repeating: 0, count: 64)
        var length = llama_token_to_piece(vocab, token, &buffer, Int32(buffer.count), 0, false)
        if length < 0 {
            buffer = [CChar](repeating: 0, count: Int(-length))
            length = llama_token_to_piece(vocab, token, &buffer, Int32(buffer.count), 0, false)
        }
        return Data(buffer.prefix(Int(max(length, 0))).map { UInt8(bitPattern: $0) })
    }
}
