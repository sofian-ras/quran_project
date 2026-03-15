"""
generate_mushaf_db.py
---------------------
Génère assets/data/Mushaf/mushaf.db à partir des sources existantes.

Tables créées :
  surahs      — métadonnées des 114 sourates
  pages       — première sourate/verset de chaque page
  page_lines  — texte QCF par page et par ligne  (rendu)
  ayah_rects  — coordonnées des boîtes de verset  (tap detection)
  verses      — texte par lecture (hafs, warsh…)  (affichage/copie)
  verses_fts  — FTS5 sur texte plain              (recherche)

Sources :
  assets/data/quran_data.json
  packages/quran_pages_with_ayah_detector/lib/data/quran_clean_plain.dart
  packages/quran_pages_with_ayah_detector/lib/data/quran_text_data.dart
  packages/quran_pages_with_ayah_detector/lib/data/ayah_data.json
  packages/quran_pages_with_ayah_detector/lib/data/is_madani.dart
  packages/quran_pages_with_ayah_detector/lib/data/surah_number_of_ayahs.dart
  lib/surah_name.dart
"""

import json, re, sqlite3, os, sys

ROOT = os.path.normpath(os.path.join(os.path.dirname(__file__), ".."))
OUT  = os.path.join(ROOT, "assets", "data", "Mushaf", "mushaf.db")

os.makedirs(os.path.dirname(OUT), exist_ok=True)
if os.path.exists(OUT):
    os.remove(OUT)

con = sqlite3.connect(OUT)
cur = con.cursor()

# ── Helpers ───────────────────────────────────────────────────────────────────

def read(rel):
    return open(os.path.join(ROOT, rel), encoding="utf-8").read()

def parse_int_map(dart_src, var_name):
    """Extrait {int: int} depuis une variable Dart."""
    body = re.search(
        rf'{var_name}\s*=\s*\{{(.*?)\}};',
        dart_src, re.DOTALL
    ).group(1)
    return {int(k): int(v) for k, v in re.findall(r'(\d+):\s*(\w+)', body)}

def parse_bool_map(dart_src, var_name):
    """Extrait {int: bool} depuis une variable Dart."""
    body = re.search(
        rf'{var_name}\s*=\s*\{{(.*?)\}};',
        dart_src, re.DOTALL
    ).group(1)
    return {int(k): (v == 'true') for k, v in re.findall(r'(\d+):\s*(true|false)', body)}

def parse_str_map(dart_src, var_name):
    """Extrait {int: str} depuis une variable Dart."""
    body = re.search(
        rf'{var_name}\s*=\s*\{{(.*?)\}};',
        dart_src, re.DOTALL
    ).group(1)
    return {int(k): v for k, v in re.findall(r"(\d+):\s*'(.*?)'", body)}

# ── 1. Charger les sources ────────────────────────────────────────────────────

print("Chargement des sources…")

quran_data = json.loads(read("assets/data/quran_data.json"))
ayah_data  = json.loads(
    read("packages/quran_pages_with_ayah_detector/lib/data/ayah_data.json")
)

# is_madani
is_madani_src = read(
    "packages/quran_pages_with_ayah_detector/lib/data/is_madani.dart"
)
is_madani = parse_bool_map(is_madani_src, "isMadani")

# ayah_count par sourate
ayah_count_src = read(
    "packages/quran_pages_with_ayah_detector/lib/data/surah_number_of_ayahs.dart"
)
ayah_count = parse_int_map(ayah_count_src, "suraNumberOfAyahs")

# noms français
surah_fr_src = read("lib/surah_name.dart")
# Les apostrophes sont échappées dans le Dart : \'
surah_fr_src_clean = surah_fr_src.replace("\\'", "\x00")
surah_fr = {}
for k, v in re.findall(r"(\d+):\s*'(.*?)'", surah_fr_src_clean):
    surah_fr[int(k)] = v.replace("\x00", "'")

# quran_text_data  — List<List<String>> indexé 0-based (page-1)
qt_src = read(
    "packages/quran_pages_with_ayah_detector/lib/data/quran_text_data.dart"
)
# On extrait toutes les chaînes entre guillemets après le = [
# Structure : [[line, line, …], [line, line, …], …]
# Chaque page est un sous-tableau.  On parse via regex.
qt_raw = re.findall(r'"([^"]*)"', qt_src)  # toutes les strings
# Reconstruit par page via les blocs [ … ] imbriqués dans le tableau principal
# Approche : enlever l'en-tête Dart puis eval-like parsing
# On split par pages en cherchant les blocs de lignes dans le Dart
page_blocks = re.findall(r'\[((?:[^[\]]*|\[[^\]]*\])*)\]', qt_src[qt_src.index('= [') + 3:])
quran_text_pages = []
for block in page_blocks:
    lines = re.findall(r'"([^"]*)"', block)
    if lines:
        quran_text_pages.append(lines)

print(f"  quran_data       : {len(quran_data)} versets")
print(f"  ayah_data        : {len(ayah_data)} pages")
print(f"  quran_text_pages : {len(quran_text_pages)} pages")
print(f"  surah_fr         : {len(surah_fr)} sourates")

# quran_clean_plain — recherche
qcp_src = read(
    "packages/quran_pages_with_ayah_detector/lib/data/quran_clean_plain.dart"
)
# Structure : [{"surah_number": N, "verse_number": N, "content": "…"}, …]
qcp_rows = []
for m in re.finditer(
    r'"surah_number":\s*(\d+),\s*"verse_number":\s*(\d+),\s*"content":\s*"([^"]*)"',
    qcp_src
):
    qcp_rows.append((int(m.group(1)), int(m.group(2)), m.group(3)))
print(f"  quran_clean_plain: {len(qcp_rows)} versets")

