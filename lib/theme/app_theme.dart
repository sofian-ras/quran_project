import 'package:flutter/material.dart';

class AppColors {
  // Palette principale - Vert foncé moderne avec dégradés
  static const Color primary = Color(0xFF1E3A2F); // Vert foncé principal
  static const Color primaryLight = Color(0xFF2D5A45); // Vert foncé clair pour dégradés
  static const Color primaryDark = Color(0xFF0F1F18); // Vert très foncé
  static const Color primaryAccent = Color(0xFF3A6B54); // Vert moyen pour highlights
  
  // Couleurs secondaires
  static const Color accent = Color(0xFFD4AF77); // Or doux
  static const Color accentLight = Color(0xFFE5C8A0);
  
  // Arrière-plans
  static const Color background = Color(0xFFF5F7F6); // Gris très clair verdâtre
  static const Color cardBackground = Colors.white;
  static const Color darkBackground = Color(0xFF0F1F18);
  
  // Textes
  static const Color textPrimary = Color(0xFF2C3E50);
  static const Color textSecondary = Color(0xFF7F8C8D);
  static const Color textLight = Color(0xFFBDC3C7);
  static const Color textOnPrimary = Colors.white;
  
  // États
  static const Color success = Color(0xFF27AE60);
  static const Color warning = Color(0xFFF39C12);
  static const Color error = Color(0xFFE74C3C);
  static const Color info = Color(0xFF3498DB);
  
  // Surfaces et bordures
  static const Color surface = Colors.white;
  static const Color border = Color(0xFFECF0F1);
  static const Color divider = Color(0xFFE8E8E8);
  
  // Ombres
  static Color shadow = Colors.black.withOpacity(0.08);
  static Color shadowMedium = Colors.black.withOpacity(0.12);
  static Color shadowStrong = Colors.black.withOpacity(0.16);
  
