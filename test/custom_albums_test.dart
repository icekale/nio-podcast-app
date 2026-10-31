import 'package:flutter_test/flutter_test.dart';
import 'package:nio_radio/api.dart';
import 'package:nio_radio/custom_albums.dart';
import 'package:nio_radio/player.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'dart:convert';

void main() {
  test('白噪音 album mirrors web id, count, and loop-one', () {
    expect(customWhiteNoiseAlbumId, 900001);
    expect(customWhiteNoiseAlbum.name, '白噪音');
    expect(customWhiteNoiseAlbum.category, 'news');
    expect(customWhiteNoiseAlbum.evergreen, isTrue);
    expect(customWhiteNoiseEpisodes.length, 113);
    expect(customWhiteNoiseEpisodes.first.id, 900001001);
    expect(customWhiteNoiseEpisodes.first.title, '小雨');
    expect(customWhiteNoiseEpisodes.first.playbackMode, 'loop-one');
    expect(customWhiteNoiseEpisodes.first.audioUrl, contains('XMSLEEP'));
    expect(customWhiteNoiseEpisodes.first.audioUrl, endsWith('rain/light-rain.ogg'));
    expect(customWhiteNoiseEpisodes.last.title, '屋檐落雨');
    expect(isLoopingEpisode(customWhiteNoiseEpisodes.first), isTrue);
    expect(isCustomAlbumId(900001), isTrue);
    expect(isCustomAlbumId(5), isFalse);
  });

  test('getCustomEpisodes paginates', () {
    final page1 = getCustomEpisodes(900001, page: 1, pageSize: 30)!;
    expect(page1.episodes.length, 30);
    expect(page1.hasMore, isTrue);
    final page4 = getCustomEpisodes(900001, page: 4, pageSize: 30)!;
    expect(page4.episodes.length, 23);
    expect(page4.hasMore, isFalse);
    expect(getCustomEpisodes(5), isNull);
  });

  test('mergeCustomAlbums injects evergreen album and skips home today', () {
    final remote = Catalog(
      generatedAt: 1,
      albums: [
        Album(
          id: 5,
          name: '资讯充电站',
          imageUrl: '',
          evergreen: false,
          latestEpisode: Episode(
            id: 11,
            title: '早间',
            albumId: 5,
            albumName: '资讯',
            albumPic: '',
            host: '',
            durationMs: 1,
            onlineTime: DateTime.now().millisecondsSinceEpoch,
            audioUrl: 'https://cdn.example/a.m4a',
          ),
        ),
      ],
    );
    final merged = mergeCustomAlbums(remote);
    expect(merged.albums.any((a) => a.id == 900001), isTrue);
    expect(merged.albums.where((a) => a.id == 900001).length, 1);
    final home = selectHomeEpisodes(merged.albums);
    expect(home.episodes.any((e) => e.albumId == 900001), isFalse);
  });

  test('NioApi serves custom album without gateway', () async {
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
                  'duration': 1000,
                  'onlineTime': 1,
                  'audioUrl': 'https://cdn.example/a.m4a',
                },
              },
            ],
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }
      return http.Response('should not hit gateway for custom', 500);
    });
    final api = NioApi(
      client: client,
      customAlbumPageLoader: getCustomEpisodes,
      catalogAugmentor: mergeCustomAlbums,
    );
    final catalog = await api.fetchCatalog();
    expect(catalog.albums.any((a) => a.name == '白噪音'), isTrue);
    final page = await api.fetchAlbumPage(900001, page: 1, pageSize: 10);
    expect(page.episodes.length, 10);
    expect(page.episodes.first.playbackMode, 'loop-one');
    expect(page.hasMore, isTrue);
  });

  test('RadioPlayer clears stopAfterEpisode for loop-one', () async {
    final player = RadioPlayer(skipAudio: true);
    player.stopAfterEpisode = true;
    await player.playEpisode(customWhiteNoiseEpisodes.first);
    expect(player.stopAfterEpisode, isFalse);
    expect(isLoopingEpisode(player.current), isTrue);
  });
}
