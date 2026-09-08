import 'package:flutter/material.dart';
import 'package:just_audio_background/just_audio_background.dart';

import 'api.dart';
import 'player.dart';
import 'screens.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
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
  runApp(NioRadioApp(api: NioApi(), player: RadioPlayer()));
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
