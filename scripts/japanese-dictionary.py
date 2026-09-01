#!/usr/bin/env python3
"""Local Yomitan-compatible Japanese dictionary index for iNiR.

The runtime deliberately imports user-provided dictionary ZIPs instead of
shipping a network-bound dictionary service. It accepts the stable Yomitan v3
term, term-meta, and kanji bank shapes and stores the useful fields in SQLite.
"""

from __future__ import annotations

import argparse
import datetime as dt
import json
import os
import re
import sqlite3
import sys
import zipfile
from pathlib import Path
from typing import Any, Iterable

BANK_PATTERNS = {
    "term": re.compile(r"(?:^|/)term_bank_(\d+)\.json$"),
    "term_meta": re.compile(r"(?:^|/)term_meta_bank_(\d+)\.json$"),
    "kanji": re.compile(r"(?:^|/)kanji_bank_(\d+)\.json$"),
}


def data_home() -> Path:
    base = Path(os.environ.get("XDG_DATA_HOME", Path.home() / ".local/share"))
    return base / "inir"


def default_db_path() -> Path:
    return data_home() / "japanese-dictionaries.sqlite3"


def emit(payload: Any, *, pretty: bool = False) -> None:
    json.dump(payload, sys.stdout, ensure_ascii=False, indent=2 if pretty else None)
    sys.stdout.write("\n")


def connect(path: Path) -> sqlite3.Connection:
    path.parent.mkdir(parents=True, exist_ok=True)
    db = sqlite3.connect(path)
    db.row_factory = sqlite3.Row
    db.execute("PRAGMA foreign_keys = ON")
    db.executescript(
        """
        CREATE TABLE IF NOT EXISTS dictionaries (
            id INTEGER PRIMARY KEY,
            title TEXT NOT NULL UNIQUE,
            revision TEXT NOT NULL DEFAULT '',
            format INTEGER,
            source_path TEXT NOT NULL DEFAULT '',
            imported_at TEXT NOT NULL
        );
        CREATE TABLE IF NOT EXISTS terms (
            id INTEGER PRIMARY KEY,
            dictionary_id INTEGER NOT NULL REFERENCES dictionaries(id) ON DELETE CASCADE,
            expression TEXT NOT NULL,
            reading TEXT NOT NULL DEFAULT '',
            definition_tags TEXT NOT NULL DEFAULT '',
            rules TEXT NOT NULL DEFAULT '',
            score REAL NOT NULL DEFAULT 0,
            glossary_json TEXT NOT NULL,
            sequence INTEGER NOT NULL DEFAULT -1,
            term_tags TEXT NOT NULL DEFAULT ''
        );
        CREATE INDEX IF NOT EXISTS terms_expression_idx ON terms(expression);
        CREATE INDEX IF NOT EXISTS terms_reading_idx ON terms(reading);
        CREATE TABLE IF NOT EXISTS term_meta (
            id INTEGER PRIMARY KEY,
            dictionary_id INTEGER NOT NULL REFERENCES dictionaries(id) ON DELETE CASCADE,
            expression TEXT NOT NULL,
            meta_type TEXT NOT NULL,
            data_json TEXT NOT NULL
        );
        CREATE INDEX IF NOT EXISTS term_meta_expression_idx ON term_meta(expression, meta_type);
        CREATE TABLE IF NOT EXISTS kanji (
            id INTEGER PRIMARY KEY,
            dictionary_id INTEGER NOT NULL REFERENCES dictionaries(id) ON DELETE CASCADE,
            character TEXT NOT NULL,
            onyomi TEXT NOT NULL DEFAULT '',
            kunyomi TEXT NOT NULL DEFAULT '',
            tags TEXT NOT NULL DEFAULT '',
            meanings_json TEXT NOT NULL,
            stats_json TEXT NOT NULL
        );
        CREATE INDEX IF NOT EXISTS kanji_character_idx ON kanji(character);
        """
    )
    return db


def _json_from_zip(archive: zipfile.ZipFile, name: str) -> Any:
    try:
        raw = archive.read(name)
    except KeyError as exc:
        raise ValueError(f"dictionary archive is missing {name}") from exc
    try:
        return json.loads(raw.decode("utf-8-sig"))
    except (UnicodeDecodeError, json.JSONDecodeError) as exc:
        raise ValueError(f"invalid JSON in {name}: {exc}") from exc