  // Dégradés prédéfinis
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primary, primaryLight],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  static const LinearGradient darkGradient = LinearGradient(
    colors: [primaryDark, primary],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );
  
  static const LinearGradient subtleGradient = LinearGradient(
    colors: [primaryLight, primaryAccent],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  // Variantes de dégradés (pour tester)
  static const LinearGradient variant1 = LinearGradient(
    colors: [Color(0xFF0f0f0f), Color(0xFF1a1a2e), Color(0xFF16213e)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  static const LinearGradient variant2 = LinearGradient(
    colors: [Color(0xFF0F1F18), Color(0xFF1E3A2F), Color(0xFF2D5A45)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );
  
  static const RadialGradient radialVariant = RadialGradient(
    colors: [Color(0xFF2D5A45), Color(0xFF1E3A2F), Color(0xFF0F1F18)],
    center: Alignment.topLeft,
    radius: 1.5,
  );
}

class AppTheme {
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      
      // Couleurs principales
      primaryColor: AppColors.primary,
      scaffoldBackgroundColor: AppColors.background,
      
      colorScheme: ColorScheme.light(
        primary: AppColors.primary,
        primaryContainer: AppColors.primaryLight,
        secondary: AppColors.accent,
        secondaryContainer: AppColors.accentLight,
        surface: AppColors.surface,
        background: AppColors.background,
        error: AppColors.error,
        onPrimary: AppColors.textOnPrimary,
        onSecondary: AppColors.textOnPrimary,
        onSurface: AppColors.textPrimary,
        onBackground: AppColors.textPrimary,
        onError: Colors.white,
      ),
      
      // Typographie moderne
      textTheme: TextTheme(
        displayLarge: TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.bold,
          color: AppColors.textPrimary,
          letterSpacing: -0.5,
        ),
        displayMedium: TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.bold,
          color: AppColors.textPrimary,
          letterSpacing: -0.5,
        ),
        displaySmall: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: AppColors.textPrimary,
          letterSpacing: -0.3,
        ),
        headlineMedium: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
          letterSpacing: -0.2,
        ),
        titleLarge: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
        titleMedium: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
        titleSmall: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
        bodyLarge: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.normal,
          color: AppColors.textPrimary,
          height: 1.5,
        ),
        bodyMedium: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.normal,
          color: AppColors.textPrimary,
          height: 1.5,
        ),
        bodySmall: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.normal,
          color: AppColors.textSecondary,
          height: 1.4,
        ),
        labelLarge: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
          letterSpacing: 0.1,
        ),
        labelMedium: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: AppColors.textSecondary,
          letterSpacing: 0.1,
        ),
        labelSmall: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: AppColors.textLight,
          letterSpacing: 0.1,
        ),
      ),
      
      // AppBar moderne
      appBarTheme: AppBarTheme(
        elevation: 0,
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        centerTitle: true,
        titleTextStyle: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: Colors.white,
          letterSpacing: -0.2,
        ),
      ),
      
      // Cards élégantes
      cardTheme: CardThemeData(
        elevation: 0,
        color: AppColors.cardBackground,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
      
      // Boutons modernes
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.2,
          ),
        ),
      ),
      
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary,
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          textStyle: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          side: BorderSide(color: AppColors.primary, width: 1.5),
          padding: EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      
      // Input decoration
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.error),
        ),
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
      
      // Chip moderne
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.primaryLight.withOpacity(0.1),
        selectedColor: AppColors.primary,
        labelStyle: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: AppColors.primary,
        ),
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
      
      // Divider
      dividerTheme: DividerThemeData(
        color: AppColors.divider,
        thickness: 1,
        space: 1,
      ),
      
      // BottomSheet
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: AppColors.cardBackground,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        elevation: 8,
      ),
      
      // Dialog
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.cardBackground,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        elevation: 8,
      ),
      
      // Icon
      iconTheme: IconThemeData(
        color: AppColors.textSecondary,
        size: 24,
      ),
      
      // Progress Indicator
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: AppColors.primary,
        linearTrackColor: AppColors.primaryLight.withOpacity(0.2),
        circularTrackColor: AppColors.primaryLight.withOpacity(0.2),
      ),
    );
  }
  // ── [unused — reader uses internal _readerTheme] ─────────────────────────
  static ThemeData get sepiaTheme {
    const Color _bg        = Color(0xFFF5F0E6);
    const Color _card      = Color(0xFFEDE6D9);
    const Color _primary   = Color(0xFF8B6C35);
    const Color _txtP      = Color(0xFF4A3F30);
    const Color _txtS      = Color(0xFF6B5A45);
    const Color _border    = Color(0xFFC8A97E);
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      primaryColor: _primary,
      scaffoldBackgroundColor: _bg,
      colorScheme: ColorScheme.light(
        primary: _primary,
        primaryContainer: const Color(0xFFD4B896),
        secondary: const Color(0xFFD4AF77),
        secondaryContainer: const Color(0xFFE8D5B3),
        surface: _card,
        error: AppColors.error,
        onPrimary: Colors.white,
        onSecondary: _txtP,
        onSurface: _txtP,
        onError: Colors.white,
      ),
      textTheme: TextTheme(
        displayLarge: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: _txtP, letterSpacing: -0.5),
        displayMedium: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: _txtP, letterSpacing: -0.5),
        displaySmall: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: _txtP, letterSpacing: -0.3),
        headlineMedium: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: _txtP, letterSpacing: -0.2),
        titleLarge: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: _txtP),
        titleMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: _txtP),
        titleSmall: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: _txtP),
        bodyLarge: TextStyle(fontSize: 16, color: _txtP, height: 1.6),
        bodyMedium: TextStyle(fontSize: 14, color: _txtP, height: 1.6),
        bodySmall: TextStyle(fontSize: 12, color: _txtS, height: 1.4),
        labelLarge: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: _txtP, letterSpacing: 0.1),
        labelMedium: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _txtS, letterSpacing: 0.1),
        labelSmall: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: _txtS, letterSpacing: 0.1),
      ),
      appBarTheme: AppBarTheme(
        elevation: 0,
        backgroundColor: _primary,
        foregroundColor: Colors.white,
        centerTitle: true,
        titleTextStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.white, letterSpacing: -0.2),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: _card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: _border.withValues(alpha: 0.5), width: 1),
        ),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
      dividerTheme: DividerThemeData(color: _border.withValues(alpha: 0.5), thickness: 1, space: 1),
      iconTheme: const IconThemeData(color: _txtS, size: 24),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: _primary,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: _card,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: _border)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: _border)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: _primary, width: 2)),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: _card,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: _card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: _primary,
        linearTrackColor: _border.withValues(alpha: 0.3),
        circularTrackColor: _border.withValues(alpha: 0.3),
      ),
    );
  }

  // ── Thème Nuit / OLED (ultra-sombre) ─────────────────────────────────────
  static ThemeData get nightTheme {
    const Color _bg        = Color(0xFF050810);
    const Color _surface   = Color(0xFF0D1117);
    const Color _card      = Color(0xFF111827);
    const Color _primary   = Color(0xFF4D9EFF);
    const Color _txtP      = Color(0xFFE8EAF0);
    const Color _txtS      = Color(0xFF8892A4);
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      primaryColor: _primary,
      scaffoldBackgroundColor: _bg,
      colorScheme: ColorScheme.dark(
        primary: _primary,
        primaryContainer: const Color(0xFF1A3A6B),
        secondary: const Color(0xFF7B9FD4),
        secondaryContainer: const Color(0xFF1C2B45),
        surface: _card,
        error: AppColors.error,
        onPrimary: Colors.white,
        onSecondary: _txtP,
        onSurface: _txtP,
        onError: Colors.white,
      ),
      textTheme: TextTheme(
        displayLarge: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: _txtP, letterSpacing: -0.5),
        displayMedium: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: _txtP, letterSpacing: -0.5),
        displaySmall: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: _txtP, letterSpacing: -0.3),
        headlineMedium: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: _txtP, letterSpacing: -0.2),
        titleLarge: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: _txtP),
        titleMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: _txtP),
        titleSmall: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: _txtP),
        bodyLarge: TextStyle(fontSize: 16, color: _txtP, height: 1.5),
        bodyMedium: TextStyle(fontSize: 14, color: _txtP, height: 1.5),
        bodySmall: TextStyle(fontSize: 12, color: _txtS, height: 1.4),
        labelLarge: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: _txtP, letterSpacing: 0.1),
        labelMedium: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _txtS, letterSpacing: 0.1),
        labelSmall: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: _txtS, letterSpacing: 0.1),
      ),
      appBarTheme: AppBarTheme(
        elevation: 0,
        backgroundColor: _surface,
        foregroundColor: _txtP,
        centerTitle: true,
        titleTextStyle: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: _txtP, letterSpacing: -0.2),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: _card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Colors.white.withValues(alpha: 0.06), width: 1),
        ),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
      dividerTheme: DividerThemeData(color: Colors.white.withValues(alpha: 0.08), thickness: 1, space: 1),
      iconTheme: const IconThemeData(color: _txtS, size: 24),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: _primary,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: _card,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.12))),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.12))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: _primary, width: 2)),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: _card,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: _card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: _primary,
        linearTrackColor: _primary.withValues(alpha: 0.2),
        circularTrackColor: _primary.withValues(alpha: 0.2),
      ),
    );
  }

  static ThemeData get darkTheme {
    final base = AppTheme.lightTheme;
    return base.copyWith(
      brightness: Brightness.dark,
      primaryColor: AppColors.primary,
      scaffoldBackgroundColor: AppColors.darkBackground,
      colorScheme: ColorScheme.dark(
        primary: AppColors.primaryAccent,
        primaryContainer: AppColors.primary,
        secondary: AppColors.accent,
        secondaryContainer: AppColors.accentLight,
        surface: AppColors.primaryDark,
        background: AppColors.darkBackground,
        error: AppColors.error,
        onPrimary: AppColors.textOnPrimary,
        onSecondary: AppColors.primaryDark,
        onSurface: Colors.white,
        onBackground: Colors.white,
        onError: Colors.white,
      ),
      textTheme: base.textTheme.apply(
        bodyColor: Colors.white,
        displayColor: Colors.white,
      ),
    );
  }

  
  // Gradients personnalisés
  static LinearGradient get primaryGradient => LinearGradient(
    colors: [AppColors.primary, AppColors.primaryLight],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  static LinearGradient get accentGradient => LinearGradient(
    colors: [AppColors.accent, AppColors.accentLight],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  // Ombres élégantes
  static List<BoxShadow> get softShadow => [
    BoxShadow(
      color: AppColors.shadow,
      blurRadius: 10,
      offset: Offset(0, 2),
    ),
  ];
  
  static List<BoxShadow> get mediumShadow => [
    BoxShadow(
      color: AppColors.shadowMedium,
      blurRadius: 16,
      offset: Offset(0, 4),
    ),
  ];
  
  static List<BoxShadow> get strongShadow => [
    BoxShadow(
      color: AppColors.shadowStrong,
      blurRadius: 24,
      offset: Offset(0, 8),
    ),
  ];
}

// Extensions utiles
extension ThemeExtension on BuildContext {
  ThemeData get theme => Theme.of(this);
  TextTheme get textTheme => Theme.of(this).textTheme;
  ColorScheme get colors => Theme.of(this).colorScheme;
}
