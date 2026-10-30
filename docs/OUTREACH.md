# Free outreach and checks (do these yourself)

Nothing here costs money. None of it blocks the files-only release, except the trademark check.

## 1. Trademark and name (10 minutes, free)

1. Search the USPTO trademark database (tmsearch.uspto.gov) for "Ready" in software (class 9) and
   emergency or preparedness services. Look at who else uses it.
2. Search the App Store for "Ready", "Ready offline", "Ready search".
3. Note that Ready.gov is a US government campaign name. Do not use its logo or say anything that suggests
   affiliation. The app already says it is not affiliated with any agency.
4. If the name looks crowded or confusing, pick a more distinctive one. Renaming is cheap now and not later.

## 2. Ask EPA and FEMA about reusing their text (free, replies not guaranteed)

Do not wait for replies. These are for the later guides release.

> Subject: Reuse of text from [page title]
>
> Hello,
>
> I'm the developer of a free, open-source iPhone app that lets people search documents offline. I'd like
> to include a lightly edited, text-only copy of [page title] ([URL], last updated [date]) as a built-in
> guide, credited to [EPA / FEMA] with a link to the original and the date, with no logos or images, and
> a statement that the app is not affiliated with or endorsed by [agency].
>
> I understand US government works are generally not subject to copyright. Could you confirm that this
> page has no third-party material and that this use is fine, or tell me whom to ask?
>
> Thank you,
> [name], privacy@arrhen.me

Send one to each agency's public contact page. Save any reply in `docs/permissions/` and cite it in the
guide's front matter before setting `clearance: cleared`.

## 3. Check the Army manuals against the publisher (free)

For TB MED 577 (field water), TC 21-3 (cold weather) and ATP 4-25.12 (field sanitation): open the official
PDF from the Army Publishing Directorate and confirm the front page prints "Approved for public release;
distribution is unlimited", and note the date. Then scan for photos or figures with credits to third parties.
Record the date you checked in `docs/CONTENT_SOURCES.md`.

## 4. Test on a real phone (free)

Connect your iPhone to the Mac, choose it in Xcode, set your own Apple ID as the team, and run. It lapses
after 7 days; that's fine for a first check of speed, memory and the file picker.
