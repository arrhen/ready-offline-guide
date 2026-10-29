# Ready: Offline Guide

A free, open-source iPhone app that answers practical "what do I do?" questions with no signal, no account and no network. Download a small language model once, then everything runs on the device.

> **Status:** early. The device check, model recommendation, and verified model downloads and a basic chat with the downloaded model work. Answers have no sources yet, so they can be wrong. See [SPEC.md](SPEC.md).

## What it will do

- **Library:** read curated, openly licensed guides (first aid, water, shelter, fire, navigation, power outages) with no model at all.
- **Ask:** a small on-device model answers from those guides and shows the passages it used. It is not a replacement for a professional or an emergency call.
- **Set up in one tap:** the app checks your phone's memory and free space and recommends a model size and settings. Everything can be changed later.
- **Fully offline** after the one-time download. No analytics, no accounts, no tracking.

## Build

Requires Xcode, [XcodeGen](https://github.com/yonaskolb/XcodeGen) and CMake (`brew install xcodegen cmake`).

```sh
./scripts/setup-llama.sh   # once: builds Vendor/llama.xcframework (a few minutes)
xcodegen generate
open Ready.xcodeproj
swift test --package-path Packages/ReadyCore   # recommendation rules
```

`scripts/setup-llama.sh` exists because llama.cpp publishes iOS device and macOS builds but no Simulator build. It checks the official build against a pinned SHA-256 and builds the Simulator slice from the same release tag.

To run the tests against a real model: `READY_TEST_MODEL=/path/to/Qwen3-0.6B-Q4_K_M.gguf swift test --package-path Packages/ReadyCore`.

The rules that map a phone to a model live in `Packages/ReadyCore/Sources/ReadyCore/Recommender.swift`.

## Not a medical device

A small model can be wrong. Ready always shows its sources, and for anything serious you should call your local emergency number.

## Support

Free, with optional donations through [GitHub Sponsors](https://github.com/sponsors/arrhen).

## License

[MIT](LICENSE). Third-party notices (llama.cpp, models) are in [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md). Bundled guides and downloadable models carry their own licenses, listed in the app and in SPEC.md.
