---
description: Extract a Flutter widget block into a proper StatelessWidget or StatefulWidget
argument-hint: <file:start_line-end_line> or <file> for full analysis
---

You are a Flutter refactoring expert. The user wants to extract a widget from: $ARGUMENTS

**Step 1 — Read**

If $ARGUMENTS contains a line range (e.g. `lib/ui/home_screen_widgets.dart:150-280`):
→ Read only those lines + 10 lines of context before/after

If $ARGUMENTS is just a file:
→ Read the entire file and identify candidate blocks for extraction
→ Display a numbered list of candidates with approximate size and ask which one to extract

**Step 2 — Analyze the block**

For the selected block, determine:
1. **Type**: StatelessWidget or StatefulWidget?
   - StatefulWidget if: setState, initState, dispose, AnimationController, Timer, streams
   - StatelessWidget otherwise
2. **Required parameters**: list all parent scope variables used in the block
3. **Suggested name**: propose a descriptive PascalCase name (e.g. `_PrayerTimesHeader`, `_ReciterCard`)
4. **Target file**: same file or separate `*_widgets.dart` file?

Display the analysis:
```
Type      : StatelessWidget / StatefulWidget
Name      : _ProposedName
Parameters: variable1 (Type), variable2 (Type), ...
File      : lib/ui/file_widgets.dart (new) / existing file
```

**Step 3 — Extract**

1. Create the new widget with:
   - Constructor with all parameters as `final`
   - `const` annotation if StatelessWidget without callbacks
   - `build` method with the extracted code
   - Correct `BuildContext` handling (no context after await)

2. In the source file, replace the original block with:
   ```dart
   WidgetName(
     param1: value1,
     param2: value2,
   )
   ```

3. If the widget goes in a separate file, add the necessary `part of` / `import`

**Mandatory rules:**
- Add `const` to the constructor if possible
- Use `_` prefix if the widget is private to the file (single use)
- Keep callbacks typed as `VoidCallback` or `Function(Type)`
- Do not change the logic, only extract
- Project gold color if needed: `const Color(0xFFC8A165)`

**Step 4 — Summary**

```
📦 Widget extracted: WidgetName (StatelessWidget/StatefulWidget)
📍 Source: file:start_line-end_line
📁 Destination: file:line
🔧 Parameters: X parameters
```