def _find_index_name(archive: zipfile.ZipFile) -> str:
    candidates = [n for n in archive.namelist() if n == "index.json" or n.endswith("/index.json")]
    if not candidates:
        raise ValueError("not a Yomitan dictionary: index.json is missing")
    candidates.sort(key=lambda n: (n.count("/"), len(n)))
    return candidates[0]


def _bank_names(archive: zipfile.ZipFile, kind: str) -> list[str]:
    pattern = BANK_PATTERNS[kind]
    matched: list[tuple[int, str]] = []
    for name in archive.namelist():
        match = pattern.search(name)
        if match:
            matched.append((int(match.group(1)), name))
    return [name for _, name in sorted(matched)]


def _require_list(entry: Any, size: int, source: str) -> list[Any]:
    if not isinstance(entry, list) or len(entry) < size:
        raise ValueError(f"malformed entry in {source}")
    return entry


def import_dictionary(db: sqlite3.Connection, archive_path: Path) -> dict[str, Any]:
    if not archive_path.is_file():
        raise ValueError(f"dictionary archive does not exist: {archive_path}")

    with zipfile.ZipFile(archive_path) as archive:
        index_name = _find_index_name(archive)
        index = _json_from_zip(archive, index_name)
        if not isinstance(index, dict):
            raise ValueError("dictionary index must be a JSON object")
        title = str(index.get("title") or "").strip()
        if not title:
            raise ValueError("dictionary index has no title")
        revision = str(index.get("revision") or "")
        fmt = index.get("format", index.get("version"))
        if fmt is not None and not isinstance(fmt, int):
            fmt = None

        term_names = _bank_names(archive, "term")
        meta_names = _bank_names(archive, "term_meta")
        kanji_names = _bank_names(archive, "kanji")
        if not term_names and not kanji_names and not meta_names:
            raise ValueError("dictionary archive contains no supported Yomitan banks")

        imported_at = dt.datetime.now(dt.timezone.utc).isoformat()
        term_count = meta_count = kanji_count = 0

        with db:
            old = db.execute("SELECT id FROM dictionaries WHERE title = ?", (title,)).fetchone()
            if old:
                db.execute("DELETE FROM dictionaries WHERE id = ?", (old["id"],))
            cur = db.execute(
                "INSERT INTO dictionaries(title, revision, format, source_path, imported_at) VALUES (?, ?, ?, ?, ?)",
                (title, revision, fmt, str(archive_path.resolve()), imported_at),
            )
            dictionary_id = int(cur.lastrowid)

            for name in term_names:
                bank = _json_from_zip(archive, name)
                if not isinstance(bank, list):
                    raise ValueError(f"{name} is not a term bank array")
                rows = []
                for raw in bank:
                    row = _require_list(raw, 8, name)
                    expression, reading, def_tags, rules, score, glossary, sequence, term_tags = row[:8]
                    if not isinstance(expression, str) or not isinstance(reading, str) or not isinstance(glossary, list):
                        raise ValueError(f"malformed term entry in {name}")
                    rows.append(
                        (
                            dictionary_id,
                            expression,
                            reading,
                            str(def_tags or ""),
                            str(rules or ""),
                            float(score or 0),
                            json.dumps(glossary, ensure_ascii=False, separators=(",", ":")),
                            int(sequence) if isinstance(sequence, int) else -1,
                            str(term_tags or ""),
                        )
                    )
                db.executemany(
                    """INSERT INTO terms(
                        dictionary_id, expression, reading, definition_tags, rules,
                        score, glossary_json, sequence, term_tags
                    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)""",
                    rows,
                )
                term_count += len(rows)

            for name in meta_names:
                bank = _json_from_zip(archive, name)
                if not isinstance(bank, list):
                    raise ValueError(f"{name} is not a term metadata bank array")
                rows = []
                for raw in bank:
                    row = _require_list(raw, 3, name)
                    expression, meta_type, data = row[:3]
                    if not isinstance(expression, str) or meta_type not in {"freq", "pitch", "ipa"}:
                        continue
                    rows.append(
                        (
                            dictionary_id,
                            expression,
                            meta_type,
                            json.dumps(data, ensure_ascii=False, separators=(",", ":")),
                        )
                    )
                db.executemany(
                    "INSERT INTO term_meta(dictionary_id, expression, meta_type, data_json) VALUES (?, ?, ?, ?)",
                    rows,
                )
                meta_count += len(rows)

            for name in kanji_names:
                bank = _json_from_zip(archive, name)
                if not isinstance(bank, list):
                    raise ValueError(f"{name} is not a kanji bank array")
                rows = []
                for raw in bank:
                    row = _require_list(raw, 6, name)
                    character, onyomi, kunyomi, tags, meanings, stats = row[:6]
                    if not isinstance(character, str) or not isinstance(meanings, list) or not isinstance(stats, dict):
                        raise ValueError(f"malformed kanji entry in {name}")
                    rows.append(
                        (
                            dictionary_id,
                            character,
                            str(onyomi or ""),
                            str(kunyomi or ""),
                            str(tags or ""),
                            json.dumps(meanings, ensure_ascii=False, separators=(",", ":")),
                            json.dumps(stats, ensure_ascii=False, separators=(",", ":")),
                        )
                    )
                db.executemany(
                    """INSERT INTO kanji(
                        dictionary_id, character, onyomi, kunyomi, tags, meanings_json, stats_json
                    ) VALUES (?, ?, ?, ?, ?, ?, ?)""",
                    rows,
                )
                kanji_count += len(rows)

    return {
        "ok": True,
        "title": title,
        "revision": revision,
        "terms": term_count,
        "metadata": meta_count,
        "kanji": kanji_count,
    }


