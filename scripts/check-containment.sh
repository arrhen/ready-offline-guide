#!/usr/bin/env bash
# Fails if the model could reach the outside world. Run before every build you ship; check-release.sh runs it.
#
# The model is text in, text out. This checks the things that keep it that way:
#   1. the llama.cpp framework imports no network functions,
#   2. only the model downloader uses URLSession, and no engine code can open sockets, run
#      processes, load code, show web content or open links,
#   3. no tool or function calling, and the model file's own chat template is never applied,
#   4. no App Transport Security exceptions,
#   5. only the chat session loads a model,
#   6. nothing can share, export or send out a file or a library (files a person adds stay on the phone).
set -euo pipefail
cd "$(dirname "$0")/.."
fail=0
bad() { echo "FAIL: $1" >&2; fail=1; }

# 1. Network and process functions imported by the llama framework (every slice).
FW=Vendor/llama.xcframework
[[ -d "$FW" ]] || { echo "Vendor/llama.xcframework is missing. Run scripts/setup-llama.sh first." >&2; exit 1; }
for bin in "$FW"/*/llama.framework/llama "$FW"/*/llama.framework/Versions/A/llama; do
  [[ -f "$bin" ]] || continue
  hits=$(nm -u "$bin" 2>/dev/null | grep -iE '(^| )_?(socket|connect|bind|listen|accept|getaddrinfo|gethostbyname|sendto|recvfrom|curl_[a-z_]*|nw_connection[a-z_]*|CFSocket[A-Za-z]*|CFStream[A-Za-z]*|SSLCreateContext)$|NSURLSession|NSURLConnection|CFNetwork' || true)
  [[ -z "$hits" ]] || bad "$bin imports network symbols: $(echo "$hits" | tr '\n' ' ')"
done

SRC="Packages/ReadyCore/Sources/ReadyCore App/Ready"

# 2a. URLSession only in the downloader.
users=$(grep -rlE '\bURLSession|\bURLRequest|\bNWConnection|\bNWListener|\bCFStream|\bCFSocket|\bWKWebView|\bSFSafariViewController' $SRC | grep -v 'ModelDownloader.swift' || true)
[[ -z "$users" ]] || bad "network or web APIs used outside ModelDownloader.swift: $users"

# 2b. The engine and everything that handles model text must not open anything or run anything.
for f in LlamaEngine ChatSession ChatFormat SafeMarkdown GuidePack UserLibrary FileImporter Lookup; do
  file="Packages/ReadyCore/Sources/ReadyCore/$f.swift"
  hits=$(grep -nE 'Process\(|NSTask|dlopen|dlsym|posix_spawn|fork\(|system\(|popen|UIApplication|openURL|\.open\(|NSWorkspace|\bURLSession|FileHandle\(forWriting|\.write\(to' "$file" || true)
  [[ -z "$hits" ]] || bad "$file does something it should not: $hits"
done

# 3. No tools, and the model file's own template is never used.
hits=$(grep -rnE 'tool_call|function_call|llama_chat_apply_template|llama_model_chat_template|<tools>' $SRC \
  | grep -v 'Tests' | grep -vE 'ChatFormat.swift:[0-9]+:.*controlTags' || true)
[[ -z "$hits" ]] || bad "tool calling or a model-supplied template is referenced: $hits"

# 4. No App Transport Security exceptions.
if grep -rqiE 'NSAllowsArbitraryLoads|NSExceptionDomains|NSExceptionAllowsInsecureHTTPLoads' project.yml App 2>/dev/null; then
  bad "App Transport Security is relaxed"
fi

# 5. Only the chat session loads a model.
loaders=$(grep -rlE 'LlamaEngine\.load\(|llama_model_load' Packages/ReadyCore/Sources App | grep -vE 'LlamaEngine.swift|ChatSession.swift' || true)
[[ -z "$loaders" ]] || bad "a model is loaded outside ChatSession: $loaders"

# 6. No sharing or exporting. Files people add never leave the phone: no share sheet, no export, no
#    drag-out, no pasteboard, no mail composer with attachments.
hits=$(grep -rnE 'ShareLink|UIActivityViewController|fileExporter|UIDocumentInteractionController|UIPasteboard|NSItemProvider|Transferable|MFMailComposeViewController|\.draggable|onDrag\(' $SRC || true)
[[ -z "$hits" ]] || bad "something could share or export content: $hits"

if [[ $fail -ne 0 ]]; then exit 1; fi
echo "Containment checks passed."
