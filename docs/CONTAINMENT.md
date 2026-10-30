# How the on-device model is contained

The goal: the model is a single-function component. Text in, text out. It cannot use tools, reach
the network, run code, open links or read or write anything but the text it is given. This file says
what enforces that, what was verified, and what is not enforced.

Checked 2026-10-29 against the code and the binaries, not from memory.
`scripts/check-containment.sh` re-checks the mechanical parts and runs before every release
(`scripts/check-release.sh`). Tests in `ContainmentTests.swift` cover the rest.

## What the model can and cannot do

| Question | Answer | Evidence |
|---|---|---|
| Can it call tools or functions? | No. Nothing parses model output for tool calls, no tool is declared in any prompt, and the model file's own chat template (which is where tool support is declared) is never applied. | `check-containment.sh` step 3; `promptNeverDeclaresToolsOrFunctions` |
| Can it use the network? | Not from the runtime. The llama.cpp framework imports no socket, connect, DNS, curl or CFNetwork functions on any platform slice. | `check-containment.sh` step 1 (0 network symbols in all four slices; the same check flags curl) |
| Does the app use the network at all? | Only to download a model you pick. The request starts at `huggingface.co` over HTTPS, pinned to a commit. Hugging Face then redirects to its own CDN hosts, and the app cannot restrict that second hop in a background session, so the real control is the SHA-256: a file is kept only if its size and hash match the pinned values, otherwise it is deleted. StoreKit and links you tap are separate. | `ModelCatalog.isAllowedSource` (starting host); `ModelStore.install` (hash); step 2 (URLSession is used only in `ModelDownloader.swift`) |
| Can its words send you to a website? | No. Model output is shown as styled text only. Markdown links and images are removed, so nothing it writes is tappable. | `SafeMarkdown`; `renderedModelOutputHasNoLinksOrImages` |
| Can you or a guide forge a system turn or a tool call by typing control markers? | No. `<|...|>` markers and think/tool tags in typed text, earlier answers and guide excerpts are broken apart before tokenizing. | `ChatFormat.neutralized`; `typedSpecialTokensDoNotCreateNewTurns` and two more |
| Can it run code, start processes or open files? | No code path does. The engine, chat and formatting files are checked for process, dynamic-loading, web-view and link-opening APIs. | `check-containment.sh` step 2b |
| Can it load another model file? | Only catalog models, each pinned and hash-checked, load, and only the chat session loads one. There is no "import a model" feature. | step 5; `ModelStore.install` |
| Does it remember anything? | No. A conversation lives in memory and is gone when you leave the chat or tap New chat. Only settings are stored. | No code writes conversation text anywhere |
| Is it limited in work? | Yes: capped context, capped answer length, one answer at a time, cancellable, unloaded when the app is backgrounded. | `Recommender` presets; `ChatSession` |
| Is it single-purpose? | Yes: one system prompt (answer only from the supplied guide excerpts, no diagnosis, no doses), thinking switched off, and an emergency screen that sends medical and poisoning questions away before the model is involved. | `ChatFormat.systemPrompt`; `SafetyScreen` |
| Are there App Transport Security exceptions? | None. Plain HTTP is refused. | step 4 |

## Files people add

People can add text, Markdown and PDF files, which are indexed on the phone (`UserLibrary`) and
searched with the guides.

- **Untrusted input.** Imported text is treated like any excerpt: control markers in it are broken apart
  before the model sees it (`aFilesTextCannotForgeControlMarkersInThePrompt`), and the model has no tools.
- **Parsing.** Plain text is decoded directly. PDFs are read with Apple's PDFKit, in the app's process, so
  a malformed PDF could in principle crash the app or exploit a PDFKit bug. Mitigations: types are limited
  to ones that need no archive unpacking (no zip-based formats: Word, EPUB and OpenDocument are not
  supported), files over 100 MB, 3,000 pages or 10 million characters are refused, shortcuts
  (symbolic links) are refused, and reading happens off the main thread.
- **Protected files.** Password-locked PDFs and PDFs that forbid copying are refused. Ready never tries to
  unlock or work around protection.
- **Never leaves the phone.** There is no import from a URL, and nothing can share, export or send a file or
  library (no share sheet, exporter, drag-out or pasteboard code). `check-containment.sh` step 6 fails if
  that changes. Text from a person's files is not selectable in the app, so the system's Copy and Share menu
  is not offered for it (guide text is selectable). The Debug-only "Report this answer" email can quote
  file-derived text, so before chat ships it must leave out file passages or ask first.
- **What is kept.** Only extracted text, in a database in the app's folder. No original file is copied.
  Excluded from iCloud and device backups by default, with a toggle in Settings. "Delete all my files"
  removes everything.

## What is not enforced, and why

- **The weights still know how to do tool calls.** Qwen3 models are trained for them. Weights cannot be
  edited to remove that, and we should not try. What we guarantee is that no code path declares a
  tool or acts on one. If a future change adds one, `check-containment.sh` fails on it.
- **It runs inside the app's process.** iOS has no way to sandbox part of an app. Survival LLM puts
  its engine in a separate macOS process under a sandbox profile that refuses all network access.
  We cannot do that on iOS. The substitute is the absence of network code in the runtime (verified
  above) plus the app-level checks.
- **Three imported functions in the llama framework are not network-related but are worth knowing:**
  `dlopen` and `dlsym` come from ggml's loader for backend plug-ins. `llama.cpp` calls
  `ggml_backend_load_all()`, and I have not checked whether it runs when the model loads in our
  build, so assume it may. iOS loads only code signed with the app's own signature, which a
  downloaded model file cannot provide. `fork` is in ggml's crash handler (`ggml.c`, which tries to
  start a debugger), and iOS refuses `fork` in an app. Model data does not reach any of them. They could be removed by building llama.cpp ourselves with those paths disabled, which is
  worth doing before release.
- **The model file is parsed by llama.cpp's GGUF reader.** A malformed file could in principle trigger
  a bug in that reader. Only SHA-256-pinned files from one host load, so an attacker would need to
  change a file on Hugging Face at a pinned commit, which the hash check would catch. Keep llama.cpp
  updated.
- **Text prompt injection cannot be fully prevented.** A person can still try to talk the model into
  ignoring its instructions. With no tools, no network and no memory, the worst outcome is a wrong or
  silly answer, which is why the guide passage is always shown beside the summary.
- **The unused multimodal library is in the framework.** The official build includes image-input code
  (`mtmd`). Nothing calls it. A custom build could leave it out.
- **Release builds link the llama framework but nothing in the interface can reach it** until guides
  are reviewed (see LIABILITY.md). The framework (about 70 MB) and the increased-memory entitlement
  still ship. The increased-memory entitlement is not requested in Release builds while there is no model (see `project.yml`).
  Everything above applies to preview builds and to the future release.
- **The input defence is a list of known markers.** `neutralized` breaks apart Qwen3's markers. That is
  complete for Qwen3, and a test fails if a model from another family is added, but a list can miss
  things. The sturdier design is to tokenize our own template markers as special tokens and everything
  untrusted with special tokens switched off, which removes the list. Worth doing before a second
  model family.
- **The release scan is pattern-based.** `check-containment.sh` finds the APIs and symbols it knows
  about. It will not notice a new way of reaching the network that it has no pattern for, so review
  changes to engine, chat and download code by hand.
