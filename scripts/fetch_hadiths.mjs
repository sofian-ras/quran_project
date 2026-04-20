/**
 * Fetch all hadiths from HadeethEnc API (French + Arabic) and save to assets/data/hadiths_fr.json
 *
 * Usage: node scripts/fetch_hadiths.mjs
 *
 * Output: assets/data/hadiths_fr.json
 */

import { writeFileSync, mkdirSync } from 'fs';
import { join, dirname } from 'path';
import { fileURLToPath } from 'url';

const __dirname = dirname(fileURLToPath(import.meta.url));
const OUTPUT_PATH = join(__dirname, '..', 'assets', 'data', 'hadiths_fr.json');
const BASE_URL = 'https://hadeethenc.com/api/v1';
const BATCH_SIZE = 10;
const RETRY_ATTEMPTS = 3;
const RETRY_DELAY_MS = 1000;
const BATCH_DELAY_MS = 200;

// ── Helpers ──────────────────────────────────────────────────────────────────

async function fetchWithRetry(url, attempt = 1) {
  try {
    const res = await fetch(url);
    if (res.status === 429 || res.status >= 500) {
      throw new Error(`HTTP ${res.status}`);
    }
    if (!res.ok) throw new Error(`HTTP ${res.status}`);
    return await res.json();
  } catch (err) {
    if (attempt >= RETRY_ATTEMPTS) throw err;
    await sleep(RETRY_DELAY_MS * attempt);
    return fetchWithRetry(url, attempt + 1);
  }
}

function sleep(ms) {
  return new Promise(r => setTimeout(r, ms));
}

async function processBatch(items, fn) {
  const results = [];
  for (let i = 0; i < items.length; i += BATCH_SIZE) {
    const chunk = items.slice(i, i + BATCH_SIZE);
    const chunkResults = await Promise.allSettled(chunk.map(fn));
    results.push(...chunkResults);
    if (i + BATCH_SIZE < items.length) await sleep(BATCH_DELAY_MS);
    process.stdout.write(`\r  ${Math.min(i + BATCH_SIZE, items.length)}/${items.length}`);
  }
  console.log();
  return results;
}

// ── Step 1: Walk category tree ───────────────────────────────────────────────

async function fetchAllCategories() {
  console.log('📂 Fetching root categories...');
  const roots = await fetchWithRetry(`${BASE_URL}/categories/roots/?language=fr`);
  const leafIds = [];
  await walkCategories(roots, leafIds);
  console.log(`   Found ${leafIds.length} leaf categories`);
  return leafIds;
}

async function walkCategories(categories, leafIds) {
  for (const cat of categories) {
    const id = cat.id ?? cat.ID;
    const hasChildren = cat.hadeeths_count === 0 || cat.children_count > 0;

    if (hasChildren) {
      try {
        const children = await fetchWithRetry(`${BASE_URL}/categories/list/?language=fr&parent_id=${id}`);
        if (Array.isArray(children) && children.length > 0) {
          await walkCategories(children, leafIds);
          continue;
        }
      } catch (_) {}
    }
    leafIds.push(id);
  }
}

// ── Step 2: Collect all hadith IDs from categories ───────────────────────────

async function collectHadithIds(categoryIds) {
  console.log('🔢 Collecting hadith IDs...');
  const allIds = new Set();

  for (const catId of categoryIds) {
    let page = 1;
    while (true) {
      try {
        const data = await fetchWithRetry(
          `${BASE_URL}/hadeeths/list/?language=fr&category_id=${catId}&page=${page}&per_page=50`
        );
        const items = data.data ?? data;
        if (!Array.isArray(items) || items.length === 0) break;
        for (const h of items) {
          const id = h.id ?? h.ID;
          if (id != null) allIds.add(id);
        }
        const meta = data.meta ?? data.pagination;
        if (!meta || page >= (meta.last_page ?? 1)) break;
        page++;
      } catch (_) {
        break;
      }
    }
  }

  console.log(`   Found ${allIds.size} unique hadiths`);
  return Array.from(allIds);
}

// ── Step 3: Fetch hadith details (FR + AR) ───────────────────────────────────

async function fetchHadithDetails(ids) {
  console.log('📥 Fetching hadith details (FR)...');
  const frResults = await processBatch(ids, async (id) => {
    return fetchWithRetry(`${BASE_URL}/hadeeths/one/?language=fr&id=${id}`);
  });

  console.log('📥 Fetching hadith details (AR)...');
  const arResults = await processBatch(ids, async (id) => {
    return fetchWithRetry(`${BASE_URL}/hadeeths/one/?language=ar&id=${id}`);
  });

  const hadiths = [];

  for (let i = 0; i < ids.length; i++) {
    const id = ids[i];
    const frResult = frResults[i];
    const arResult = arResults[i];

    if (frResult.status !== 'fulfilled') continue;

    const fr = frResult.value;
    const ar = arResult.status === 'fulfilled' ? arResult.value : null;

    hadiths.push({
      id: Number(id),
      arabic: (ar?.hadeeth ?? fr?.hadeeth_ar ?? '').trim(),
      french: (fr?.hadeeth ?? '').trim(),
      title: (fr?.title ?? '').trim(),
      explanation: (fr?.explanation ?? '').trim(),
    });
  }

  return hadiths.filter(h => h.french.length > 0);
}

// ── Main ─────────────────────────────────────────────────────────────────────

async function main() {
  console.log('🕌 HadeethEnc Hadith Fetcher\n');

  const categoryIds = await fetchAllCategories();
  const hadithIds = await collectHadithIds(categoryIds);
  const hadiths = await fetchHadithDetails(hadithIds);

  hadiths.sort((a, b) => a.id - b.id);

  mkdirSync(join(__dirname, '..', 'assets', 'data'), { recursive: true });
  writeFileSync(OUTPUT_PATH, JSON.stringify(hadiths, null, 2), 'utf8');

  console.log(`\n✅ Done! ${hadiths.length} hadiths saved to assets/data/hadiths_fr.json`);

  const sample = hadiths[0];
  if (sample) {
    console.log('\nSample:');
    console.log(`  id: ${sample.id}`);
    console.log(`  title: ${sample.title}`);
    console.log(`  arabic: ${sample.arabic.slice(0, 60)}...`);
    console.log(`  french: ${sample.french.slice(0, 80)}...`);
  }
}

main().catch(err => {
  console.error('❌ Error:', err.message);
  process.exit(1);
});
