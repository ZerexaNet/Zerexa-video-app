/// Four built-in visual themes for Zerexa Video.
///
///  - [AppThemeMode.material] : Google Material You - rounded surfaces,
///    soft shadows, warm neutrals.
///  - [AppThemeMode.metro]    : Windows 8 Metro / Modern UI - flat blocks,
///    hard edges, vibrant solid colour, uppercase labels.
///  - [AppThemeMode.clean]    : Zerexa Clean - pure white surface, navy ink,
///    registrar-blue accent (default).
///  - [AppThemeMode.midnight] : high-contrast dark variant.
library;

import 'package:flutter/material.dart';

import '../stores/app_stores.dart';

/// Extra design tokens carried alongside [ThemeData] via theme extensions.
@immutable
class ZxSpec extends ThemeExtension<ZxSpec> {
  const ZxSpec({
    required this.cardRadius,
    required this.controlRadius,
    required this.tileAccents,
    required this.uppercaseNav,
    required this.boldTitles,
    required this.dividerWeight,
  });

  /// Radius applied to cards and sheets.
  final double cardRadius;

  /// Radius applied to buttons, chips and inputs.
  final double controlRadius;

  /// Accent palette used by tiles/badges (richest in Metro theme).
  final List<Color> tileAccents;

  /// Whether nav labels render in uppercase (Metro).
  final bool uppercaseNav;

  /// Whether titles render extra bold (Metro).
  final bool boldTitles;

  final double dividerWeight;

  Color accentFor(int index) =>
      tileAccents.isEmpty ? const Color(0xFF0A6CFF) : tileAccents[index % tileAccents.length];

  @override
  ZxSpec copyWith({
    double? cardRadius,
    double? controlRadius,
    List<Color>? tileAccents,
    bool? uppercaseNav,
    bool? boldTitles,
    double? dividerWeight,
  }) =>
      ZxSpec(
        cardRadius: cardRadius ?? this.cardRadius,
        controlRadius: controlRadius ?? this.controlRadius,
        tileAccents: tileAccents ?? this.tileAccents,
        uppercaseNav: uppercaseNav ?? this.uppercaseNav,
        boldTitles: boldTitles ?? this.boldTitles,
        dividerWeight: dividerWeight ?? this.dividerWeight,
      );

  @override
  ZxSpec lerp(ZxSpec? other, double t) {
    if (other == null) return this;
    return ZxSpec(
      cardRadius: lerpDouble(cardRadius, other.cardRadius, t),
      controlRadius: lerpDouble(controlRadius, other.controlRadius, t),
      tileAccents: tileAccents,
      uppercaseNav: uppercaseNav,
      boldTitles: boldTitles,
      dividerWeight: lerpDouble(dividerWeight, other.dividerWeight, t),
    );
  }
}

double lerpDouble(double a, double b, double t) => a + (b - a) * t;

/// Returns the [ZxSpec] attached to the active theme.
extension ZxSpecX on BuildContext {
  ZxSpec get zx =>
      Theme.of(this).extension<ZxSpec>() ??
      const ZxSpec(
        cardRadius: 8,
        controlRadius: 6,
        tileAccents: [Color(0xFF0A6CFF)],
        uppercaseNav: false,
        boldTitles: false,
        dividerWeight: 1,
      );
}

const metroAccents = <Color>[
  Color(0xFF00AFF0), // Win8 blue
  Color(0xFFE61400), // Metro red
  Color(0xFF00A300), // Metro green
  Color(0xFFFFB900), // Metro amber
  Color(0xFF8C0095), // Metro purple
  Color(0xFF00ABA9), // Metro teal
];

ThemeData buildTheme(AppThemeMode mode) {
  switch (mode) {
    case AppThemeMode.material:
      return _material();
    case AppThemeMode.metro:
      return _metro();
    case AppThemeMode.midnight:
      return _midnight();
    case AppThemeMode.clean:
      return _clean();
  }
}

