# Liability and compliance notes

Ready gives practical guidance to people who may be in a stressful or dangerous situation, so
getting this right matters more than any feature. This file records the risks, what the app
does about each, and what is still open. **It is not legal advice.** Have a lawyer review the
final wording, the privacy policy and the store listing before any public release, and ask them
whether to publish under a company rather than a personal account.

## Principles

1. Ready is a reference tool, never a substitute for professional help or an emergency call.
2. Show the source. Quote the guide; the model may help find and summarize, but the guide
   text is what the person relies on.
3. Say when we don't know. If nothing relevant is found, say so instead of guessing.
4. Keep scope conservative. No diagnosis, no medication dosing, nothing that needs training.
5. Collect nothing. No accounts, analytics or tracking, so there is little to leak or misuse.

## Risk register

| Risk | What the app does | Open |
|---|---|---|
| Small model gives wrong advice (ungrounded, it did: wrong burn and ibuprofen answers) | Questions are answered only from retrieved guide excerpts; no excerpt means no model call and a "no guide" reply; the excerpt is shown under every answer; chat labelled as possibly wrong | Re-test every model change against a fixed question set; a model can still misparaphrase an excerpt |
| Outdated medical guidance | Medical content is limited to current, dated, cited sources; every guide shows its date | Decide whether to include first-aid treatment content at all before launch |
| Copyright or distribution limits on content | Only content with a documented licence basis; provenance recorded per guide (see CONTENT_SOURCES.md) | Check each document's own front matter, not just a website's claim |
| Implied government affiliation or trademark conflict (Ready.gov / FEMA, Army) | No agency names, logos or seals used as branding; sources are credited as sources only | Trademark search for "Ready: Offline Guide" |
| App Review 1.4.1 (medical) | "Check with a doctor" reminder, sources shown, disclaimer on first run and in the chat | Add review notes explaining the app |
| App Review 1.2 (generated content) | Published contact address, per-answer "Report this answer" | A reliable output filter isn't possible on-device; explain in review notes |
| Donations (3.1.1, 3.2.2) | Optional tip jar through in-app purchase, unlocks nothing; GitHub Sponsors link shown inside the app on the US storefront only (storefront checked in code, hidden if unknown) | Needs the paid developer programme and products set up in App Store Connect |
| Privacy | Nothing leaves the device except user-started model/content downloads, and a report email the person sends themselves | Privacy policy page, "Data Not Collected" label |
| Warranty and open-source terms | MIT licence ("as is"), plus an in-app notice | Lawyer to confirm wording |
| Third-party licences | llama.cpp (MIT) and Qwen3 (Apache 2.0) credited in THIRD_PARTY_NOTICES.md | Add CC BY-SA attribution if any Wikipedia-derived pack ships |
| Region-specific advice | Emergency number shown for the device's region, generic text elsewhere | Content is US-centric; label packs by region |
| Export compliance | HTTPS only; `ITSAppUsesNonExemptEncryption` is set to NO in the build | Confirm with the lawyer / App Store Connect questions |

## Containment

The on-device model is text in, text out, with no tools, network, links or memory. See
CONTAINMENT.md for what enforces that and what does not.

## Release gating

Guides are `pending` until cleared (see CONTENT_SOURCES.md). `scripts/check-release.sh` must pass
before an App Store build. Release builds hide uncleared guides, so until a guide is cleared the app
has nothing to answer from.

Answers are grounded: the app searches the guides first and gives the model only the matching
excerpts. If no excerpt covers the question the model is not asked; the app says it has no guide
and shows the emergency number. Every answer shows the guide passage under it. Testing on the 0.6B
model showed it keeps numbers from excerpts when given them, but a model can still paraphrase
wrongly, so the passage text is always shown and the summary is labelled as machine-written.

Chat has no sources yet, so the chat screen ("Ready when you are") is compiled into Debug builds only. Release builds show the
installed model and nothing to ask until guides, retrieval and citations ship.

The emergency number comes from the region setting, which is not the phone's location, so a known
number is always shown with "or the local emergency number where you are".

## Donations: what Apple allows (App Review Guidelines, checked 2026-10-29)

- 3.1.1: apps may use in-app purchase to let people "tip" the developer.
- 3.2.2(iv): collecting funds for charities inside an app is not allowed unless approved as a
  nonprofit; Ready is not a charity, so tips go to the developer and are described that way.
- 3.1.1(a) / 3.1.3: outside the US storefront, an in-app button or link that sends people to
  another payment method is not allowed. So: **tip jar inside the app via in-app purchase everywhere, plus a
  GitHub Sponsors link inside the app on the US storefront only; Sponsors on the website and
  README.** Recheck the US external-link rule just before each submission; it has been contested.

## Before release

- [ ] Lawyer review (disclaimer, privacy policy, store text, entity)
- [ ] Trademark and name check
- [ ] Verify every content source against its own front matter
- [ ] Fixed question set run against each shipped model
- [ ] App Store review notes written
