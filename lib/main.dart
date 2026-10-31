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
  // Paint the branded splash on the first Flutter frame immediately.
  // JustAudioBackground.init (and AudioPlayer construction) run after that
  // so OEM/Android-12 handoff is not stuck on a blank NormalTheme window.
  runApp(const BootApp());
}

class BootApp extends StatefulWidget {
  const BootApp({super.key});

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

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NIO Radio',
      theme: nioTheme(Brightness.light),
      darkTheme: nioTheme(Brightness.dark),
      home: _ready
          ? RadioApp(api: _api, player: _player)
          : const LaunchSplashRaw(),
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
