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
  static const lightLine = Color(0xFFE8EDF0);

  static const darkSurface = Color(0xFF101A27);
  static const darkSurfaceSoft = Color(0xFF182433);
  static const darkAqua = Color(0xFF133239);
  static const darkTeal = Color(0xFF2BD0C6);
  static const darkTealDark = Color(0xFF8AF5EB);
  static const darkInk = Color(0xFFF0F6FA);
  static const darkMuted = Color(0xFFB8C4CE);
  static const darkLine = Color(0xFF2B3949);

  static const logoTeal = Color(0xFF00BEBE);
}

ThemeData nioTheme(Brightness brightness) {
  final dark = brightness == Brightness.dark;
  final surface = dark ? NioColors.darkSurface : NioColors.lightSurface;
  final aqua = dark ? NioColors.darkAqua : NioColors.lightAqua;
  final teal = dark ? NioColors.darkTeal : NioColors.lightTeal;
  final ink = dark ? NioColors.darkInk : NioColors.lightInk;
  final muted = dark ? NioColors.darkMuted : NioColors.lightMuted;
  final overlay = SystemUiOverlayStyle(
    statusBarColor: aqua,
    statusBarIconBrightness: dark ? Brightness.light : Brightness.dark,
    systemNavigationBarColor: surface,
    systemNavigationBarIconBrightness: dark ? Brightness.light : Brightness.dark,
  );
  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    scaffoldBackgroundColor: surface,
    colorScheme: ColorScheme(
      brightness: brightness,
      primary: teal,
      onPrimary: dark ? NioColors.lightInk : Colors.white,
      secondary: aqua,
      onSecondary: ink,
      surface: surface,
      onSurface: ink,
      error: dark ? const Color(0xFFFF9292) : const Color(0xFFB53939),
      onError: surface,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: aqua,
      foregroundColor: ink,
      elevation: 0,
      scrolledUnderElevation: 0,
      systemOverlayStyle: overlay,
    ),
    textTheme: TextTheme(
      bodyMedium: TextStyle(color: ink),
      bodySmall: TextStyle(color: muted),
    ),
  );
}
