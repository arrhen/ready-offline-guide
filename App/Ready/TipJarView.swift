import SwiftUI
import StoreKit

/// Optional tips for the developer, through in-app purchase as App Review requires.
/// Tips unlock nothing: the app is the same for everyone.
@MainActor @Observable
final class TipStore {
    static let productIDs = [
        "com.arrhen.ready.tip.small",
        "com.arrhen.ready.tip.medium",
        "com.arrhen.ready.tip.large",
    ]

    enum Phase: Equatable { case loading, unavailable, ready, thanks, failed(String) }

    private(set) var products: [Product] = []
    private(set) var phase: Phase = .loading

    func load() async {
        do {
            products = try await Product.products(for: Self.productIDs).sorted { $0.price < $1.price }
            phase = products.isEmpty ? .unavailable : .ready
        } catch {
            phase = .unavailable
        }
    }

    func tip(_ product: Product) async {
        do {
            switch try await product.purchase() {
            case .success(let verification):
                if case .verified(let transaction) = verification {
                    await transaction.finish()
                    phase = .thanks
                } else {
                    phase = .failed("The purchase couldn't be verified.")
                }
            case .pending, .userCancelled:
                break
            @unknown default:
                break
            }
        } catch {
            phase = .failed(error.localizedDescription)
        }
    }
}

struct TipJarView: View {
    @State private var store = TipStore()

    var body: some View {
        List {
            Section {
                Text("Ready is free and open source, and always will be. If it's useful to you, you can leave a tip for the developer. Tips unlock nothing and aren't tax-deductible donations to a charity.")
            }
            Section {
                switch store.phase {
                case .loading:
                    ProgressView()
                case .unavailable:
                    Text("Tips aren't available right now.")
                        .foregroundStyle(.secondary)
                case .ready, .failed:
                    ForEach(store.products) { product in
                        Button {
                            Task { await store.tip(product) }
                        } label: {
                            HStack {
                                Text(product.displayName)
                                Spacer()
                                Text(product.displayPrice).foregroundStyle(.secondary)
                            }
                        }
                    }
                    if case .failed(let message) = store.phase {
                        Text(message).font(.footnote).foregroundStyle(.red)
                    }
                case .thanks:
                    Label("Thank you!", systemImage: "heart.fill")
                        .foregroundStyle(.pink)
                }
            }
        }
        .navigationTitle("Support Ready")
        .navigationBarTitleDisplayMode(.inline)
        .task { await store.load() }
    }
}