// ---------------- Material You ----------------

ThemeData _material() {
  final scheme = ColorScheme.fromSeed(
    seedColor: const Color(0xFF4285F4),
    brightness: Brightness.light,
  );
  const spec = ZxSpec(
    cardRadius: 16,
    controlRadius: 12,
    tileAccents: [Color(0xFF4285F4), Color(0xFF34A853), Color(0xFFFBBC05), Color(0xFFEA4335)],
    uppercaseNav: false,
    boldTitles: false,
    dividerWeight: 0,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: const Color(0xFFFAFAF7),
    extensions: [spec],
    appBarTheme: AppBarTheme(
      backgroundColor: const Color(0xFFFAFAF7),
      foregroundColor: scheme.onSurface,
      elevation: 0,
      scrolledUnderElevation: 1,
      centerTitle: false,
      titleTextStyle: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: scheme.onSurface,
      ),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: Colors.white,
      surfaceTintColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: scheme.outlineVariant.withValues(alpha: .4)),
      ),
      margin: EdgeInsets.zero,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Colors.white,
      indicatorColor: scheme.primaryContainer,
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      elevation: 2,
    ),
    navigationRailTheme: NavigationRailThemeData(
      backgroundColor: const Color(0xFFFAFAF7),
      indicatorColor: scheme.primaryContainer,
      selectedIconTheme: IconThemeData(color: scheme.onPrimaryContainer),
      selectedLabelTextStyle: TextStyle(
        color: scheme.onPrimaryContainer,
        fontWeight: FontWeight.w600,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: scheme.outlineVariant),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: scheme.outlineVariant),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: scheme.primary, width: 2),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    chipTheme: ChipThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ),
    dividerTheme: DividerThemeData(
      color: scheme.outlineVariant.withValues(alpha: .5),
      thickness: 1,
      space: 1,
    ),
  );
}

// ---------------- Win8 Metro ----------------

ThemeData _metro() {
  const metroBlue = Color(0xFF00AFF0);
  const spec = ZxSpec(
    cardRadius: 0,
    controlRadius: 0,
    tileAccents: metroAccents,
    uppercaseNav: true,
    boldTitles: true,
    dividerWeight: 0,
  );
  final scheme = const ColorScheme(
    brightness: Brightness.light,
    primary: metroBlue,
    onPrimary: Colors.white,
    secondary: Color(0xFF00ABA9),
    onSecondary: Colors.white,
    error: Color(0xFFE61400),
    onError: Colors.white,
    surface: Colors.white,
    onSurface: Color(0xFF1A1A1A),
    surfaceContainerHighest: Color(0xFFF2F2F2),
    onSurfaceVariant: Color(0xFF4A4A4A),
    outline: Color(0xFFBFBFBF),
    outlineVariant: Color(0xFFE2E2E2),
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: Colors.white,
    extensions: [spec],
    appBarTheme: const AppBarTheme(
      backgroundColor: metroBlue,
      foregroundColor: Colors.white,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: Colors.white,
        letterSpacing: .5,
      ),
      iconTheme: IconThemeData(color: Colors.white),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: Colors.white,
      surfaceTintColor: Colors.white,
      shape: const RoundedRectangleBorder(side: BorderSide.none),
      margin: EdgeInsets.zero,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: const Color(0xFF111111),
      indicatorColor: metroBlue,
      labelTextStyle: WidgetStatePropertyAll(
        const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: .8,
        ),
      ),
      iconTheme: const WidgetStatePropertyAll(IconThemeData(color: Colors.white)),
      height: 62,
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      elevation: 0,
    ),
    navigationRailTheme: NavigationRailThemeData(
      backgroundColor: const Color(0xFF111111),
      indicatorColor: metroBlue,
      selectedIconTheme: const IconThemeData(color: Colors.white),
      unselectedIconTheme: const IconThemeData(color: Color(0xFF9E9E9E)),
      selectedLabelTextStyle: const TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.w700,
        letterSpacing: .8,
      ),
      unselectedLabelTextStyle: const TextStyle(color: Color(0xFF9E9E9E)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.zero,
        borderSide: const BorderSide(color: Color(0xFFBFBFBF)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.zero,
        borderSide: const BorderSide(color: Color(0xFFBFBFBF)),
      ),
      focusedBorder: const OutlineInputBorder(
        borderRadius: BorderRadius.zero,
        borderSide: BorderSide(color: metroBlue, width: 2),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: metroBlue,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        textStyle: const TextStyle(fontWeight: FontWeight.w700, letterSpacing: .5),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        side: const BorderSide(color: Color(0xFFBFBFBF)),
      ),
    ),
    chipTheme: const ChipThemeData(
      shape: RoundedRectangleBorder(side: BorderSide.none),
      labelStyle: TextStyle(fontWeight: FontWeight.w600),
    ),
    tabBarTheme: const TabBarThemeData(
      labelColor: metroBlue,
      unselectedLabelColor: Color(0xFF4A4A4A),
      labelStyle: TextStyle(fontWeight: FontWeight.w700),
      indicatorColor: metroBlue,
      dividerColor: Color(0xFFE2E2E2),
    ),
    dividerTheme: const DividerThemeData(color: Color(0xFFE2E2E2), thickness: 1, space: 1),
    listTileTheme: const ListTileThemeData(iconColor: metroBlue),
    progressIndicatorTheme: const ProgressIndicatorThemeData(color: metroBlue),
    snackBarTheme: const SnackBarThemeData(
      backgroundColor: Color(0xFF111111),
      contentTextStyle: TextStyle(color: Colors.white),
      behavior: SnackBarBehavior.floating,
    ),
  );
}

