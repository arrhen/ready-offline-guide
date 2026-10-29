# Third-party notices

Ready includes or downloads the following. Each keeps its own license.

## llama.cpp

Runs the language models on the device. https://github.com/ggml-org/llama.cpp
Used as the official release build b11988 plus a Simulator build from the same tag.

    MIT License
    
    Copyright (c) 2023-2026 The ggml authors
    
    Permission is hereby granted, free of charge, to any person obtaining a copy
    of this software and associated documentation files (the "Software"), to deal
    in the Software without restriction, including without limitation the rights
    to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
    copies of the Software, and to permit persons to whom the Software is
    furnished to do so, subject to the following conditions:
    
    The above copyright notice and this permission notice shall be included in all
    copies or substantial portions of the Software.
    
    THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
    IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
    FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
    AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
    LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
    OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
    SOFTWARE.

## Models (downloaded by the user, not bundled)

| Model | License | Source |
|---|---|---|
| Qwen3 0.6B (Q4_K_M) | Apache 2.0 | https://huggingface.co/unsloth/Qwen3-0.6B-GGUF |
| Qwen3 1.7B (Q4_K_M) | Apache 2.0 | https://huggingface.co/unsloth/Qwen3-1.7B-GGUF |
| Qwen3 4B (Q4_K_M) | Apache 2.0 | https://huggingface.co/Qwen/Qwen3-4B-GGUF |

Qwen3 is by the Qwen team at Alibaba Cloud. Exact file revisions and SHA-256 hashes are in
`Packages/ReadyCore/Sources/ReadyCore/Resources/models.json`.
