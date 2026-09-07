import 'package:flutter/material.dart';

import 'api.dart';
import 'home.dart';
import 'player.dart';
import 'theme.dart';

void main() {
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
      home: HomePage(api: api, player: player),
    );
  }
}
