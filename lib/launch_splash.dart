import 'package:flutter/material.dart';

/// Matches native launch/splash_background colors and the in-app loading mark.
class LaunchSplash extends StatelessWidget {
  const LaunchSplash({super.key});

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final dark = brightness == Brightness.dark;
    return ColoredBox(
      color: dark ? const Color(0xFF101A27) : Colors.white,
      child: Center(
        child: Image.asset(
          'assets/logo.png',
          width: 168,
          height: 168,
          color: dark ? Colors.white : Colors.black,
          colorBlendMode: BlendMode.srcIn,
        ),
      ),
    );
  }
}

/// Used before MaterialApp theme is available (BootApp first frame).
class LaunchSplashRaw extends StatelessWidget {
  const LaunchSplashRaw({super.key});

  @override
  Widget build(BuildContext context) {
    final dark = WidgetsBinding.instance.platformDispatcher.platformBrightness ==
        Brightness.dark;
    return ColoredBox(
      color: dark ? const Color(0xFF101A27) : Colors.white,
      child: Center(
        child: Image.asset(
          'assets/logo.png',
          width: 168,
          height: 168,
          color: dark ? Colors.white : Colors.black,
          colorBlendMode: BlendMode.srcIn,
        ),
      ),
    );
  }
}
