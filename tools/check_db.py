import sqlite3
conn = sqlite3.connect(r'c:\Users\rasmi\Projects\quran_project\assets\data\quran.db')
cur = conn.cursor()
tables = cur.execute("SELECT name FROM sqlite_master WHERE type='table'").fetchall()
print("Tables:", [r[0] for r in tables])
print("ayah_bbox count:", cur.execute("SELECT COUNT(*) FROM ayah_bbox").fetchone()[0])
print("quran_plain count:", cur.execute("SELECT COUNT(*) FROM quran_plain").fetchone()[0])
print("quran_tashkeel count:", cur.execute("SELECT COUNT(*) FROM quran_tashkeel").fetchone()[0])
print("quran_text_qcf count:", cur.execute("SELECT COUNT(*) FROM quran_text_qcf").fetchone()[0])
print()
print("Sample ayah_bbox (page=2):")
for r in cur.execute("SELECT * FROM ayah_bbox WHERE page=2 LIMIT 3").fetchall():
    print(" ", r)
print()
print("Sample quran_plain (sura=1):")
for r in cur.execute("SELECT * FROM quran_plain WHERE sura=1 LIMIT 3").fetchall():
    print(" ", r)
conn.close()
