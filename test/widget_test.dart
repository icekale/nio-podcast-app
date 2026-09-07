import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nio_radio/api.dart';
import 'package:nio_radio/main.dart';
import 'package:nio_radio/player.dart';

void main() {
  testWidgets('home list plays into mini player and queue', (tester) async {
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final client = MockClient((request) async {
      return http.Response(
        jsonEncode({
          'generatedAt': nowMs,
          'albums': [
            {
              'id': 5,
              'name': '资讯充电站',
              'imageUrl': '',
              'latestEpisode': {
                'id': 11,
                'title': '早间新闻',
                'albumId': 5,
                'albumName': '资讯充电站',
                'albumPic': '',
                'host': '',
                'duration': 60000,
                'onlineTime': nowMs,
                'audioUrl': 'https://cdn.example/a.m4a',
              },
            },
            {
              'id': 11,
              'name': '乐行记',
              'imageUrl': '',
              'latestEpisode': {
                'id': 12,
                'title': '路上',
                'albumId': 11,
                'albumName': '乐行记',
                'albumPic': '',
                'host': '',
                'duration': 120000,
                'onlineTime': nowMs,
                'audioUrl': 'https://cdn.example/b.m4a',
              },
            },
          ],
        }),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    });
    final player = RadioPlayer(skipAudio: true);
    await tester.pumpWidget(NioRadioApp(api: NioApi(client: client), player: player));
    await tester.pumpAndSettle();

    expect(find.text('今日更新'), findsOneWidget);
    expect(find.text('早间新闻'), findsOneWidget);

    await tester.tap(find.text('早间新闻'));
    await tester.pumpAndSettle();
    expect(player.current?.id, 11);
    expect(player.playing, isTrue);
    expect(find.byIcon(Icons.pause_circle), findsOneWidget);

    await tester.tap(find.byIcon(Icons.queue_music));
    await tester.pumpAndSettle();
    expect(find.byType(ListTile), findsWidgets);
    await tester.tap(find.text('路上').last);
    await tester.pumpAndSettle();
    expect(player.current?.id, 12);
  });
}
