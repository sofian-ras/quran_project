---
description: Targeted diagnosis of audio_service.dart — ValueNotifiers, dispose, memory leaks, player states
---

You are a Flutter audio expert. Perform a complete diagnosis of the audio service in this Quran app.

**Project context:**
- `lib/services/audio_service.dart` — singleton, 600+ lines, 2 players (full surah + ayah-by-ayah)
- 20+ ValueNotifiers declared
- Risk: dispose() never called → memory leaks
- Known bug: tag: i (int) whereas it expects a String like "2:255"

**Step 1 — Read**

Read `lib/services/audio_service.dart` in full.

**Step 2 — ValueNotifier audit**

List all declared ValueNotifiers. For each one, check:
- [ ] Is it correctly initialized?
- [ ] Is it disposed in `dispose()`?
- [ ] Is it listened to without ever being cancelled (listener leak)?

Display a table:

| ValueNotifier | Initialized | Disposed | Listeners cancelled | Status |
|---------------|-------------|----------|---------------------|--------|
| ... | ✅/❌ | ✅/❌ | ✅/❌ | OK/LEAK |

**Step 3 — Dual player audit**

For each player (surah player + ayah player):
- Verify that `dispose()` is called
- Verify that streams are cancelled (StreamSubscription.cancel())
- Verify state handling (playing, paused, stopped, error)
- Identify cases where a player could be used after dispose

**Step 4 — Known bugs to verify**

Check and fix if present:
1. **Tag int vs String** — find `tag: i` or `tag: index` where i is an int → must be a String like `"${surahNumber}:${ayahNumber}"`
2. **Playlist recreated on every play** — check if 114 AudioSources are recreated on each play call → cache the playlist
3. **dispose() never called** — check if the singleton has any cleanup mechanism

**Step 5 — Fixes**

Apply corrections for:
- Undisposed ValueNotifiers (add them to dispose())
- The int→String tag bug
- Uncancelled StreamSubscriptions

**Step 6 — Final report**

```
🔴 Critical leaks found/fixed: X
🟡 Bugs fixed: Y
🔵 Warnings (unfixed, require refactor): Z
📁 Files modified: lib/services/audio_service.dart
```

For issues requiring a larger refactor (e.g. playlist cache),
add a TODO comment in the code with a precise description.
