import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nio_radio/api.dart';
import 'package:nio_radio/covers.dart';

void main() {
  late Directory dir;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('nio_covers_test');
    CoverStore.reset();
    CoverStore.overrideDir = dir;
  });

  tearDown(() {
    CoverStore.reset();
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  });

  test('prefetch writes album covers to disk once', () async {
    var hits = 0;
    CoverStore.client = MockClient((request) async {
      hits += 1;
      return http.Response.bytes([1, 2, 3, 4], 200);
    });
    const album = Album(
      id: 5,
      name: '资讯充电站',
      imageUrl: 'https://cdn.example/cover.jpg',
      category: 'news',
      evergreen: false,
    );
    await CoverStore.prefetch([album, album]);
    expect(hits, 1);
    expect(CoverStore.lookup(album.imageUrl)!.readAsBytesSync(), [1, 2, 3, 4]);
    await CoverStore.ensure(album.imageUrl);
    expect(hits, 1);
  });

  test('prefetch trims cache down to maxFiles', () async {
    CoverStore.maxFiles = 3;
    CoverStore.client = MockClient((request) async => http.Response.bytes([1, 2, 3, 4], 200));
    for (var i = 0; i < 5; i++) {
      File('${dir.path}/old$i').writeAsStringSync('x');
    }
    final cover = Album(
      id: 5,
      name: '资讯充电站',
      imageUrl: 'https://cdn.example/cover.jpg',
      category: 'news',
      evergreen: false,
    );
    await CoverStore.prefetch([cover]);
    expect(CoverStore.lookup(cover.imageUrl), isNotNull);
    await CoverStore.prefetch([cover]);
    final remaining = dir.listSync().whereType<File>().length;
    expect(remaining, CoverStore.maxFiles);
    expect(CoverStore.lookup(cover.imageUrl), isNotNull);
  });
}