// ---------------- Zerexa Clean ----------------

ThemeData _clean() {
  const ink = Color(0xFF16283C);
  const blue = Color(0xFF0A6CFF);
  const spec = ZxSpec(
    cardRadius: 10,
    controlRadius: 8,
    tileAccents: [blue, Color(0xFF16283C), Color(0xFF5B7A99), Color(0xFF2E9E6B)],
    uppercaseNav: false,
    boldTitles: false,
    dividerWeight: 1,
  );
  final scheme = const ColorScheme(
    brightness: Brightness.light,
    primary: blue,
    onPrimary: Colors.white,
    secondary: Color(0xFF16283C),
    onSecondary: Colors.white,
    error: Color(0xFFD63031),
    onError: Colors.white,
    surface: Colors.white,
    onSurface: ink,
    surfaceContainerHighest: Color(0xFFF6F8FB),
    onSurfaceVariant: Color(0xFF5B7A99),
    outline: Color(0xFFC9D4E0),
    outlineVariant: Color(0xFFEBF0F6),
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: Colors.white,
    extensions: [spec],
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.white,
      foregroundColor: ink,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        fontSize: 19,
        fontWeight: FontWeight.w600,
        color: ink,
        letterSpacing: -.2,
      ),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: Colors.white,
      surfaceTintColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: const BorderSide(color: Color(0xFFEBF0F6)),
      ),
      margin: EdgeInsets.zero,
    ),
    navigationBarTheme: const NavigationBarThemeData(
      backgroundColor: Colors.white,
      indicatorColor: Color(0xFFEAF2FF),
      surfaceTintColor: Colors.white,
      elevation: 0,
      height: 64,
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
    ),
    navigationRailTheme: const NavigationRailThemeData(
      backgroundColor: Colors.white,
      indicatorColor: Color(0xFFEAF2FF),
      selectedIconTheme: IconThemeData(color: blue),
      selectedLabelTextStyle: TextStyle(color: blue, fontWeight: FontWeight.w600),
      unselectedLabelTextStyle: TextStyle(color: Color(0xFF5B7A99)),
      unselectedIconTheme: IconThemeData(color: Color(0xFF5B7A99)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Color(0xFFF6F8FB),
      hintStyle: const TextStyle(color: Color(0xFF8FA6BC)),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: blue, width: 1.5),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: blue,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: const Color(0xFFF6F8FB),
      side: BorderSide.none,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      labelStyle: const TextStyle(color: Color(0xFF5B7A99)),
    ),
    tabBarTheme: const TabBarThemeData(
      labelColor: blue,
      unselectedLabelColor: Color(0xFF5B7A99),
      labelStyle: TextStyle(fontWeight: FontWeight.w600),
      indicatorColor: blue,
      dividerColor: Color(0xFFEBF0F6),
    ),
    dividerTheme: const DividerThemeData(color: Color(0xFFEBF0F6), thickness: 1, space: 1),
    progressIndicatorTheme: const ProgressIndicatorThemeData(color: blue),
  );
}

