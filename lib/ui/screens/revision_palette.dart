import 'package:flutter/material.dart';

class RevisionPalette {
  final Color accent;
  final Color bgTop;
  final Color bgBottom;
  final bool isDark;

  const RevisionPalette({
    required this.accent,
    required this.bgTop,
    required this.bgBottom,
    required this.isDark,
  });

  Color get textPrimary   => isDark ? Colors.white : const Color(0xFF1A1A1A);
  Color get textSecondary => isDark ? const Color(0x99FFFFFF) : const Color(0xAA555555);
  Color get textHint      => isDark ? const Color(0x55FFFFFF) : const Color(0x88333333);
  Color get cardBg        => isDark ? const Color(0x12FFFFFF) : const Color(0x0D000000);
  Color get cardBorder    => isDark ? const Color(0x1FFFFFFF) : const Color(0x1A000000);
  Color get iconMuted     => isDark ? const Color(0x88FFFFFF) : const Color(0xFF777777);
  Color get buttonFg      => isDark ? const Color(0xFF0F1F18) : Colors.white;
}

class RevisionThemeScope extends InheritedWidget {
  final RevisionPalette palette;

  const RevisionThemeScope({
    super.key,
    required this.palette,
    required super.child,
  });

  static RevisionPalette of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<RevisionThemeScope>();
    assert(scope != null, 'RevisionThemeScope not found in widget tree');
    return scope!.palette;
  }

  @override
  bool updateShouldNotify(RevisionThemeScope old) => palette != old.palette;
}
