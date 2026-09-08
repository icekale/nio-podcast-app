import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'api.dart';

const _favoritesKey = 'favorites';
const _laterKey = 'later';
const _historyKey = 'history';
const _playbackKey = 'playback';

List<int> loadFavorites(SharedPreferences prefs) =>
    (prefs.getStringList(_favoritesKey) ?? const []).map(int.parse).toList();

Future<void> saveFavorites(SharedPreferences prefs, List<int> ids) =>
    prefs.setStringList(_favoritesKey, [for (final id in ids) '$id']);

List<Episode> loadLater(SharedPreferences prefs) => _loadEpisodes(prefs, _laterKey);

Future<void> saveLater(SharedPreferences prefs, List<Episode> episodes) => _saveEpisodes(prefs, _laterKey, episodes);

List<Episode> loadHistory(SharedPreferences prefs) => _loadEpisodes(prefs, _historyKey);

Future<void> saveHistory(SharedPreferences prefs, List<Episode> episodes) => _saveEpisodes(prefs, _historyKey, episodes);

List<Episode> _loadEpisodes(SharedPreferences prefs, String key) => [
      for (final raw in prefs.getStringList(key) ?? const <String>[])
        Episode.fromJson(jsonDecode(raw) as Map<String, dynamic>),
    ];

Future<void> _saveEpisodes(SharedPreferences prefs, String key, List<Episode> episodes) =>
    prefs.setStringList(key, [for (final episode in episodes) jsonEncode(episode.toJson())]);

class SavedPlayback {
  const SavedPlayback({required this.queue, required this.index, required this.position, required this.duration});

  final List<Episode> queue;
  final int index;
  final Duration position;
  final Duration duration;
}

SavedPlayback? loadPlayback(SharedPreferences prefs) {
  final raw = prefs.getString(_playbackKey);
  if (raw == null) return null;
  try {
    final json = jsonDecode(raw) as Map<String, dynamic>;
    final queue = [for (final item in json['queue'] as List) Episode.fromJson(Map<String, dynamic>.from(item))];
    final index = (json['index'] as num?)?.toInt() ?? -1;
    if (queue.isEmpty || index < 0 || index >= queue.length) return null;
    return SavedPlayback(
      queue: queue,
      index: index,
      position: Duration(milliseconds: (json['positionMs'] as num?)?.toInt() ?? 0),
      duration: Duration(milliseconds: (json['durationMs'] as num?)?.toInt() ?? 0),
    );
  } catch (_) {
    return null;
  }
}

Future<void> savePlayback(
  SharedPreferences prefs, {
  required List<Episode> queue,
  required int index,
  required int positionMs,
  required int durationMs,
}) {
  return prefs.setString(
    _playbackKey,
    jsonEncode({
      'queue': [for (final episode in queue) episode.toJson()],
      'index': index,
      'positionMs': positionMs,
      'durationMs': durationMs,
    }),
  );
}
