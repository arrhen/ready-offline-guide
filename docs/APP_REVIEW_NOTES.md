# App Review notes (draft)

Paste into App Store Connect > App Review Information > Notes. Update before each submission.

**How to try it (the first release has no built-in content).** Open the app and tap the field "Search your files"
or the "Add files" row. Accept the one-time notice, choose a text or PDF file (a sample, `review-sample.pdf`, is
attached), then search a word from it, for example "spare key". The passage appears under "From your files".
Settings has the iCloud backup toggle and "Delete all my files". There is no login. There are no accounts.

**What the app is.** Ready: Offline Guide is a free, open-source reference app. After a one-time,
user-started download of a small language model, it works fully offline. It collects no data and
has no accounts. Source: https://github.com/arrhen/ready-offline-guide

**Health and safety content (Guideline 1.4).** The app shows a notice on first launch and in
Settings > About & legal: it is a reference tool, not a substitute for professional help, it must
not be used to diagnose or treat a condition, users should check with a doctor, and they should
call their local emergency number in an emergency. Guides show their source and date. Answers
are generated on the device from those guides and cite them. (Update this paragraph to match the
build: today chat is not in release builds.)

**Generated content (Guideline 1.2).** Answers are produced on the device only. Users can report
any answer from its context menu, which opens an email to privacy@arrhen.me. There is no
user-to-user content, sharing or social feature.

**Tips (Guideline 3.1.1).** Settings > Support Ready offers optional tips to the developer
through in-app purchase (consumables). Tips unlock nothing: the app is identical for everyone.
The app is not a charity and does not solicit charitable donations.

**External link (US storefront only).** On the US storefront the Support screen also shows a
link to GitHub Sponsors, as permitted for the United States storefront by Guideline 3.1.1(a).
The link is hidden on every other storefront, and when the storefront can't be determined.

**Files the user adds (Guideline 5.2).** The app can search text, Markdown and PDF files that the user
chooses from the Files picker. It keeps only the text it reads, on the device. Nothing is uploaded, shared
or exported, there is no import from a URL, and the app does not download, convert or save media from any
service, so it does not facilitate file sharing (5.2.3). It does not open password-locked or
copy-protected PDFs. The only text bundled in the app consists of guides reproduced from US government publications, each
credited to its publisher with its source page and date (5.2, 5.2.1). Text from a user's own files is
not selectable in the app. A notice shown before the first
import says to add only files the user owns or has permission to use. Imported files are kept out of
iCloud backup unless the user turns it on.

**Emergency questions.** Questions that look like emergencies get a fixed reply telling the person to call emergency services. The app does not answer them. If the user has added their own files, a link below the reply lets them choose, after a confirmation, to see matching text from those files exactly as written, labelled as not reviewed. No guide is searched and no generated text is produced for these questions.

**Encryption.** HTTPS only (model downloads). ITSAppUsesNonExemptEncryption is NO.

**No login is needed.** There are no accounts.
