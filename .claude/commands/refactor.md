---
description: Refactor the Quran project step by step — clean architecture, no breakage
argument-hint: [phase number or "status"]
---

You are a senior Flutter architect. Your mission: refactor this project phase by phase, safely,
without breaking existing functionality. Each phase is atomic and ends with a passing `flutter analyze`.

**Target architecture:**
```
lib/
  core/
    constants/     ← colors, sizes, strings (extracted from screens)
    utils/         ← helpers, extensions
  data/            ← all static Dart data files
  models/          ← data models
  services/        ← business logic (keep existing sub-folders)
  ui/
    screens/       ← ALL screens (no files loose in ui/)
    widgets/       ← all shared widgets
  theme/           ← theme (unchanged)
  main.dart
```

---

## Phase routing

If $ARGUMENTS is **"status"** → go to STATUS CHECK.
If $ARGUMENTS is a number (1–6) → go directly to that PHASE.
If $ARGUMENTS is empty → go to PHASE 0 (audit + ask which phase to run).

---

## STATUS CHECK

Read the current lib/ tree with a Bash `find lib -type f -name "*.dart" | sort` command.
Compare against the target architecture above.
Report which phases are done (✅), in progress (🔄), or not started (⬜).
Show the file count per folder.

---

## PHASE 0 — Audit

**0a. Map the current state**

Run: `find lib -type f -name "*.dart" | sort`
Run: `wc -l lib/main.dart lib/ui/home_screen.dart lib/services/audio_service.dart 2>/dev/null || true`

Report a table:
| File / Folder | Lines | Problem | Target phase |
|---|---|---|---|

**0b. Identify all import chains**

For each file that will move in phases 1–2, grep for its import path in all other files:
`grep -r "hizb_juzz\|surah_name" lib/ --include="*.dart" -l`
`grep -r "ui/home_screen\|ui/surah_list\|ui/reader_screen\|ui/dua_screen\|ui/settings_screen\|ui/statistics_screen\|ui/share_screen\|ui/tafsir\|ui/translated\|ui/reciter\|ui/full_player" lib/ --include="*.dart" -l`

**0c. Propose the execution order**

Print the phase list with estimated risk level (Low/Medium/High) and ask the user:
> "Which phase should I run? (1–6, or 'all' to run sequentially)"

---

## PHASE 1 — Data layer cleanup  *(Low risk)*

**Goal:** Move `lib/hizb_juzz.dart` and `lib/surah_name.dart` into `lib/data/`.

**Steps:**

1. Read `lib/hizb_juzz.dart` and `lib/surah_name.dart` in full.
2. Grep for every file importing them:
   `grep -r "hizb_juzz\|surah_name" lib/ --include="*.dart" -l`
3. For each file, note the import line to update.
4. Copy content to `lib/data/hizb_juzz.dart` and `lib/data/surah_name.dart`
   (use Write tool — keep content 100% identical, only the file path changes).
