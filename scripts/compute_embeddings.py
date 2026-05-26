"""
Script de pré-calcul des embeddings pour le RAG coranique.

Usage :
    pip install sentence-transformers sqlite3
    python compute_embeddings.py --db path/to/translation_fr.sqlite --out assets/data/ayah_embeddings.db

Ce script lit les versets depuis le SQLite de traduction française,
calcule un embedding 384-dim avec all-MiniLM-L6-v2, et stocke le résultat
dans un SQLite séparé. Le fichier généré peut être bundlé dans assets/data/.

Taille attendue : ~10 MB pour 6236 versets × 384 floats × 4 bytes.

NOTE : Ce script est destiné à une phase 2. L'app actuelle utilise
       une recherche par mots-clés (rag_chat_service.dart) qui n'a pas
       besoin de ce fichier.
"""

import argparse
import sqlite3
import struct
import os
from pathlib import Path

try:
    from sentence_transformers import SentenceTransformer
except ImportError:
    print("Installez sentence-transformers : pip install sentence-transformers")
    raise


def detect_schema(cursor):
    """Détecte le nom de table et les colonnes disponibles."""
    cursor.execute("SELECT name FROM sqlite_master WHERE type='table'")
    tables = [r[0] for r in cursor.fetchall()]
    for table in tables:
        cursor.execute(f"PRAGMA table_info('{table}')")
        cols = {r[1].lower() for r in cursor.fetchall()}
        if 'verse_key' in cols:
            text_col = next((c for c in ['text', 'value', 'translation', 'content'] if c in cols), None)
            if text_col:
                return table, 'verse_key', None, text_col
        if 'surah' in cols and 'ayah' in cols:
            text_col = next((c for c in ['fr', 'text', 'value', 'translation'] if c in cols), None)
            if text_col:
                return table, None, ('surah', 'ayah'), text_col
    raise ValueError(f"Schéma non reconnu dans : {tables}")


def load_verses(db_path):
    conn = sqlite3.connect(db_path)
    cur = conn.cursor()
    table, vk_col, sa_cols, text_col = detect_schema(cur)

    if vk_col:
        cur.execute(f"SELECT {vk_col}, {text_col} FROM {table} ORDER BY {vk_col}")
        rows = cur.fetchall()
        verses = []
        for vk, text in rows:
            if not vk or not text:
                continue
            parts = str(vk).split(':')
            if len(parts) != 2:
                continue
            s, a = int(parts[0]), int(parts[1])
            verses.append((s, a, str(text)))
    else:
        sc, ac = sa_cols
        cur.execute(f"SELECT {sc}, {ac}, {text_col} FROM {table} ORDER BY {sc}, {ac}")
        verses = [(int(r[0]), int(r[1]), str(r[2])) for r in cur.fetchall() if r[2]]

    conn.close()
    print(f"  {len(verses)} versets chargés depuis {db_path}")
    return verses


def pack_embedding(vec):
    """Sérialise un vecteur float32 en bytes."""
    return struct.pack(f'{len(vec)}f', *vec)


def compute_and_store(db_path, out_path, batch_size=64):
    print(f"Chargement du modèle all-MiniLM-L6-v2...")
    model = SentenceTransformer('all-MiniLM-L6-v2')

    verses = load_verses(db_path)

    out_conn = sqlite3.connect(out_path)
    out_conn.execute("""
        CREATE TABLE IF NOT EXISTS ayah_embeddings (
            surah   INTEGER NOT NULL,
            ayah    INTEGER NOT NULL,
            vector  BLOB    NOT NULL,
            PRIMARY KEY (surah, ayah)
        )
    """)
    out_conn.commit()

    texts = [v[2] for v in verses]
    total = len(texts)
    print(f"Calcul de {total} embeddings par batches de {batch_size}...")

    for start in range(0, total, batch_size):
        batch_texts = texts[start:start + batch_size]
        batch_meta  = verses[start:start + batch_size]
        embeddings  = model.encode(batch_texts, normalize_embeddings=True)

        rows = [
            (meta[0], meta[1], pack_embedding(emb.tolist()))
            for meta, emb in zip(batch_meta, embeddings)
        ]
        out_conn.executemany(
            "INSERT OR REPLACE INTO ayah_embeddings (surah, ayah, vector) VALUES (?,?,?)",
            rows,
        )
        out_conn.commit()
        done = min(start + batch_size, total)
        print(f"  {done}/{total} ({100*done//total}%)", end='\r')

    out_conn.close()
    size_mb = os.path.getsize(out_path) / 1_000_000
    print(f"\nFichier généré : {out_path} ({size_mb:.1f} MB)")
    print("Ajoutez ce fichier dans assets/data/ et déclarez-le dans pubspec.yaml.")


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description='Calcule les embeddings des ayahs coraniques.')
    parser.add_argument('--db',  required=True, help='Chemin vers translation_fr.sqlite')
    parser.add_argument('--out', default='assets/data/ayah_embeddings.db',
                        help='Chemin de sortie (défaut: assets/data/ayah_embeddings.db)')
    parser.add_argument('--batch', type=int, default=64, help='Taille des batches')
    args = parser.parse_args()

    Path(args.out).parent.mkdir(parents=True, exist_ok=True)
    compute_and_store(args.db, args.out, args.batch)
