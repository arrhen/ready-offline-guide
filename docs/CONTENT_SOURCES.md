# Content sources

Status as of 2026-10-29. "Verify" means the licence basis must be confirmed from the document
itself (front matter or the site's own notice) before it is bundled. Each shipped guide records
its source URL, retrieval date and licence basis.

## Use (after verification)

US federal agency web pages and publications are works of the US government and not subject to
copyright (17 U.S.C. 105) unless a page says it contains third-party material. Take text only;
leave out logos, seals and third-party images.

| Topic | Candidate source | Notes |
|---|---|---|
| Safe drinking water in an emergency | CDC "Making Water Safe in an Emergency"; EPA emergency disinfection guidance | High value, low risk |
| Food safety in a power outage | USDA FSIS "Keeping Food Safe During an Emergency" | Low risk |
| Extreme cold and heat | CDC and NWS safety pages | Medical-adjacent; keep to prevention and "when to get help" |
| Preparedness basics | FEMA / Ready.gov guides | Content only; do not use the Ready.gov name or logo |
| Fire, shelter, navigation | NPS and USFS public safety pages | Check each page for third-party material |

## Do not use

| Source | Why |
|---|---|
| FM 3-05.70 Survival (2002) | Copies carry a distribution limit to US government agencies and contractors |
| Commercial survival and first-aid books, wikiHow, Red Cross, Mayo Clinic, WHO (most) | Copyrighted or non-commercial licences |
| FM 4-25.11 First Aid (2002) | Cleared for public release, but superseded (by TC 4-02.1, 2016) and the guidance has changed. Outdated treatment advice is a liability |

## Possible larger packs (size options)

| Pack | Size | Licence | Notes |
|---|---|---|---|
| Core guides (bundled) | a few MB | US government, as above | Always available, no model needed |
| WikiMed-derived, Lite | about 175 MB (Kiwix "mini") | CC BY-SA 4.0 | Encyclopedia text, not first-aid instructions; needs attribution and share-alike on adaptations |
| WikiMed-derived, Standard | about 1 GB (Kiwix "nopic") | CC BY-SA 4.0 | As above |
| WikiMed-derived, Full | about 1.9 GB (Kiwix "maxi") | CC BY-SA 4.0 | As above |

CC BY-SA packs are download-only. Never bundle them in the app binary, and ship their attribution
and licence text with the pack.

Kiwix sizes are from the Kiwix catalogue, October 2026 builds. Reading Kiwix ZIM files needs
libzim, which is GPL; that conflicts with shipping an MIT app on the App Store. If these packs
are built, convert the article text ourselves into the pack format rather than linking libzim.
Note the catalogue entries carry no licence field, so confirm the licence from the articles'
own attribution data.

## Pack format (planned)

A pack is a SQLite full-text-search database plus a manifest (id, title, version, date, region,
size, source list with licence basis, SHA-256). Packs download through the same verified
downloader as models. Search is lexical (SQLite FTS5) first, which is small, fast, offline and
easy to audit; semantic search can be added later.