def _decode_json(value: str, fallback: Any) -> Any:
    try:
        return json.loads(value)
    except json.JSONDecodeError:
        return fallback


def _metadata_for(db: sqlite3.Connection, expression: str) -> dict[str, list[dict[str, Any]]]:
    result: dict[str, list[dict[str, Any]]] = {"pitch": [], "frequency": [], "ipa": []}
    rows = db.execute(
        """SELECT m.meta_type, m.data_json, d.title AS dictionary
           FROM term_meta m JOIN dictionaries d ON d.id = m.dictionary_id
           WHERE m.expression = ?""",
        (expression,),
    )
    for row in rows:
        item = {"dictionary": row["dictionary"], "data": _decode_json(row["data_json"], None)}
        if row["meta_type"] == "freq":
            result["frequency"].append(item)
        else:
            result[row["meta_type"]].append(item)
    return result


def term_rows(db: sqlite3.Connection, expression: str, limit: int, *, reading_too: bool = True) -> list[dict[str, Any]]:
    if reading_too:
        query = """SELECT t.*, d.title AS dictionary
                   FROM terms t JOIN dictionaries d ON d.id = t.dictionary_id
                   WHERE t.expression = ? OR t.reading = ?
                   ORDER BY CASE WHEN t.expression = ? THEN 0 ELSE 1 END, t.score DESC, t.id
                   LIMIT ?"""
        params = (expression, expression, expression, limit)
    else:
        query = """SELECT t.*, d.title AS dictionary
                   FROM terms t JOIN dictionaries d ON d.id = t.dictionary_id
                   WHERE t.expression = ?
                   ORDER BY t.score DESC, t.id LIMIT ?"""
        params = (expression, limit)
    result = []
    for row in db.execute(query, params):
        result.append(
            {
                "expression": row["expression"],
                "reading": row["reading"] or row["expression"],
                "definitionTags": row["definition_tags"].split() if row["definition_tags"] else [],
                "rules": row["rules"].split() if row["rules"] else [],
                "score": row["score"],
                "definitions": _decode_json(row["glossary_json"], []),
                "sequence": None if row["sequence"] < 0 else row["sequence"],
                "termTags": row["term_tags"].split() if row["term_tags"] else [],
                "dictionary": row["dictionary"],
            }
        )
    return result


def lookup(db: sqlite3.Connection, text: str, limit: int) -> dict[str, Any]:
    terms = term_rows(db, text, limit)
    return {"query": text, "terms": terms, "metadata": _metadata_for(db, text)}


def scan_prefix(db: sqlite3.Connection, text: str, limit: int, max_chars: int) -> dict[str, Any]:
    # Japanese has no mandatory whitespace. Matching longest dictionary prefixes
    # gives OCR text a useful first lookup without making tokenizer choice part of
    # the dictionary storage contract. A morphology layer can add deinflection on
    # top later without changing this API.
    candidate = text.strip()[:max_chars]
    matched = ""
    terms: list[dict[str, Any]] = []
    for size in range(len(candidate), 0, -1):
        prefix = candidate[:size]
        terms = term_rows(db, prefix, limit, reading_too=False)
        if terms:
            matched = prefix
            break
    return {
        "query": text,
        "matched": matched,
        "consumed": len(matched),
        "terms": terms,
        "metadata": _metadata_for(db, matched) if matched else {"pitch": [], "frequency": [], "ipa": []},
    }


