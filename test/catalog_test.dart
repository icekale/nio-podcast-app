import 'package:flutter_test/flutter_test.dart';
import 'package:nio_radio/api.dart';
import 'package:nio_radio/catalog.dart';

Episode _episode(int albumId) => Episode(
      id: albumId,
      title: 'E$albumId',
      albumId: albumId,
      albumName: 'A$albumId',
      albumPic: '',
      host: '',
      durationMs: 1000,
      onlineTime: 1,
      audioUrl: 'https://cdn.example/$albumId.m4a',
    );

Album _album(int id, String name, {String? category}) => Album(
      id: id,
      name: name,
      imageUrl: '',
      category: category,
      evergreen: false,
      latestEpisode: _episode(id),
    );

void main() {
  test('groupAlbumsByCategory uses labels and favorite pin order', () {
    final albums = [
      _album(11, '乐行记', category: 'audio'),
      _album(5, '资讯充电站', category: 'news'),
      _album(35, '芝士分子', category: 'kids'),
      _album(99, '未分类测试'),
    ];
    final data = groupAlbumsByCategory(albums, [11]);
    expect(data.groups.firstWhere((group) => group.id == 'news').label, '资讯热点');
    expect(data.groups.firstWhere((group) => group.id == 'audio').albums.first.id, 11);
    expect(data.groups.firstWhere((group) => group.id == 'news').albums.first.id, 5);
    expect(data.rest.single.id, 99);
  });

  test('mergeDaytime uses 日间 heading', () {
    final fallback = HomeSelection(heading: '今日更新', episodes: [_episode(1), _episode(2)]);
    final merged = mergeDaytime(fallback, [_episode(3)]);
    expect(merged.heading, '日间');
    expect(merged.episodes.map((e) => e.id), [3, 1, 2]);
  });
}