5. Delete original files (Bash: `rm lib/hizb_juzz.dart lib/surah_name.dart`).
6. In every file found in step 2, update the import path:
   - `import '../hizb_juzz.dart'` → `import '../data/hizb_juzz.dart'`
   - `import 'hizb_juzz.dart'` → `import 'data/hizb_juzz.dart'`
   (adjust relative depth based on the importing file's location)
7. Run: `flutter analyze lib/ 2>&1 | grep -E "error|warning" | head -30`
8. If errors: fix them before continuing.
9. Commit: `git add -A && git commit -m "refactor(data): move hizb_juzz and surah_name into lib/data/"`

---

## PHASE 2 — UI layer cleanup  *(Low risk)*

**Goal:** Move all loose screen files from `lib/ui/` into `lib/ui/screens/`.

Files to move (those directly in `lib/ui/*.dart`, NOT in `lib/ui/widgets/` or `lib/ui/screens/`):

Run first to get the exact list:
`find lib/ui -maxdepth 1 -name "*.dart" -type f`

For each screen file found:

1. Read the file.
2. Grep all files importing it:
   `grep -r "ui/<filename>" lib/ --include="*.dart" -l`
   Also check imports from within ui/ itself using relative `'<filename>.dart'`.
3. Write the file to `lib/ui/screens/<filename>.dart` (identical content).
4. Delete the original.
5. Update all imports in the files found in step 2:
   - From `lib/ui/`: `'../ui/<file>.dart'` → `'../ui/screens/<file>.dart'`
   - From `lib/ui/widgets/`: `'../<file>.dart'` → `'../screens/<file>.dart'`
   - From `lib/main.dart`: `'ui/<file>.dart'` → `'ui/screens/<file>.dart'`
   - From `lib/ui/screens/`: `'../<file>.dart'` stays at `'../<file>.dart'` (already correct if already in screens/)

   **Important:** process ALL files in one pass per screen before moving to the next.

6. After ALL screens are moved, run:
   `flutter analyze lib/ 2>&1 | grep -E "error|warning" | head -30`
7. Fix any remaining import issues.
8. Commit: `git add -A && git commit -m "refactor(ui): consolidate all screens into lib/ui/screens/"`

---

## PHASE 3 — Extract home_screen widgets  *(Medium risk)*

**Goal:** Break `lib/ui/home_screen.dart` (~2000 lines) into focused widget files,
without changing any logic.

**Steps:**

1. Read `lib/ui/home_screen.dart` fully.
2. Identify self-contained widget blocks (look for private `_SomeWidget` classes or
   `_buildSomething()` methods that return `Widget` and have no dependency on `HomeScreenState`
   fields except via parameters).
3. For each extractable widget:
   a. Create `lib/ui/widgets/<widget_name>.dart` with only that widget class.
   b. Add the import to `home_screen.dart`.
   c. Replace the inline definition with a reference to the new file.
4. Run `flutter analyze lib/` — fix any errors.
5. Commit: `git add -A && git commit -m "refactor(home): extract independent widgets from home_screen"`

**Rule:** Do NOT change any logic, state, or behavior. Pure mechanical extraction only.

---

## PHASE 4 — Decompose home_screen state  *(High risk — ask confirmation)*

**Goal:** Split `HomeScreen` God class into a controller + focused sub-sections.

**Before starting:** warn the user:
> "Phase 4 modifies home_screen.dart logic. This is the highest-risk phase.
> I recommend having a clean git state before proceeding. Continue? (yes/no)"

**Steps:**

1. Read the current `lib/ui/home_screen.dart` (post-phase 3).
2. Group the state variables and methods by concern:
   - **Navigation** (bottom nav index, page controller)
   - **Audio** (player state, reciter)
   - **Data loading** (daily verse, reciters list, last reading)
   - **UI toggles** (search overlay, side menu)
3. Create `lib/ui/screens/home/` folder with:
   - `home_screen.dart` — slim root widget, delegates to sub-sections
   - `home_controller.dart` — `ChangeNotifier` or `ValueNotifier` bundle for state
   - Named sub-widgets for each section (already extracted in phase 3)
4. Migrate state variables into `HomeController`.
5. Use `ListenableBuilder` or `ValueListenableBuilder` in the screen.
6. Run `flutter analyze lib/` — fix all errors.
7. Run a manual smoke test checklist (print it for the user to check):
   ```
   □ Home screen loads without crash
   □ Bottom navigation works
   □ Daily verse card shows
   □ Resume reading card shows
   □ Mini player appears when audio plays
   ```
8. Commit: `git add -A && git commit -m "refactor(home): extract HomeController, decompose God class"`

---

## PHASE 5 — Audio service cleanup  *(High risk — ask confirmation)*

**Goal:** Fix memory leaks in `audio_service.dart`, ensure `dispose()` is called.

**Before starting:** warn the user:
> "Phase 5 modifies audio_service.dart. Audio regression is possible.
> Ensure you can test audio playback before proceeding. Continue? (yes/no)"

**Steps:**

1. Read `lib/services/audio_service.dart` fully.
2. Identify:
   - All `ValueNotifier` fields → list them.
   - All `_player` / `_playerX` instances.
   - Whether `dispose()` method exists and is complete.
   - Whether `dispose()` is called anywhere (grep for `.dispose()`).
3. Fix issues in this priority order:
   a. **Missing dispose calls** — add `.dispose()` in the `dispose()` method for every
      ValueNotifier and every AudioPlayer instance.
   b. **Tag format bug** (line ~152) — ensure tag is a String `"suraNb:ayahNb"` not an int.
   c. **Playlist recreation** — if playlist is rebuilt from 114 sources on every play,
      cache it as a field and only rebuild when the reciter changes.
4. Run `flutter analyze lib/` — fix errors.
5. Commit: `git add -A && git commit -m "fix(audio): dispose ValueNotifiers and players, cache playlist, fix tag type"`

---

## PHASE 6 — Service instantiation  *(Medium risk)*

**Goal:** Convert static-only services to proper singletons injectable via constructor,
making them testable.

**Steps:**

1. Read `lib/services/quran_image_service.dart` and `lib/services/audio_download_service.dart`.
2. For each static service:
   a. Add a private constructor `QuranImageService._()`.
   b. Add `static final QuranImageService instance = QuranImageService._();`.
   c. Change all `static` methods to instance methods.
   d. Fix `_extractionProgress` to actually update during extraction (grep for
      `ZipDecoder` / extraction loop, add progress callback).
3. Update all call sites:
   `grep -r "QuranImageService\.\|AudioDownloadService\." lib/ --include="*.dart" -l`
   Replace `ServiceName.method()` with `ServiceName.instance.method()`.
4. Run `flutter analyze lib/` — fix errors.
5. Commit: `git add -A && git commit -m "refactor(services): convert static services to proper singletons"`

---

## After each phase — Standard validation

Always run these after any phase completes:

```bash
flutter analyze lib/ 2>&1 | grep -c "error"
```

If error count > 0: **stop, fix all errors, then re-validate before committing**.
Never commit with analyze errors.

---

## Final summary (after all phases)

```
Refactoring complete ✅

Phase 1 — Data layer:      ✅ / ⬜
Phase 2 — UI screens:      ✅ / ⬜
Phase 3 — Home widgets:    ✅ / ⬜
Phase 4 — Home controller: ✅ / ⬜
Phase 5 — Audio service:   ✅ / ⬜
Phase 6 — Service singletons: ✅ / ⬜

📁 Files created:  X
📁 Files moved:    Y
📁 Files modified: Z
📊 home_screen.dart: was ~2000 lines → now ~XXX lines
📊 audio_service.dart: was ~600 lines → now ~XXX lines
```