# ── 2. Créer les tables ───────────────────────────────────────────────────────

print("\nCréation des tables…")

cur.executescript("""
PRAGMA journal_mode = WAL;
PRAGMA encoding = 'UTF-8';

CREATE TABLE surahs (
    id        INTEGER PRIMARY KEY,
    name_ar   TEXT    NOT NULL,
    name_fr   TEXT    NOT NULL,
    page_start INTEGER NOT NULL,
    ayah_count INTEGER NOT NULL,
    is_madani  INTEGER NOT NULL DEFAULT 0
);

CREATE TABLE pages (
    page        INTEGER PRIMARY KEY,
    surah_start INTEGER NOT NULL,
    ayah_start  INTEGER NOT NULL
);

CREATE TABLE page_lines (
    page        INTEGER NOT NULL,
    line_number INTEGER NOT NULL,
    text_qcf    TEXT    NOT NULL,
    PRIMARY KEY (page, line_number)
);

CREATE TABLE ayah_rects (
    page   INTEGER NOT NULL,
    surah  INTEGER NOT NULL,
    ayah   INTEGER NOT NULL,
    line   INTEGER NOT NULL,
    x0     INTEGER NOT NULL,
    y0     INTEGER NOT NULL,
    x1     INTEGER NOT NULL,
    y1     INTEGER NOT NULL
);
CREATE INDEX idx_ayah_rects_page ON ayah_rects (page);
CREATE INDEX idx_ayah_rects_surah_ayah ON ayah_rects (surah, ayah);

CREATE TABLE verses (
    surah INTEGER NOT NULL,
    ayah  INTEGER NOT NULL,
    page  INTEGER NOT NULL,
    hafs  TEXT,
    warsh TEXT,
    PRIMARY KEY (surah, ayah)
);
CREATE INDEX idx_verses_page ON verses (page);

CREATE VIRTUAL TABLE verses_fts USING fts5(
    surah UNINDEXED,
    ayah  UNINDEXED,
    text_plain,
    tokenize = 'unicode61'
);
""")

# ── 3. Remplir surahs ─────────────────────────────────────────────────────────

print("Insertion surahs…")

# page_start de chaque sourate depuis quran_data (premier ayah=1 de chaque sourate)
surah_page_start = {}
for row in quran_data:
    s = row["surah"]
    if s not in surah_page_start:
        surah_page_start[s] = row["page"]

# name_ar depuis quran_data (sura_name du premier verset de chaque sourate)
surah_name_ar = {}
for row in quran_data:
    s = row["surah"]
    if s not in surah_name_ar and row.get("sura_name"):
        surah_name_ar[s] = row["sura_name"]

surahs_rows = []
for sid in range(1, 115):
    surahs_rows.append((
        sid,
        surah_name_ar.get(sid, f"Sourate {sid}"),
        surah_fr.get(sid, f"Sourate {sid}"),
        surah_page_start.get(sid, 1),
        ayah_count.get(sid, 0),
        1 if is_madani.get(sid, False) else 0,
    ))
cur.executemany(
    "INSERT INTO surahs VALUES (?,?,?,?,?,?)",
    surahs_rows
)

# ── 4. Remplir pages ──────────────────────────────────────────────────────────

print("Insertion pages…")

# Pour chaque page, trouver la première sourate/verset
page_first = {}  # page → (surah, ayah)
for row in quran_data:
    p = int(row["page"])
    if p not in page_first:
        page_first[p] = (row["surah"], row["ayah"])

cur.executemany(
    "INSERT INTO pages VALUES (?,?,?)",
    [(p, sa[0], sa[1]) for p, sa in sorted(page_first.items())]
)

# ── 5. Remplir page_lines ─────────────────────────────────────────────────────

print("Insertion page_lines…")

page_lines_rows = []
for page_idx, lines in enumerate(quran_text_pages):
    page_num = page_idx + 1
    for line_idx, text in enumerate(lines):
        page_lines_rows.append((page_num, line_idx + 1, text))

cur.executemany(
    "INSERT INTO page_lines VALUES (?,?,?)",
    page_lines_rows
)
print(f"  {len(page_lines_rows)} lignes insérées")

# ── 6. Remplir ayah_rects ─────────────────────────────────────────────────────

print("Insertion ayah_rects…")

rects_rows = []
for page_str, rows in ayah_data.items():
    page = int(page_str)
    for r in rows:
        ln, sn, an, x0, y0, x1, y1 = r
        rects_rows.append((page, sn, an, ln, x0, y0, x1, y1))

cur.executemany(
    "INSERT INTO ayah_rects VALUES (?,?,?,?,?,?,?,?)",
    rects_rows
)
print(f"  {len(rects_rows)} rectangles insérés")

# ── 7. Remplir verses ─────────────────────────────────────────────────────────

print("Insertion verses…")

verses_rows = [
    (row["surah"], row["ayah"], row["page"],
     row.get("hafs"), row.get("warsh"))
    for row in quran_data
]
cur.executemany(
    "INSERT OR IGNORE INTO verses VALUES (?,?,?,?,?)",
    verses_rows
)
print(f"  {len(verses_rows)} versets insérés")

# ── 8. Remplir verses_fts ─────────────────────────────────────────────────────

print("Insertion verses_fts (FTS5)…")

cur.executemany(
    "INSERT INTO verses_fts VALUES (?,?,?)",
    qcp_rows
)
print(f"  {len(qcp_rows)} versets indexés pour la recherche")

# ── 9. Finaliser ──────────────────────────────────────────────────────────────

con.commit()
con.close()

size_kb = os.path.getsize(OUT) // 1024
print(f"\nFINI  ->  {OUT}")
print(f"Taille : {size_kb} KB ({size_kb // 1024} MB)")
