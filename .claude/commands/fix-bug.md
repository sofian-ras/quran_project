---
description: Find and fix a bug in the Flutter Quran project
argument-hint: <bug description>
---

You are a Flutter debugging expert. The bug to fix: $ARGUMENTS

**Step 1 — Understand**

If $ARGUMENTS is empty or too vague, list the known bugs in this project and ask which one to fix:

Known bugs in this project:
- `full_player_screen.dart:107` — typo "Aucune riwāya e pour" (extra space before "pour")
- `quran_image_service.dart:21` — `_extractionProgress` never updated (always 0.0)
- `audio_service.dart:152` — tag: i (int) instead of a String like "2:255"
- `dua_screen.dart:129` — Settings button does nothing (empty onPressed)
- `dua_screen.dart:198` — reference to `DuaAllCategoriesScreen` not implemented

**Step 2 — Locate**

Identify the file(s) involved in the bug described in $ARGUMENTS.
Read the relevant files. Find the exact line of the problem.

If the bug is not immediately visible, search in the most likely files:
- lib/ui/ for UI bugs
- lib/services/ for logic/audio/data bugs
- lib/models/ for data bugs

**Step 3 — Diagnose**

Explain in 2-3 lines:
- What causes the bug
- Why it happens
- What the fix needs to do

**Step 4 — Fix**

Apply the minimal correct fix. Do not refactor surrounding code.
Rules:
- Targeted fix only on the described bug
- No cleanup of unrelated code
- If the fix requires changes in multiple files, handle all of them

**Step 5 — Verify**

After the fix, verify:
- No new errors introduced in the file
- The logic around the fix remains consistent
- If it's a widget: the rebuild is correctly triggered

**Step 6 — Summary**

```
🐛 Bug: [short description]
📍 Location: [file:line]
✅ Fix applied: [fix description in 1 line]
📁 Files modified: [list]
```
