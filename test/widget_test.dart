import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nio_radio/api.dart';
import 'package:nio_radio/main.dart';
import 'package:nio_radio/player.dart';

void main() {
  testWidgets('home matches web copy and plays into mini player', (tester) async {
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final client = MockClient((request) async {
      if (request.url.toString() == daytimeUrl) {
        return http.Response(jsonEncode({'result': []}), 200, headers: {'content-type': 'application/json; charset=utf-8'});
      }
      return http.Response(
        jsonEncode({
          'generatedAt': nowMs,
          'albums': [
            {
              'id': 5,
              'name': '资讯充电站',
              'imageUrl': '',
              'category': 'news',
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
              'category': 'audio',
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

    expect(find.text('NIO Radio'), findsWidgets);
    expect(find.text('今日推荐'), findsOneWidget);
    expect(find.text('TODAY'), findsOneWidget);
    expect(find.text('全部播放'), findsOneWidget);
    expect(find.text('今日更新'), findsOneWidget);
    expect(find.text('早间新闻'), findsWidgets);

    await tester.tap(find.text('全部播放'));
    await tester.pumpAndSettle();
    expect(player.current?.id, 11);
    expect(player.playing, isTrue);
    expect(find.text('暂停'), findsOneWidget);
    expect(find.byTooltip('打开播放列表'), findsOneWidget);

    await tester.tap(find.byTooltip('全部专辑'));
    await tester.pumpAndSettle();
    expect(find.text('资讯热点'), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('今日推荐'), findsOneWidget);

    await tester.tap(find.byTooltip('全部专辑'));
    await tester.pumpAndSettle();
    expect(find.text('资讯热点'), findsOneWidget);
    expect(find.byIcon(Icons.favorite_border), findsWidgets);
    expect(find.byIcon(Icons.star_border), findsNothing);

    await tester.tap(find.byTooltip('搜索'));
    await tester.pumpAndSettle();
    expect(find.text('搜索专辑'), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('今日推荐'), findsOneWidget);
  });

  testWidgets('album auto-loads next page without a button', (tester) async {
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final client = MockClient((request) async {
      if (request.url.toString() == daytimeUrl) {
        return http.Response(jsonEncode({'result': []}), 200, headers: {'content-type': 'application/json; charset=utf-8'});
      }
      if (request.url.toString() == albumListUrl) {
        final page = int.tryParse(Uri.splitQueryString(request.body)['pagenum'] ?? '1') ?? 1;
        final start = (page - 1) * 30;
        return http.Response(
          jsonEncode({
            'result': {
              'haveNext': page == 1 ? 1 : 0,
              'dataList': [
                for (var i = start; i < start + 30 && i < 35; i++)
                  {
                    'audioId': 100 + i,
                    'audioName': '专辑节目${i + 1}',
                    'albumId': 5,
                    'albumName': '资讯充电站',
                    'albumPic': '',
                    'host': '',
                    'duration': 60000,
                    'onlineTime': nowMs,
                    'aacPlayUrl192': 'https://cdn.example/e.m4a',
                  },
              ],
            },
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }
      return http.Response(
        jsonEncode({
          'generatedAt': nowMs,
          'albums': [
            {
              'id': 5,
              'name': '资讯充电站',
              'imageUrl': '',
              'category': 'news',
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
          ],
        }),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    });
    await tester.pumpWidget(NioRadioApp(api: NioApi(client: client), player: RadioPlayer(skipAudio: true)));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('全部专辑'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('资讯充电站'));
    await tester.pumpAndSettle();
    expect(find.text('加载更多'), findsNothing);
    expect(find.text('专辑节目1'), findsOneWidget);
    await tester.fling(find.byType(ListView), const Offset(0, -4000), 3000);
    await tester.pumpAndSettle();
    expect(find.text('专辑节目35'), findsOneWidget);
  });
}
