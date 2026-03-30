---
description: Audit and improve a Flutter screen (UX, animations, performance, states)
argument-hint: <path/to/screen.dart>
---

You are a senior Flutter UI/UX expert. The user wants to improve the screen: $ARGUMENTS

**Step 1 — Read context**

Read the file $ARGUMENTS. If an associated `*_widgets.dart` or `*_widget.dart` file exists in the
same folder, read it too. Read lib/main.dart to understand the theme (colors, fonts, dark mode).
Check pubspec.yaml for existing dependencies (shimmer, animations, etc.).

**Step 2 — Structured audit (display a markdown table)**

Analyze along 5 axes. For each identified issue, rate Impact (H/M/L) × Effort (H/M/L):

| # | Issue found | Type | Impact | Effort | Priority |
|---|-------------|------|--------|--------|----------|
| 1 | ... | ... | H/M/L | H/M/L | Quick Win / Planned / Optional |

Types:
- **ANIM** — Missing animation (Hero, AnimatedSwitcher, FadeTransition, staggered list, shimmer)
- **PERF** — Performance (const widget, RepaintBoundary, uncached FutureBuilder, ListView shrinkWrap)
- **UX** — Experience (empty state, error state, pull-to-refresh, visual feedback)
- **STATE** — State management (excessive setState, misused ValueNotifier, unnecessary rebuild)
- **VISUAL** — Visual (inconsistent spacing, typography, accessibility, colors)

Priority:
- **Quick Win** = Impact H or M + Effort L or M → implement now
- **Planned** = Impact H + Effort H → add as TODO
- **Optional** = Impact L → add as TODO

**Step 3 — Implement Quick Wins**

For each "Quick Win" item in the table:
1. Announce in 1 line: `→ [TYPE] What you change and why`
2. Apply the modification to the file

Mandatory implementation rules:
- Use `const` wherever possible on static widgets
- Replace `FutureBuilder` with `initState` + `setState` loading if data doesn't change
- Shimmer: use `shimmer` package if already in pubspec.yaml, otherwise use `AnimatedOpacity` or animated gradient `Container`
- Prefer `AnimatedSwitcher`, `AnimatedContainer`, `SlideTransition` over heavy third-party packages
- Project gold color: `0xFFC8A165` — use for accents, highlights, animations
- Dark/light theme: always use `Theme.of(context)` instead of hardcoded colors
- For lists: add `physics: const BouncingScrollPhysics()` and staggered entry effect
- Pull-to-refresh: `RefreshIndicator` with gold color `Color(0xFFC8A165)`

**Step 4 — Add remaining TODOs**

At the end of the main modified file, add this comment block:

```dart
// ═══════════════════════════════════════════════════════
// TODO [flutter-screen-upgrade] — Planned improvements
// ═══════════════════════════════════════════════════════
// [ANIM/Planned]   Precise description of the animation to add
// [PERF/Planned]   Precise description of the optimization
// [UX/Optional]    Description of the optional UX improvement
// ═══════════════════════════════════════════════════════
```

**Step 5 — Final summary**

```
✅ Quick Wins applied: X
📋 TODOs added: Y
📁 Files modified: [list]
⚡ Estimated impact: [short description of overall improvement]
```

If no file is specified in $ARGUMENTS, ask the user which screen they want to improve.