// ---------------- Midnight ----------------

ThemeData _midnight() {
  const bg = Color(0xFF0B0F1A);
  const panel = Color(0xFF121828);
  const blue = Color(0xFF5B9DFF);
  const spec = ZxSpec(
    cardRadius: 12,
    controlRadius: 10,
    tileAccents: [blue, Color(0xFF7C6BFF), Color(0xFF2E9E6B), Color(0xFFE8A13C)],
    uppercaseNav: false,
    boldTitles: false,
    dividerWeight: 1,
  );
  final scheme = const ColorScheme(
    brightness: Brightness.dark,
    primary: blue,
    onPrimary: Color(0xFF0B0F1A),
    secondary: Color(0xFF7C6BFF),
    onSecondary: Colors.white,
    error: Color(0xFFFF5D5D),
    onError: Color(0xFF0B0F1A),
    surface: panel,
    onSurface: Color(0xFFE7ECF5),
    surfaceContainerHighest: Color(0xFF1A2236),
    onSurfaceVariant: Color(0xFF93A1B8),
    outline: Color(0xFF3A465E),
    outlineVariant: Color(0xFF232D44),
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: bg,
    extensions: [spec],
    appBarTheme: const AppBarTheme(
      backgroundColor: bg,
      foregroundColor: Color(0xFFE7ECF5),
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        fontSize: 19,
        fontWeight: FontWeight.w600,
        color: Color(0xFFE7ECF5),
      ),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: panel,
      surfaceTintColor: panel,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFF232D44)),
      ),
      margin: EdgeInsets.zero,
    ),
    navigationBarTheme: const NavigationBarThemeData(
      backgroundColor: Color(0xFF0E1422),
      indicatorColor: Color(0xFF1D2A47),
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      height: 64,
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
    ),
    navigationRailTheme: const NavigationRailThemeData(
      backgroundColor: Color(0xFF0E1422),
      indicatorColor: Color(0xFF1D2A47),
      selectedIconTheme: IconThemeData(color: blue),
      selectedLabelTextStyle: TextStyle(color: blue, fontWeight: FontWeight.w600),
      unselectedLabelTextStyle: TextStyle(color: Color(0xFF93A1B8)),
      unselectedIconTheme: IconThemeData(color: Color(0xFF93A1B8)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Color(0xFF161E31),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: blue, width: 1.5),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: blue,
        foregroundColor: const Color(0xFF0B0F1A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: const Color(0xFF1A2236),
      side: BorderSide.none,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      labelStyle: const TextStyle(color: Color(0xFF93A1B8)),
    ),
    tabBarTheme: const TabBarThemeData(
      labelColor: blue,
      unselectedLabelColor: Color(0xFF93A1B8),
      labelStyle: TextStyle(fontWeight: FontWeight.w600),
      indicatorColor: blue,
      dividerColor: Color(0xFF232D44),
    ),
    dividerTheme: const DividerThemeData(color: Color(0xFF232D44), thickness: 1, space: 1),
    progressIndicatorTheme: const ProgressIndicatorThemeData(color: blue),
  );
}
