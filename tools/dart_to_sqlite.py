"""
Script to convert Quran Dart data files into a single SQLite database.

Input files (from quran_pages_with_ayah_detector):
  - lib/data/ayah_data.dart       → table: ayah_bbox
  - lib/data/quran_text_data.dart → table: quran_text_qcf (QCF text by page/line)
  - lib/data/quran_clean_plain.dart → table: quran_plain (plain Arabic, for search)
  - lib/data/quran_text.dart      → table: quran_tashkeel (vocalized Arabic)

Output:
  - assets/data/quran.db
"""

import re
import sqlite3
import os

# ── Paths ────────────────────────────────────────────────────────────────────
DART_DATA_DIR = r"c:\Users\rasmi\Downloads\quran_pages_with_ayah_detector-main\quran_pages_with_ayah_detector-main\lib\data"
OUTPUT_DB = r"c:\Users\rasmi\Projects\quran_project\assets\data\quran.db"

# ── Helpers ───────────────────────────────────────────────────────────────────

def read_file(name):
    path = os.path.join(DART_DATA_DIR, name)
    with open(path, encoding="utf-8") as f:
        return f.read()


# ── Parsers ───────────────────────────────────────────────────────────────────

def parse_ayah_data(src: str):
    """
    Parse const List<Map<String, Object?>> ayahRows = [ {...}, ... ]
    Returns list of dicts.
    """
    # Extract content between the outermost [ ... ]
    start = src.index("[")
    end = src.rindex("]")
    block = src[start + 1:end]

    rows = []
    # Each map: { "key": value, ... }
    for map_match in re.finditer(r'\{([^}]+)\}', block):
        entry = {}
        for kv in re.finditer(r'"(\w+)":\s*(-?\d+)', map_match.group(1)):
            entry[kv.group(1)] = int(kv.group(2))
        if entry:
            rows.append(entry)
    return rows


def parse_list_of_maps(src: str, string_key="content"):
    """
    Parse  List<Map<String, dynamic>> foo = [ {"key": val, ...}, ... ]
    where values are either integers or quoted strings.
    Returns list of dicts.
    """
    start = src.index("[")
    end = src.rindex("]")
    block = src[start + 1:end]

    rows = []
    for map_match in re.finditer(r'\{([^}]+)\}', block, re.DOTALL):
        entry = {}
        inner = map_match.group(1)
        # integers
        for kv in re.finditer(r'"(\w+)":\s*(-?\d+)', inner):
            entry[kv.group(1)] = int(kv.group(2))
        # strings (content field, may contain Arabic characters)
        for kv in re.finditer(r'"' + string_key + r'":\s*"([^"]*)"', inner):
            entry[string_key] = kv.group(1)
        # multi-line string with concatenation: "foo"\n  "bar"
        full_str = re.search(
            r'"' + string_key + r'":\s*((?:"[^"]*"\s*)+)', inner
        )
        if full_str:
            parts = re.findall(r'"([^"]*)"', full_str.group(1))
            entry[string_key] = "".join(parts)
        if entry:
            rows.append(entry)
    return rows


def parse_qcf_text_data(src: str):
    """
    Parse const List<List<String>> quranTextData = [ [...], [...], ... ]
    Index 0 = page 1. Each inner list = lines on that page.
    Returns list of (page, line_index, text).
    """
    # Find the outer list
    start = src.index("[")
    end = src.rindex("]")
    outer = src[start:end + 1]

    rows = []
    page = 1

    # Split by top-level inner lists using a simple bracket tracker
    depth = 0
    inner_start = None
    for i, ch in enumerate(outer):
        if ch == "[":
            depth += 1
            if depth == 2:
                inner_start = i + 1
        elif ch == "]":
            depth -= 1
            if depth == 1 and inner_start is not None:
                inner = outer[inner_start:i]
                # Extract quoted strings (QCF glyphs)
                lines = re.findall(r'"([^"]*)"', inner)
                for line_idx, text in enumerate(lines):
                    rows.append((page, line_idx + 1, text))
                page += 1
                inner_start = None

    return rows


# ── Database builder ──────────────────────────────────────────────────────────

