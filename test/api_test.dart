import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nio_radio/api.dart';

void main() {
  test('normalizeAudioUrl upgrades http', () {
    expect(normalizeAudioUrl('http://cdn.example/a.m4a'), 'https://cdn.example/a.m4a');
    expect(normalizeAudioUrl('https://cdn.example/a.m4a'), 'https://cdn.example/a.m4a');
    expect(normalizeAudioUrl(''), '');
  });

  test('selectHomeEpisodes prefers today then caps at 12', () {
    final now = DateTime.utc(2026, 9, 7, 4);
    final nowMs = now.millisecondsSinceEpoch;
    final albums = [
      for (var i = 0; i < 15; i++)
        Album(
          id: i,
          name: 'A$i',
          imageUrl: '',
          evergreen: i == 0,
          latestEpisode: Episode(
            id: 100 + i,
            title: 'E$i',
            albumId: i,
            albumName: 'A$i',
            albumPic: '',
            host: '',
            durationMs: 60000,
            onlineTime: nowMs - (i < 3 ? 0 : 48 * 60 * 60 * 1000),
            audioUrl: 'https://cdn.example/$i.m4a',
          ),
        ),
    ];
    final today = selectHomeEpisodes(albums, now: now);
    expect(today.heading, '今日更新');
    expect(today.episodes.map((e) => e.id), [101, 102]);

    final stale = selectHomeEpisodes(albums, now: DateTime.utc(2026, 1, 1));
    expect(stale.heading, '最新更新');
    expect(stale.episodes.length, 12);
    expect(stale.episodes.first.id, 101);
  });

  test('Episode.fromApi maps play url and host list', () {
    final episode = Episode.fromApi({
      'audioId': 9,
      'audioName': '早间',
      'albumId': 5,
      'albumName': '资讯充电站',
      'host': ['甲', '乙'],
      'duration': 120000,
      'onlineTime': 1,
      'aacPlayUrl192': 'http://cdn.example/a.m4a',
    });
    expect(episode.id, 9);
    expect(episode.host, '甲, 乙');
    expect(episode.audioUrl, 'https://cdn.example/a.m4a');
  });

  test('NioApi.fetchCatalog and fetchAlbumEpisodes parse payloads', () async {
    final client = MockClient((request) async {
      if (request.url.toString() == catalogUrl) {
        return http.Response(
          jsonEncode({
            'generatedAt': 1,
            'albums': [
              {
                'id': 5,
                'name': '资讯充电站',
                'imageUrl': 'https://cdn.example/a.png',
                'latestEpisode': {
                  'id': 11,
                  'title': '早间',
                  'albumId': 5,
                  'albumName': '资讯充电站',
                  'albumPic': '',
                  'host': '',
                  'duration': 1000,
                  'onlineTime': 2,
                  'audioUrl': 'https://cdn.example/a.m4a',
                },
              },
            ],
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }
      expect(request.url.toString(), albumListUrl);
      expect(request.method, 'POST');
      expect(request.bodyFields['sorttype'], '2');
      return http.Response(
        jsonEncode({
          'result': {
            'dataList': [
              {
                'audioId': 11,
                'audioName': '早间',
                'albumId': 5,
                'aacPlayUrl128': 'https://cdn.example/a.m4a',
                'duration': 1000,
              },
            ],
            'haveNext': 0,
          },
        }),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    });
    final api = NioApi(client: client);
    final catalog = await api.fetchCatalog();
    expect(catalog.albums.single.name, '资讯充电站');
    final episodes = await api.fetchAlbumEpisodes(5);
    expect(episodes.single.title, '早间');
  });

  test('NioApi.fetchDaytimeEpisodes maps result list', () async {
    final client = MockClient((request) async {
      expect(request.url.toString(), daytimeUrl);
      return http.Response(
        jsonEncode({
          'result': [
            {
              'audioId': 1,
              'audioName': '推荐',
              'albumId': 5,
              'audioPic': 'https://cdn.example/p.png',
              'mp3PlayUrl64': 'https://cdn.example/a.mp3',
            },
          ],
        }),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    });
    final episodes = await NioApi(client: client).fetchDaytimeEpisodes();
    expect(episodes.single.title, '推荐');
    expect(episodes.single.albumPic, 'https://cdn.example/p.png');
  });
}
