#!/usr/bin/env python3
"""Builds a guide pack (SQLite + FTS5) from the markdown files in Guides/.

  scripts/build-pack.py [--cleared-only] [GUIDES_DIR] [OUT.sqlite]

--cleared-only keeps only guides whose clearance is "cleared" (and allows none at all). Run it before
a release build, so unreviewed text is not in the app at all; see docs/RELEASE.md.

Each guide starts with front matter (id, title, publisher, source_title, source_url,
source_updated, retrieved, region, license_basis, clearance) and is split into sections at
"## " headings. A guide whose clearance is not "cleared" is flagged in the pack and stays out
of release builds. Writes OUT.sqlite and OUT.manifest.json (size and SHA-256).
"""
import hashlib, json, re, sqlite3, sys
from pathlib import Path

REQUIRED = ["id", "title", "publisher", "source_title", "source_url", "source_updated",
            "retrieved", "region", "license_basis", "clearance"]
FORMAT_VERSION = 1

def parse(path):
    text = path.read_text(encoding="utf-8")
    m = re.match(r"---\n(.*?)\n---\n(.*)", text, re.S)
    if not m:
        sys.exit(f"{path}: missing front matter")
    meta = {}
    for line in m.group(1).splitlines():
        k, _, v = line.partition(":")
        meta[k.strip()] = v.strip()
    missing = [k for k in REQUIRED if not meta.get(k)]
    if missing:
        sys.exit(f"{path}: missing {', '.join(missing)}")
    if not meta["source_url"].startswith("https://"):
        sys.exit(f"{path}: source_url must be https")
    sections, heading, lines = [], None, []
    def flush():
        body = "\n".join(l for l in lines if l.strip()).strip()
        if heading and body:
            sections.append((heading, body))
    for line in m.group(2).splitlines():
        if line.startswith("## "):
            flush(); heading, lines = line[3:].strip(), []
        else:
            lines.append(line)
    flush()
    if not sections:
        sys.exit(f"{path}: no sections")
    return meta, sections

def main():
    root = Path(__file__).resolve().parent.parent
    cleared_only = "--cleared-only" in sys.argv
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    src = Path(args[0]) if len(args) > 0 else root / "Guides"
    out = Path(args[1]) if len(args) > 1 else root / "Packages/ReadyCore/Sources/ReadyCore/Resources/core.sqlite"
    out.parent.mkdir(parents=True, exist_ok=True)
    if out.exists():
        out.unlink()
    db = sqlite3.connect(out)
    db.executescript("""
    CREATE TABLE meta(key TEXT PRIMARY KEY, value TEXT NOT NULL);
    CREATE TABLE guides(id TEXT PRIMARY KEY, title TEXT NOT NULL, publisher TEXT NOT NULL,
      source_title TEXT NOT NULL, source_url TEXT NOT NULL, source_updated TEXT NOT NULL,
      retrieved TEXT NOT NULL, region TEXT NOT NULL, license_basis TEXT NOT NULL,
      clearance TEXT NOT NULL, position INTEGER NOT NULL);
    CREATE TABLE sections(id INTEGER PRIMARY KEY, guide_id TEXT NOT NULL REFERENCES guides(id),
      position INTEGER NOT NULL, heading TEXT NOT NULL, body TEXT NOT NULL);
    CREATE VIRTUAL TABLE sections_fts USING fts5(heading, body, content='sections',
      content_rowid='id', tokenize='porter unicode61');
    """)
    files = sorted(src.glob("*.md"))
    if not files and not cleared_only:
        sys.exit("no guides found")
    seen = set()
    for gi, f in enumerate(files):
        meta, sections = parse(f)
        if cleared_only and meta["clearance"] != "cleared":
            continue
        if meta["id"] in seen:
            sys.exit(f"duplicate id {meta['id']}")
        seen.add(meta["id"])
        db.execute("INSERT INTO guides VALUES (?,?,?,?,?,?,?,?,?,?,?)",
                   [meta[k] for k in REQUIRED[:10]] + [gi])
        for si, (h, b) in enumerate(sections):
            cur = db.execute("INSERT INTO sections(guide_id,position,heading,body) VALUES (?,?,?,?)",
                             (meta["id"], si, h, b))
            db.execute("INSERT INTO sections_fts(rowid,heading,body) VALUES (?,?,?)", (cur.lastrowid, h, b))
    db.execute("INSERT INTO meta VALUES ('format_version', ?)", (str(FORMAT_VERSION),))
    db.execute("INSERT INTO meta VALUES ('pack_id', 'core')")
    db.execute("INSERT INTO meta VALUES ('cleared_only', ?)", ("1" if cleared_only else "0",))
    db.commit()
    db.execute("VACUUM")
    db.close()
    data = out.read_bytes()
    manifest = {"packId": "core", "formatVersion": FORMAT_VERSION, "bytes": len(data),
                "sha256": hashlib.sha256(data).hexdigest(), "guides": sorted(seen), "clearedOnly": cleared_only}
    out.with_suffix(".manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
    print(f"wrote {out} ({len(data)} bytes, {len(seen)} guides)")

main()
