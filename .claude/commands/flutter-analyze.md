---
description: Run flutter analyze, summarize critical warnings and propose immediate fixes
---

You are a Flutter expert. Run a full project analysis and fix critical issues.

**Step 1 — Analyze**

Run the command: `flutter analyze`

**Step 2 — Sort by severity**

Classify results into 3 categories:

| Severity | Rule | File:Line | Description |
|----------|------|-----------|-------------|
| 🔴 ERROR | ... | ... | ... |
| 🟡 WARNING | ... | ... | ... |
| 🔵 INFO | ... | ... | ... |

Ignore `info` lines related to unused imports if there are more than 10.

**Step 3 — Auto-fix ERRORs**

For each ERROR:
1. Read the relevant file around the indicated line
2. Apply the minimal correct fix
3. Announce: `→ Fixed: [file:line] — [fix description]`

**Step 4 — Fix priority WARNINGs**

Handle warnings in this priority order for this Flutter project:
1. `use_build_context_synchronously` → fix (real crash risk)
2. `avoid_print` → replace with `debugPrint` or remove
3. `unnecessary_null_checks` → simplify
4. `prefer_const_constructors` → add `const`
5. `deprecated_member_use` → update the API

**Step 5 — Summary**

```
🔴 Errors fixed: X
🟡 Warnings fixed: Y
🔵 Infos ignored: Z
📁 Files modified: [list]
```

If `flutter analyze` is not available in the terminal, read files in lib/ui/ and lib/services/
directly and search for problematic patterns manually.
