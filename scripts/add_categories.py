"""
Adds category_id / category_name to the existing hadiths_fr.json
by querying only the 7 root categories (no re-fetching of hadith details).
Usage: python scripts/add_categories.py
"""

import json
import time
import os
import sys
from urllib.request import urlopen, Request
from urllib.error import HTTPError, URLError

BASE_URL = "https://hadeethenc.com/api/v1"
JSON_PATH = os.path.join(os.path.dirname(__file__), "..", "assets", "data", "hadiths_fr.json")


def fetch_json(url, attempt=1):
    try:
        req = Request(url, headers={"User-Agent": "Mozilla/5.0", "Accept": "application/json"})
        with urlopen(req, timeout=15) as res:
            return json.loads(res.read().decode("utf-8"))
    except HTTPError as e:
        if e.code in (429, 500, 502, 503) and attempt < 4:
            time.sleep(attempt * 1.5)
            return fetch_json(url, attempt + 1)
        raise
    except URLError:
        if attempt < 4:
            time.sleep(attempt * 1.5)
            return fetch_json(url, attempt + 1)
        raise


def build_category_map():
    """Returns {hadith_id: (root_id, root_name)} using only root-level list endpoints."""
    print("[1] Fetching root categories...")
    roots = fetch_json(f"{BASE_URL}/categories/roots/?language=fr")
    print(f"    {len(roots)} root categories found")

    hadith_cat = {}

    for root in roots:
        root_id = str(root.get("id") or root.get("ID"))
        root_name = (root.get("title") or root.get("name") or f"Cat {root_id}").strip()
        print(f"[2] Paginating root: {root_name} (id={root_id})")

        page = 1
        total_pages = None
        while True:
            data = fetch_json(
                f"{BASE_URL}/hadeeths/list/?language=fr&category_id={root_id}&page={page}&per_page=100"
            )
            items = data.get("data", data) if isinstance(data, dict) else data
            if not isinstance(items, list) or not items:
                break

            for h in items:
                h_id = int(h.get("id") or h.get("ID"))
                if h_id not in hadith_cat:
                    hadith_cat[h_id] = (root_id, root_name)

            meta = data.get("meta") or data.get("pagination") if isinstance(data, dict) else None
            if total_pages is None and meta:
                total_pages = meta.get("last_page", 1)

            sys.stdout.write(f"\r    page {page}/{total_pages or '?'}  ({len(hadith_cat)} hadiths mapped)")
            sys.stdout.flush()

            if not meta or page >= meta.get("last_page", 1):
                break
            page += 1
            time.sleep(0.2)

        print()

    return hadith_cat


def main():
    print("Adding categories to existing hadiths_fr.json\n")

    hadith_cat = build_category_map()
    print(f"\nMapped {len(hadith_cat)} hadiths to categories")

    print("[3] Loading existing JSON...")
    with open(JSON_PATH, encoding="utf-8") as f:
        hadiths = json.load(f)

    matched = 0
    for h in hadiths:
        cat = hadith_cat.get(h["id"])
        if cat:
            h["category_id"] = cat[0]
            h["category_name"] = cat[1]
            matched += 1
        else:
            h.setdefault("category_id", "")
            h.setdefault("category_name", "")

    print(f"    {matched}/{len(hadiths)} hadiths got a category")

    with open(JSON_PATH, "w", encoding="utf-8") as f:
        json.dump(hadiths, f, ensure_ascii=False, indent=2)

    from collections import Counter
    cats = Counter(h["category_name"] for h in hadiths if h["category_name"])
    print(f"\nDone! Saved to assets/data/hadiths_fr.json")
    print("\nRepartition par theme:")
    for name, count in sorted(cats.items(), key=lambda x: -x[1]):
        print(f"  {count:4d}  {name}")


if __name__ == "__main__":
    main()
