# Releasing to the App Store

The first release is **files-only**: search the person's own text, Markdown and PDF files on the phone.
It bundles no guides, no model and no chat. Ready authors nothing in it. Guides, model downloads and
short answers are later releases, once their text is cleared (see CONTENT_SOURCES.md).

Not legal advice. There is no lawyer in this plan, so the position is held by keeping the app's scope small.

## Build steps (every release)

Archiving runs `scripts/check-release.sh` automatically (a build phase that runs only on archive), so an archive
with unreviewed guides or a missing step fails. The steps are:

```sh
python3 -I scripts/build-pack.py --cleared-only   # bundle only cleared guides (none today)
./scripts/check-release.sh                        # containment + "bundled guides are exactly the cleared ones"
# Archive in Xcode with the Release configuration, then:
git checkout -- Packages/ReadyCore/Sources/ReadyCore/Resources   # restore the full dev pack
```

Check the archive: `Info.plist` has `ITSAppUsesNonExemptEncryption = NO`, version and build numbers are
bumped, and the app opens on the home screen with no "Guides" section.

## Before the first submission

- [ ] Apple account approved. Then agree to the **Paid Applications** agreement and add bank and tax details
      in App Store Connect. This is separate from the developer fee and is required for the tip jar.
- [ ] Bundle ID `com.arrhen.ready` registered, and the three tip products created in App Store Connect as
      consumables: `com.arrhen.ready.tip.small`, `.medium`, `.large` (they unlock nothing).
- [ ] Trademark and name check (OUTREACH.md). Decide the store name (below).
- [ ] App icon (1024 x 1024, no transparency). Not made yet.
- [ ] Screenshots from the Release build: home with a few files, a search result from "your files", the
      first-import notice, Settings with the backup toggle.
- [ ] Privacy policy published at a URL (docs/privacy-policy.md is the draft) and a support URL.
- [ ] Run the app on a real phone at least once (free Apple ID is enough for that).
- [ ] Paste docs/APP_REVIEW_NOTES.md into the review notes, trimmed to what the build contains, and attach
      `docs/review-sample.pdf` in the review attachment field. The first release has no built-in content,
      so a reviewer needs a file to try.

## Store listing (draft)

**Name.** "Ready: Offline Search" (chosen). It matches what the first release does. "Offline Guide" would
promise built-in guides, which this release does not have; revisit the name when guides ship. Check
availability in App Store Connect and the trademark note in OUTREACH.md before reserving it.

**Subtitle (30 characters).** Search your own files offline

**Description.**
> Ready searches the text, Markdown and PDF files you add, on your phone, with no account and no
> connection. Only the text is kept, on your phone. Nothing is uploaded, shared or backed up unless you
> choose to include it in iCloud backup. Ready doesn't open password-locked or copy-protected files.
>
> Add only files you own or have permission to use. Ready is not a substitute for professional help. In
> an emergency, call your local emergency number.
>
> Free and open source. Optional tips support the developer and unlock nothing.

Keep to "files you own or have permission to use". Do not describe it as a way to get or use other
people's books, and never name where to find them.

**Keywords.** offline, search, documents, PDF, notes, reference, private

**Category.** Utilities (or Reference).

## App Store Connect answers (check each against the current form)

- **App Privacy:** Data Not Collected. Nothing is sent to us. (Tips are handled by Apple.)
- **Age rating:** answer the questionnaire truthfully. This release authors no medical or treatment
  content, so those answers are "None". Re-answer when guides ship.
- **Content rights / third-party content:** the form asks about third-party content. Read the question as
  worded; the accurate answer is that users add their own files and the app bundles none.
- **Export compliance:** the app uses only Apple's system networking (HTTPS), none in this release. Already
  declared as "no non-exempt encryption".
- **In-app purchases:** the three tip consumables, each with a screenshot of the Support screen.
- **Review notes:** APP_REVIEW_NOTES.md.

## After approval

- Verify a real tip purchase in the sandbox before release.
- Keep GitHub Sponsors as the other donation route (US storefront link is already gated in the app).

## Later releases

1. Guides: clear one at a time (CONTENT_SOURCES.md), set `clearance: cleared`, rebuild the pack, run the check.
2. Short answers (models): restore the entitlement in `project.yml`, move the model screens out of
   `#if DEBUG`, update the review notes, and re-run `check-containment.sh`.
