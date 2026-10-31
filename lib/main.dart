import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:just_audio_background/just_audio_background.dart';

import 'api.dart';
import 'custom_albums.dart';
import 'launch_splash.dart';
import 'player.dart';
import 'screens.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Decode logo before the first frame so BootApp never paints a blank plate.
  final logo = await loadSplashLogoImage();
  // Best-effort ImageCache warm for later Image.asset splash uses.
  await precacheSplashLogoAsset();
  runApp(BootApp(splashLogo: logo));
}

class BootApp extends StatefulWidget {
  const BootApp({super.key, this.splashLogo});

  final ui.Image? splashLogo;

  @override
  State<BootApp> createState() => _BootAppState();
}

class _BootAppState extends State<BootApp> {
  bool _ready = false;
  late final NioApi _api;
  late final RadioPlayer _player;

  @override
  void initState() {
    super.initState();
    _prepare();
  }

  Future<void> _prepare() async {
    try {
      await JustAudioBackground.init(
        androidNotificationChannelId: 'top.k4le.nio_radio.playback',
        androidNotificationChannelName: 'NIO Radio 播放',
        androidNotificationIcon: 'drawable/ic_stat_nio',
        androidNotificationOngoing: true,
        androidStopForegroundOnPause: true,
      );
    } catch (_) {
      // 后台播放初始化失败时退回前台播放，不让 App 卡在启动页。
    }
    if (!mounted) return;
    _api = NioApi(
      customAlbumPageLoader: getCustomEpisodes,
      catalogAugmentor: mergeCustomAlbums,
    );
    _player = RadioPlayer();
    setState(() => _ready = true);
  }

  ThemeData _bootTheme(Brightness brightness) {
    // Keep scaffold on splash colors from frame 0 (matches native).
    return nioTheme(brightness).copyWith(
      scaffoldBackgroundColor: splashBackgroundFor(brightness),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NIO Radio',
      theme: _bootTheme(Brightness.light),
      darkTheme: _bootTheme(Brightness.dark),
      // Avoid a default Material white flash under the route.
      color: splashBackgroundFor(platformSplashBrightness()),
      builder: (context, child) {
        final brightness = Theme.of(context).brightness;
        return ColoredBox(
          color: splashBackgroundFor(brightness),
          child: child ??
              LaunchSplashRaw(logoImage: widget.splashLogo),
        );
      },
      home: _ready
          ? RadioApp(api: _api, player: _player)
          : LaunchSplashRaw(logoImage: widget.splashLogo),
    );
  }
}

class NioRadioApp extends StatelessWidget {
  const NioRadioApp({super.key, required this.api, required this.player});

  final NioApi api;
  final RadioPlayer player;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NIO Radio',
      theme: nioTheme(Brightness.light),
      darkTheme: nioTheme(Brightness.dark),
      home: RadioApp(api: api, player: player),
    );
  }
}
