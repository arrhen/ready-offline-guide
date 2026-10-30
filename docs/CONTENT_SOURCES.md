# Content sources

Status as of 2026-10-29. "Verify" means the licence basis must be confirmed from the document
itself (front matter or the site's own notice) before it is bundled. Each shipped guide records
its source URL, retrieval date and licence basis.

## How a guide gets into a release

Every guide in `Guides/` has front matter recording publisher, source page, the date the source
was last updated, the date we copied it, and the licence basis. `clearance: pending` is the
default. A guide is changed to `clearance: cleared` only when:

1. The numbers and steps were compared against the source page line by line (the tests also pin
   the key figures).
2. The page was checked for third-party material (images, quoted text) and none is reproduced.
3. The agency's own reuse or copyright statement was read, or the agency confirmed in writing.
4. The date is recent enough that the guidance is unlikely to have changed.

`scripts/check-release.sh` fails if any guide is not cleared. Debug builds show uncleared guides
(marked as such); release builds hide them and cannot answer from them.

## Guides in the repo now

| Guide | Source | Source updated | Status |
|---|---|---|---|
| Making water safe in an emergency | EPA, Emergency Disinfection of Drinking Water | 2026-02-24 | pending. EPA's disclaimer page describes document copyright in hedged terms ("freely distributed and used for non-commercial, scientific and educational purposes... Individual documents... may have different copyright conditions"). The app has an optional tip jar, so whether it counts as "non-commercial" is an open question for EPA or a lawyer. The stronger basis is 17 U.S.C. 105 (EPA says its disclaimers are a catalogue that applies to a given work only where stated). Get written confirmation or a lawyer's view before clearing |
| Power outages | Ready.gov (FEMA / DHS) | 2026-06-04 | pending. FEMA's copyright page returned an access error, so its reuse statement is unread |

Known gaps in retrieval: the search is word-based, so questions phrased with words the guide does not use (for example "is it safe to run a generator indoors", where the guide says "outdoors and at least 20 feet away") get "no guide". That is the safe direction. Fix by adding a `keywords:` field per section, and by using the same stemmer in the filter as in the index.

CDC and USDA FSIS pages blocked automated fetching (HTTP 403), so they were not included.

## Leads from Survival LLM (checked 2026-10-29)

Survival LLM (`~/survival-llm`, an MIT project we run privately) keeps a ledger of its sources in
`SOURCES.md` and a fetch script, `library/fetch_manuals.py`, with the source URL of each manual.
Its text copies also sit in `~/Survival LLM Library`. I read the printed front matter of each manual
there. **These are leads only. Nothing below is cleared**, for three reasons:

- I read a text conversion made by another tool, not the official PDF. Confirm each statement on
  armypubs.army.mil (or the publisher's site) before clearing.
- "Approved for public release; distribution is unlimited" is a distribution statement. It says
  nothing about third-party images or text inside the manual. A text scan cannot see image credits.
- A clear licence does not make a source in scope. Ready does not diagnose or treat (see
  LIABILITY.md), so medical and tactical manuals are poor fits even when their licence is fine.

| Manual | Printed statement (front matter) | Third-party material seen | Scope for Ready | Verdict |
|---|---|---|---|---|
| TB MED 577, Field Water Supplies | "Approved for public release; distribution is unlimited" | Trademark notice only | Good: water treatment | **Best lead** |
| TC 21-3, Cold Weather Survival (Sept 2025) | same | None found (the one "©"-style hit was a false positive) | Good: cold-weather survival | **Best lead** |
| ATP 4-25.12, Unit Field Sanitation | same | None found | Good: hygiene and sanitation | **Best lead** |
| ATP 3-50.21, Survival | same | None found (one hit was a false positive) | Fair: survival basics, but written for soldiers | Lead; read for tactical content |
| TB MED 507, Heat Stress | same | Trademark notice only | Mixed: prevention is in scope, treating heat casualties is not | Lead; prevention sections only |
| ATP 4-02.11, Casualty Response and First Aid (23 Mar 2026) | same | None found | Poor: combat casualty care and first aid is treatment | Do not use as-is |
| USAF AFH 10-644, SERE Operations | No statement found in the text | "©National Park Service" image credit seen | Poor: military survival and field medicine | Do not use unless a statement is found; exclude that image |
| Nuclear War Survival Skills (ORNL-5037, 1979) | A 1986 copyright by the author allows copying only under conditions (for example full-scale reproduction) | Author's copyright | Narrow | **Do not use**: excerpting into a search pack likely fails the conditions |
| FEMA Are You Ready? and FEMA CERT manual | No statement found in the text | None found | Fair: preparedness | Unresolved. Check ready.gov's and FEMA's reuse terms |
| Emergency Response Guidebook 2024 | No statement found in the text | None found | Narrow: hazardous materials | Unresolved. Survival LLM cites a permission to reproduce "without further permission... not for resale"; read it yourself |
| Joint Trauma System Prolonged Casualty Care | No statement found in the text | None found | Poor: tactical medicine | Do not use |

Survival LLM also lists sources that depend on non-commercial or ShareAlike licences (wikiHow,
iFixit, IFRC, WHO). Its own note calls non-commercial sources "fine for this free project". Ready has
an in-app tip jar, so treat non-commercial sources as out for the bundled pack, and ask a lawyer
before offering them even as downloads.

What Survival LLM does that Ready should copy: it records the licence and date checked for every
source, says what it left out on purpose and why, and drops rights-unclear sources from shared
builds. Ready's `clearance` flag and this file do the same job.

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
| FM 4-25.11 First Aid (2002) | Cleared for public release, but superseded (by TC 4-02.1 in 2016, which ATP 4-02.11 replaced in March 2026) and the guidance has changed. Outdated treatment advice is a liability. Its replacement is also treatment-focused, so see the leads table above |

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