def build_db():
    if os.path.exists(OUTPUT_DB):
        os.remove(OUTPUT_DB)

    conn = sqlite3.connect(OUTPUT_DB)
    cur = conn.cursor()

    # ── Table 1: ayah bounding boxes ─────────────────────────────────────────
    print("Parsing ayah_data.dart ...")
    ayah_rows = parse_ayah_data(read_file("ayah_data.dart"))
    cur.execute("""
        CREATE TABLE ayah_bbox (
            page   INTEGER NOT NULL,
            line   INTEGER NOT NULL,
            sura   INTEGER NOT NULL,
            ayah   INTEGER NOT NULL,
            min_x  INTEGER NOT NULL,
            max_x  INTEGER NOT NULL,
            min_y  INTEGER NOT NULL,
            max_y  INTEGER NOT NULL
        )
    """)
    cur.executemany(
        "INSERT INTO ayah_bbox VALUES (?,?,?,?,?,?,?,?)",
        [(r["page_number"], r["line_number"], r["sura_number"],
          r["ayah_number"], r["min_x"], r["max_x"], r["min_y"], r["max_y"])
         for r in ayah_rows]
    )
    cur.execute("CREATE INDEX idx_bbox_page ON ayah_bbox(page)")
    cur.execute("CREATE INDEX idx_bbox_sura_ayah ON ayah_bbox(sura, ayah)")
    print(f"  → {len(ayah_rows)} rows inserted into ayah_bbox")

    # ── Table 2: QCF text by page/line ───────────────────────────────────────
    print("Parsing quran_text_data.dart ...")
    qcf_rows = parse_qcf_text_data(read_file("quran_text_data.dart"))
    cur.execute("""
        CREATE TABLE quran_text_qcf (
            page      INTEGER NOT NULL,
            line      INTEGER NOT NULL,
            qcf_text  TEXT    NOT NULL
        )
    """)
    cur.executemany(
        "INSERT INTO quran_text_qcf VALUES (?,?,?)",
        qcf_rows
    )
    cur.execute("CREATE INDEX idx_qcf_page ON quran_text_qcf(page)")
    print(f"  → {len(qcf_rows)} rows inserted into quran_text_qcf")

    # ── Table 3: plain Arabic text (for search) ───────────────────────────────
    print("Parsing quran_clean_plain.dart ...")
    plain_rows = parse_list_of_maps(read_file("quran_clean_plain.dart"))
    cur.execute("""
        CREATE TABLE quran_plain (
            sura    INTEGER NOT NULL,
            ayah    INTEGER NOT NULL,
            content TEXT    NOT NULL
        )
    """)
    cur.executemany(
        "INSERT INTO quran_plain VALUES (?,?,?)",
        [(r["surah_number"], r["verse_number"], r.get("content", ""))
         for r in plain_rows]
    )
    cur.execute("CREATE INDEX idx_plain_sura ON quran_plain(sura, ayah)")
    # FTS5 table for full-text search
    cur.execute("""
        CREATE VIRTUAL TABLE quran_plain_fts USING fts5(
            content,
            content=quran_plain,
            content_rowid=rowid
        )
    """)
    cur.execute("INSERT INTO quran_plain_fts(quran_plain_fts) VALUES('rebuild')")
    print(f"  → {len(plain_rows)} rows inserted into quran_plain + FTS index")

    # ── Table 4: vocalized Arabic text (with tashkeel) ────────────────────────
    print("Parsing quran_text.dart ...")
    tashkeel_rows = parse_list_of_maps(read_file("quran_text.dart"))
    cur.execute("""
        CREATE TABLE quran_tashkeel (
            sura    INTEGER NOT NULL,
            ayah    INTEGER NOT NULL,
            content TEXT    NOT NULL
        )
    """)
    cur.executemany(
        "INSERT INTO quran_tashkeel VALUES (?,?,?)",
        [(r["surah_number"], r["verse_number"], r.get("content", ""))
         for r in tashkeel_rows]
    )
    cur.execute("CREATE INDEX idx_tashkeel_sura ON quran_tashkeel(sura, ayah)")
    print(f"  → {len(tashkeel_rows)} rows inserted into quran_tashkeel")

    conn.commit()
    conn.close()

    size_mb = os.path.getsize(OUTPUT_DB) / (1024 * 1024)
    print(f"\nDatabase created: {OUTPUT_DB}")
    print(f"Size: {size_mb:.2f} MB")


if __name__ == "__main__":
    build_db()
