import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

const String kSplashLogoAsset = 'assets/logo.png';
const double kSplashLogoSize = 168;

/// Splash background matching native `splash_background`.
Color splashBackgroundFor(Brightness brightness) =>
    brightness == Brightness.dark ? const Color(0xFF101A27) : Colors.white;

Color splashLogoTintFor(Brightness brightness) =>
    brightness == Brightness.dark ? Colors.white : Colors.black;

Brightness platformSplashBrightness() =>
    WidgetsBinding.instance.platformDispatcher.platformBrightness;

/// Decode the splash logo before [runApp] so the first Flutter frame can paint
/// it synchronously via [RawImage] (no Image.asset async gap).
Future<ui.Image?> loadSplashLogoImage() async {
  try {
    final data = await rootBundle.load(kSplashLogoAsset);
    final codec = await ui.instantiateImageCodec(
      data.buffer.asUint8List(),
      targetWidth: (kSplashLogoSize * 3).round(),
      targetHeight: (kSplashLogoSize * 3).round(),
    );
    final frame = await codec.getNextFrame();
    return frame.image;
  } catch (_) {
    return null;
  }
}

/// Also warm the ImageCache for any later [Image.asset] splash uses.
Future<void> precacheSplashLogoAsset() async {
  final image = const AssetImage(kSplashLogoAsset);
  final stream = image.resolve(
    ImageConfiguration(
      devicePixelRatio:
          WidgetsBinding.instance.platformDispatcher.views.first.devicePixelRatio,
    ),
  );
  final done = Completer<void>();
  late final ImageStreamListener listener;
  listener = ImageStreamListener(
    (ImageInfo info, bool synchronousCall) {
      if (!done.isCompleted) done.complete();
      stream.removeListener(listener);
    },
    onError: (Object error, StackTrace? stackTrace) {
      if (!done.isCompleted) done.complete();
      stream.removeListener(listener);
    },
  );
  stream.addListener(listener);
  await done.future;
}

/// Matches native launch/splash_background colors and the in-app loading mark.
class LaunchSplash extends StatelessWidget {
  const LaunchSplash({super.key, this.logoImage});

  final ui.Image? logoImage;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return LaunchSplashSurface(
      brightness: brightness,
      logoImage: logoImage,
    );
  }
}

/// Used before MaterialApp theme is available (BootApp first frame).
class LaunchSplashRaw extends StatelessWidget {
  const LaunchSplashRaw({super.key, this.logoImage});

  final ui.Image? logoImage;

  @override
  Widget build(BuildContext context) {
    return LaunchSplashSurface(
      brightness: platformSplashBrightness(),
      logoImage: logoImage,
    );
  }
}

class LaunchSplashSurface extends StatelessWidget {
  const LaunchSplashSurface({
    super.key,
    required this.brightness,
    this.logoImage,
  });

  final Brightness brightness;
  final ui.Image? logoImage;

  @override
  Widget build(BuildContext context) {
    final dark = brightness == Brightness.dark;
    final bg = splashBackgroundFor(brightness);
    final tint = splashLogoTintFor(brightness);
    final Widget mark;
    if (logoImage != null) {
      mark = ColorFiltered(
        colorFilter: ColorFilter.mode(tint, BlendMode.srcIn),
        child: RawImage(
          image: logoImage,
          width: kSplashLogoSize,
          height: kSplashLogoSize,
          fit: BoxFit.contain,
        ),
      );
    } else {
      mark = Image.asset(
        kSplashLogoAsset,
        width: kSplashLogoSize,
        height: kSplashLogoSize,
        color: tint,
        colorBlendMode: BlendMode.srcIn,
        gaplessPlayback: true,
        filterQuality: FilterQuality.medium,
      );
    }
    return ColoredBox(
      color: bg,
      child: Center(child: mark),
    );
  }
}
