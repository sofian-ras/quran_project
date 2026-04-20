"""
Fetch all hadiths from HadeethEnc API (French + Arabic) with categories.
Usage: python scripts/fetch_hadiths.py
Output: assets/data/hadiths_fr.json
"""

import json
import time
import os
import sys
from urllib.request import urlopen, Request
from urllib.error import HTTPError, URLError
from concurrent.futures import ThreadPoolExecutor, as_completed

BASE_URL = "https://hadeethenc.com/api/v1"
OUTPUT_PATH = os.path.join(os.path.dirname(__file__), "..", "assets", "data", "hadiths_fr.json")
BATCH_SIZE = 10
RETRY_ATTEMPTS = 3
RETRY_DELAY = 1.0
BATCH_DELAY = 0.3


def fetch_json(url, attempt=1):
    try:
        req = Request(url, headers={"User-Agent": "Mozilla/5.0", "Accept": "application/json"})
        with urlopen(req, timeout=15) as res:
            return json.loads(res.read().decode("utf-8"))
    except HTTPError as e:
        if e.code in (429, 500, 502, 503) and attempt < RETRY_ATTEMPTS:
            time.sleep(RETRY_DELAY * attempt)
            return fetch_json(url, attempt + 1)
        raise
    except URLError:
        if attempt < RETRY_ATTEMPTS:
            time.sleep(RETRY_DELAY * attempt)
            return fetch_json(url, attempt + 1)
        raise


# ── Step 1: Walk category tree ────────────────────────────────────────────────
# Returns list of (leaf_id, root_name, root_id) tuples

def fetch_category_tree():
    print("[1] Fetching category tree...")
    roots = fetch_json(f"{BASE_URL}/categories/roots/?language=fr")
    leaves = []  # list of (leaf_id, root_name, root_id)
    for root in roots:
        root_id = str(root.get("id") or root.get("ID"))
        root_name = (root.get("title") or root.get("name") or f"Cat {root_id}").strip()
        walk_categories(root_id, root_name, root_id, root_name, leaves, depth=0)
    print(f"   Found {len(leaves)} leaf categories under {len(roots)} root themes")
    return leaves


def walk_categories(cat_id, cat_name, root_id, root_name, leaves, depth):
    children_count = 0
    hadeeths_count = 0
    try:
        children = fetch_json(f"{BASE_URL}/categories/list/?language=fr&parent_id={cat_id}")
        if isinstance(children, list) and children:
            for child in children:
                c_id = str(child.get("id") or child.get("ID"))
                c_name = (child.get("title") or child.get("name") or f"Cat {c_id}").strip()
                walk_categories(c_id, c_name, root_id, root_name, leaves, depth + 1)
            return
    except Exception:
        pass

    # It's a leaf
    leaves.append({
        "leaf_id": cat_id,
        "leaf_name": cat_name,
        "root_id": root_id,
        "root_name": root_name,
    })


# ── Step 2: Collect hadith IDs with category info ─────────────────────────────

def collect_hadith_ids_with_categories(leaves):
    print("[2] Collecting hadith IDs from categories...")
    # hadith_id -> first category info encountered
    hadith_category = {}

    for i, leaf in enumerate(leaves):
        cat_id = leaf["leaf_id"]
        page = 1
        while True:
            try:
                data = fetch_json(
                    f"{BASE_URL}/hadeeths/list/?language=fr&category_id={cat_id}&page={page}&per_page=50"
                )
                items = data.get("data", data) if isinstance(data, dict) else data
                if not isinstance(items, list) or not items:
                    break
                for h in items:
                    h_id = int(h.get("id") or h.get("ID"))
                    if h_id not in hadith_category:
                        hadith_category[h_id] = leaf
                meta = data.get("meta") or data.get("pagination") if isinstance(data, dict) else None
                if not meta or page >= meta.get("last_page", 1):
                    break
                page += 1
            except Exception:
                break
        sys.stdout.write(f"\r   {i+1}/{len(leaves)} categories processed")
        sys.stdout.flush()

    print()
    print(f"   Found {len(hadith_category)} unique hadiths")
    return hadith_category


# ── Step 3: Fetch hadith details ──────────────────────────────────────────────

def fetch_detail(hadith_id, lang):
    try:
        return fetch_json(f"{BASE_URL}/hadeeths/one/?language={lang}&id={hadith_id}")
    except Exception:
        return None


def fetch_all_details(hadith_category):
    ids = sorted(hadith_category.keys())
    print(f"[3] Fetching details for {len(ids)} hadiths (FR + AR)...")
    hadiths = []
    total = len(ids)

    for batch_start in range(0, total, BATCH_SIZE):
        batch = ids[batch_start:batch_start + BATCH_SIZE]

        with ThreadPoolExecutor(max_workers=BATCH_SIZE) as ex:
            fr_futures = {ex.submit(fetch_detail, hid, "fr"): hid for hid in batch}
            ar_futures = {ex.submit(fetch_detail, hid, "ar"): hid for hid in batch}

            fr_results = {}
            for f in as_completed(fr_futures):
                hid = fr_futures[f]
                fr_results[hid] = f.result()

            ar_results = {}
            for f in as_completed(ar_futures):
                hid = ar_futures[f]
                ar_results[hid] = f.result()

        for hid in batch:
            fr = fr_results.get(hid)
            ar = ar_results.get(hid)
            if not fr:
                continue

            french = (fr.get("hadeeth") or "").strip()
            if not french:
                continue

            arabic = (
                (ar.get("hadeeth") if ar else None)
                or fr.get("hadeeth_ar")
                or ""
            ).strip()

            cat = hadith_category.get(hid, {})

            hadiths.append({
                "id": int(hid),
                "arabic": arabic,
                "french": french,
                "title": (fr.get("title") or "").strip(),
                "explanation": (fr.get("explanation") or "").strip(),
                "category_id": cat.get("root_id", ""),
                "category_name": cat.get("root_name", ""),
            })

        done = min(batch_start + BATCH_SIZE, total)
        sys.stdout.write(f"\r   {done}/{total} hadiths fetched")
        sys.stdout.flush()
        if batch_start + BATCH_SIZE < total:
            time.sleep(BATCH_DELAY)

    print()
    return hadiths


# ── Main ──────────────────────────────────────────────────────────────────────

def main():
    print("HadeethEnc Hadith Fetcher (Python)\n")

    leaves = fetch_category_tree()
    hadith_category = collect_hadith_ids_with_categories(leaves)

    if not hadith_category:
        print("ERROR: No hadiths found. Check API availability.")
        sys.exit(1)

    hadiths = fetch_all_details(hadith_category)
    hadiths.sort(key=lambda h: h["id"])

    os.makedirs(os.path.dirname(OUTPUT_PATH), exist_ok=True)
    with open(OUTPUT_PATH, "w", encoding="utf-8") as f:
        json.dump(hadiths, f, ensure_ascii=False, indent=2)

    # Stats par categorie
    from collections import Counter
    cats = Counter(h["category_name"] for h in hadiths)
    print(f"\nDone! {len(hadiths)} hadiths saved to assets/data/hadiths_fr.json")
    print("\nRepartition par theme:")
    for name, count in sorted(cats.items(), key=lambda x: -x[1]):
        print(f"  {count:4d}  {name}")


if __name__ == "__main__":
    main()