def kanji_lookup(db: sqlite3.Connection, text: str) -> dict[str, Any]:
    seen: set[str] = set()
    chars = [c for c in text if not (c in seen or seen.add(c))]
    rows: list[dict[str, Any]] = []
    for char in chars:
        matches = db.execute(
            """SELECT k.*, d.title AS dictionary
               FROM kanji k JOIN dictionaries d ON d.id = k.dictionary_id
               WHERE k.character = ? ORDER BY k.id""",
            (char,),
        )
        for row in matches:
            rows.append(
                {
                    "character": row["character"],
                    "onyomi": row["onyomi"].split() if row["onyomi"] else [],
                    "kunyomi": row["kunyomi"].split() if row["kunyomi"] else [],
                    "tags": row["tags"].split() if row["tags"] else [],
                    "meanings": _decode_json(row["meanings_json"], []),
                    "stats": _decode_json(row["stats_json"], {}),
                    "dictionary": row["dictionary"],
                }
            )
    return {"query": text, "kanji": rows}


def list_dictionaries(db: sqlite3.Connection) -> dict[str, Any]:
    dictionaries = []
    for row in db.execute(
        """SELECT d.*,
           (SELECT COUNT(*) FROM terms t WHERE t.dictionary_id = d.id) AS terms,
           (SELECT COUNT(*) FROM term_meta m WHERE m.dictionary_id = d.id) AS metadata,
           (SELECT COUNT(*) FROM kanji k WHERE k.dictionary_id = d.id) AS kanji
           FROM dictionaries d ORDER BY d.title COLLATE NOCASE"""
    ):
        dictionaries.append(dict(row))
    return {"dictionaries": dictionaries}


def remove_dictionary(db: sqlite3.Connection, title: str) -> dict[str, Any]:
    with db:
        cur = db.execute("DELETE FROM dictionaries WHERE title = ?", (title,))
    return {"ok": cur.rowcount > 0, "removed": title if cur.rowcount else ""}


def parser() -> argparse.ArgumentParser:
    p = argparse.ArgumentParser(description="iNiR local Yomitan-compatible Japanese dictionary index")
    p.add_argument("--db", type=Path, default=default_db_path(), help="override SQLite database path")
    p.add_argument("--pretty", action="store_true", help="pretty-print JSON output")
    sub = p.add_subparsers(dest="command", required=True)

    imp = sub.add_parser("import", help="import or replace one Yomitan dictionary ZIP")
    imp.add_argument("archive", type=Path)

    sub.add_parser("list", help="list imported dictionaries")

    look = sub.add_parser("lookup", help="exact term/reading lookup")
    look.add_argument("text")
    look.add_argument("--limit", type=int, default=16)

    scan = sub.add_parser("scan", help="longest dictionary prefix at the start of OCR text")
    scan.add_argument("text")
    scan.add_argument("--limit", type=int, default=16)
    scan.add_argument("--max-chars", type=int, default=32)

    kj = sub.add_parser("kanji", help="lookup kanji information for characters in text")
    kj.add_argument("text")

    rm = sub.add_parser("remove", help="remove an imported dictionary by exact title")
    rm.add_argument("title")
    return p


def main() -> int:
    args = parser().parse_args()
    try:
        db = connect(args.db)
        if args.command == "import":
            payload = import_dictionary(db, args.archive)
        elif args.command == "list":
            payload = list_dictionaries(db)
        elif args.command == "lookup":
            payload = lookup(db, args.text, max(1, min(args.limit, 100)))
        elif args.command == "scan":
            payload = scan_prefix(db, args.text, max(1, min(args.limit, 100)), max(1, min(args.max_chars, 128)))
        elif args.command == "kanji":
            payload = kanji_lookup(db, args.text)
        elif args.command == "remove":
            payload = remove_dictionary(db, args.title)
        else:
            raise AssertionError(args.command)
        emit(payload, pretty=args.pretty)
        return 0
    except (ValueError, OSError, sqlite3.Error, zipfile.BadZipFile) as exc:
        emit({"ok": False, "error": str(exc)}, pretty=args.pretty)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
