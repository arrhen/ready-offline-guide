# Ready: Offline Guide: Spec (draft)

Store name: **Ready: Offline Guide**. Home-screen name: **Ready** (`CFBundleDisplayName`). Reserve the name in App Store Connect and check USPTO class 9 before submitting. "Ready.gov" is FEMA's campaign, so avoid anything that implies government affiliation.

## Goals

1. Free, MIT, iOS, fully offline after a one-time download.
2. One-tap setup that picks a sensible model and settings for the device.
3. Useful even with no model: the Library works on its own.
4. Honest about limits: sources shown, clear disclaimer, short answers.

Non-goals: accounts, cloud sync, analytics, chat history upload, ads, anything "prepper" in tone.

## Architecture

- SwiftUI app, iOS 17+.
- Inference: llama.cpp (GGUF, Metal). MLX Swift is the fallback if llama.cpp packaging gets awkward.
- Retrieval: small on-device embedding model plus a vector index built at build time over the bundled guides. The model answers only from retrieved passages and the UI shows them.
- Downloads: `URLSession` background sessions, resumable, Wi-Fi only by default, SHA-256 verified against hashes pinned in the repo, stored outside iCloud backup.
- Storage screen: list, size, delete.

## Setup and recommendations

First run: check device, show one recommended card, download, then an offline check (airplane-mode test).

Inputs: `ProcessInfo.physicalMemory`, free space (`volumeAvailableCapacityForImportantUsage`), device identifier (chip generation), plus live Low Power Mode and thermal state.

Rule: model weights plus KV cache stay under about 50-60% of RAM. Keep at least 2 GB free after download. The rules live in one table in code, easy to tune.

| Device RAM | Default tier | Context | Notes |
|---|---|---|---|
| 4 GB | Tiny (~0.5 GB) | 2k | Only tier offered |
| 6 GB | Balanced (~1 GB) | 4k | Tiny also offered |
| 8 GB+ | Best (~2.5 GB) | 4-8k | Balanced also offered; uses extended memory entitlement |

Presets: **Battery saver**, **Balanced**, **Best quality** set context length, answer length and GPU use together. Advanced settings are collapsed by default. Low Power Mode or high thermal state drops to Battery saver automatically.

## Models (shortlist, to be benchmarked)

Prefer Apache 2.0 / MIT: Qwen3 (0.6B, 1.7B, 4B), SmolLM. Llama and Gemma carry use-restriction terms; offer as optional downloads or skip. Record every model's license, source URL and SHA-256 in `models.json`.

## Content (shortlist, licenses to verify before bundling)

- US Army FM 21-76 Survival (US government work, public domain)
- First-aid and water guidance from public-domain US government sources
- Anything else only with a license that permits redistribution; keep an attribution file

## Safety and App Review

- Disclaimer on first run and in the answer view; emergency-number reminder.
- Answers cite passages. If retrieval finds nothing relevant, say so instead of guessing.
- No claims of medical accuracy. Review guideline 1.4.1 (medical info) applies.
- Privacy: nothing leaves the device; the only network use is user-initiated model download.

## Milestones

1. Device check and recommendation screen with the tier table (no model yet).
2. Model download manager and storage screen.
3. Chat with a single tier, streaming output.
4. Library reader and retrieval with citations.
5. Presets, thermal/Low Power handling, offline check.
6. Site page on arrhen.me, privacy page, TestFlight, App Store.

## Open questions

- Bundle the smallest model, or download-only?
- iPad support at launch?
- Final corpus list and licenses.
