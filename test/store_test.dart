import 'package:flutter_test/flutter_test.dart';
import 'package:nio_radio/api.dart';
import 'package:nio_radio/store.dart';
import 'package:shared_preferences/shared_preferences.dart';

Episode _episode(int id) => Episode(
      id: id,
      title: '节目$id',
      albumId: 1,
      albumName: '专辑',
      albumPic: '',
      host: '',
      durationMs: 60000,
      onlineTime: 1,
      audioUrl: 'https://cdn.example/$id.m4a',
    );

void main() {
  test('favorites, episode lists, and playback round-trip', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    await saveFavorites(prefs, [5, 23]);
    expect(loadFavorites(prefs), [5, 23]);

    await saveLater(prefs, [_episode(11), _episode(12)]);
    final later = loadLater(prefs);
    expect(later.map((e) => e.id), [11, 12]);
    expect(later.singleWhere((e) => e.id == 11).audioUrl, 'https://cdn.example/11.m4a');

    await saveHistory(prefs, [_episode(12)]);
    expect(loadHistory(prefs).single.id, 12);

    await savePlayback(prefs, queue: [_episode(11), _episode(12)], index: 1, positionMs: 45000, durationMs: 60000);
    final playback = loadPlayback(prefs)!;
    expect(playback.index, 1);
    expect(playback.position, const Duration(milliseconds: 45000));
    expect(playback.duration, const Duration(milliseconds: 60000));
    expect(playback.queue.map((e) => e.id), [11, 12]);
  });

  test('loadPlayback rejects empty queue and out-of-range index', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    expect(loadPlayback(prefs), isNull);
    await savePlayback(prefs, queue: const [], index: -1, positionMs: 0, durationMs: 0);
    expect(loadPlayback(prefs), isNull);
  });
}
