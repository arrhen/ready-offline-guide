# Ready: Offline Guide

A free, open-source iPhone app that answers practical "what do I do?" questions with no signal, no account and no network. Download a small language model once, then everything runs on the device.

> **Status:** early. The device check, model recommendation, and verified model downloads work; answering is not built yet. See [SPEC.md](SPEC.md).

## What it will do

- **Library:** read curated, openly licensed guides (first aid, water, shelter, fire, navigation, power outages) with no model at all.
- **Ask:** a small on-device model answers from those guides and shows the passages it used. It is not a replacement for a professional or an emergency call.
- **Set up in one tap:** the app checks your phone's memory and free space and recommends a model size and settings. Everything can be changed later.
- **Fully offline** after the one-time download. No analytics, no accounts, no tracking.

## Build

Requires Xcode and [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`).

```sh
xcodegen generate
open Ready.xcodeproj
swift test --package-path Packages/ReadyCore   # recommendation rules
```

The rules that map a phone to a model live in `Packages/ReadyCore/Sources/ReadyCore/Recommender.swift`.

## Not a medical device

A small model can be wrong. Ready always shows its sources, and for anything serious you should call your local emergency number.

## Support

Free, with optional donations through [GitHub Sponsors](https://github.com/sponsors/arrhen).

## License

[MIT](LICENSE). Bundled guides and downloadable models carry their own licenses, listed in the app and in SPEC.md.
