import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Copied from nio-podcast-web/src/App.css :root tokens.
class NioColors {
  static const lightSurface = Color(0xFFFFFFFF);
  static const lightSurfaceSoft = Color(0xFFF5F8F9);
  static const lightAqua = Color(0xFFE7F7F7);
  static const lightTeal = Color(0xFF00B9B5);
  static const lightTealDark = Color(0xFF006F6D);
  static const lightInk = Color(0xFF08162E);
  static const lightMuted = Color(0xFF5F6B7B);
  static const lightMutedStrong = Color(0xFF4B586B);
  static const lightLine = Color(0xFFE8EDF0);

  static const darkSurface = Color(0xFF101A27);
  static const darkSurfaceSoft = Color(0xFF182433);
  static const darkAqua = Color(0xFF133239);
  static const darkTeal = Color(0xFF2BD0C6);
  static const darkTealDark = Color(0xFF8AF5EB);
  static const darkInk = Color(0xFFF0F6FA);
  static const darkMuted = Color(0xFFB8C4CE);
  static const darkMutedStrong = Color(0xFFD3DDE5);
  static const darkLine = Color(0xFF2B3949);

  static const logoTeal = Color(0xFF00BEBE);
  static const accentInk = Color(0xFF08162E);
}

class NioPalette {
  const NioPalette(this.brightness);
  final Brightness brightness;
  bool get dark => brightness == Brightness.dark;
  Color get surface => dark ? NioColors.darkSurface : NioColors.lightSurface;
  Color get surfaceSoft => dark ? NioColors.darkSurfaceSoft : NioColors.lightSurfaceSoft;
  Color get aqua => dark ? NioColors.darkAqua : NioColors.lightAqua;
  Color get teal => dark ? NioColors.darkTeal : NioColors.lightTeal;
  Color get tealDark => dark ? NioColors.darkTealDark : NioColors.lightTealDark;
  Color get ink => dark ? NioColors.darkInk : NioColors.lightInk;
  Color get muted => dark ? NioColors.darkMuted : NioColors.lightMuted;
  Color get mutedStrong => dark ? NioColors.darkMutedStrong : NioColors.lightMutedStrong;
  Color get line => dark ? NioColors.darkLine : NioColors.lightLine;
  Color get danger => dark ? const Color(0xFFFF9292) : const Color(0xFFB53939);
}

ThemeData nioTheme(Brightness brightness) {
  final palette = NioPalette(brightness);
  final overlay = SystemUiOverlayStyle(
    statusBarColor: palette.aqua,
    statusBarIconBrightness: palette.dark ? Brightness.light : Brightness.dark,
    systemNavigationBarColor: palette.surface,
    systemNavigationBarIconBrightness: palette.dark ? Brightness.light : Brightness.dark,
  );
  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    scaffoldBackgroundColor: palette.surface,
    colorScheme: ColorScheme(
      brightness: brightness,
      primary: palette.teal,
      onPrimary: palette.dark ? NioColors.accentInk : Colors.white,
      secondary: palette.aqua,
      onSecondary: palette.ink,
      surface: palette.surface,
      onSurface: palette.ink,
      error: palette.danger,
      onError: palette.surface,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: palette.aqua,
      foregroundColor: palette.ink,
      elevation: 0,
      scrolledUnderElevation: 0,
      systemOverlayStyle: overlay,
    ),
    textTheme: TextTheme(
      bodyMedium: TextStyle(color: palette.ink, height: 1.45),
      bodySmall: TextStyle(color: palette.muted),
    ),
  );
}
