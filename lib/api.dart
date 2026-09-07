import 'dart:convert';

import 'package:http/http.dart' as http;

const catalogUrl = 'https://nio.k4le.top/data/albums.json';
const albumListUrl = 'https://gateway-front-external.nio.com/moat/100914/v2/audio/list';
const daytimeUrl = 'https://gateway-front-external.nio.com/moat/100914/v3/radio/list?pageSize=87';
const fetchTimeout = Duration(seconds: 8);

class ApiException implements Exception {
  ApiException(this.code, this.message);
  final String code;
  final String message;
  @override
  String toString() => message;
}

class Episode {
  const Episode({
    required this.id,
    required this.title,
    required this.albumId,
    required this.albumName,
    required this.albumPic,
    required this.host,
    required this.durationMs,
    required this.onlineTime,
    required this.audioUrl,
  });

  final int id;
  final String title;
  final int albumId;
  final String albumName;
  final String albumPic;
  final String host;
  final int durationMs;
  final int onlineTime;
  final String audioUrl;

  factory Episode.fromCatalog(Map<String, dynamic> json) {
    return Episode(
      id: _asInt(json['id']),
      title: (json['title'] as String?)?.trim().isNotEmpty == true ? json['title'] as String : '未命名节目',
      albumId: _asInt(json['albumId']),
      albumName: (json['albumName'] as String?) ?? '',
      albumPic: (json['albumPic'] as String?) ?? '',
      host: (json['host'] as String?) ?? '',
      durationMs: _asInt(json['duration']),
      onlineTime: _asInt(json['onlineTime']),
      audioUrl: normalizeAudioUrl(json['audioUrl'] as String? ?? ''),
    );
  }

  factory Episode.fromApi(Map<String, dynamic> json) {
    final host = json['host'];
    final hostText = host is List
        ? host.join(', ')
        : host is String
            ? host
            : (json['singer'] as String? ?? '');
    return Episode(
      id: _asInt(json['audioId'] ?? json['id']),
      title: (json['audioName'] as String?)?.trim().isNotEmpty == true
          ? json['audioName'] as String
          : '未命名节目',
      albumId: _asInt(json['albumId']),
      albumName: (json['albumName'] as String?) ?? '',
      albumPic: (json['albumPic'] as String?) ?? (json['audioPic'] as String?) ?? '',
      host: hostText,
      durationMs: _asInt(json['duration']),
      onlineTime: _asInt(json['onlineTime'] ?? json['updateTime']),
      audioUrl: normalizeAudioUrl(
        (json['aacPlayUrl192'] as String?) ??
            (json['aacPlayUrl128'] as String?) ??
            (json['mp3PlayUrl64'] as String?) ??
            (json['audioUrl'] as String?) ??
            '',
      ),
    );
  }
}

class Album {
  const Album({
    required this.id,
    required this.name,
    required this.imageUrl,
    required this.evergreen,
    this.latestEpisode,
  });

  final int id;
  final String name;
  final String imageUrl;
  final bool evergreen;
  final Episode? latestEpisode;

  factory Album.fromJson(Map<String, dynamic> json) {
    final latest = json['latestEpisode'];
    return Album(
      id: _asInt(json['id']),
      name: (json['name'] as String?) ?? '',
      imageUrl: (json['imageUrl'] as String?) ?? '',
      evergreen: json['evergreen'] == true,
      latestEpisode: latest is Map<String, dynamic> ? Episode.fromCatalog(latest) : null,
    );
  }
}

class Catalog {
  const Catalog({required this.generatedAt, required this.albums});
  final int generatedAt;
  final List<Album> albums;

  factory Catalog.fromJson(Map<String, dynamic> json) {
    final raw = json['albums'];
    if (raw is! List) {
      throw ApiException('INVALID_RESPONSE', '目录格式无效');
    }
    final albums = raw
        .whereType<Map>()
        .map((item) => Album.fromJson(Map<String, dynamic>.from(item)))
        .where((album) => album.latestEpisode != null)
        .toList()
      ..sort((a, b) {
        final time = (b.latestEpisode?.onlineTime ?? 0) - (a.latestEpisode?.onlineTime ?? 0);
        if (time != 0) return time;
        return a.id - b.id;
      });
    return Catalog(generatedAt: _asInt(json['generatedAt']), albums: albums);
  }
}

class HomeSelection {
  const HomeSelection({required this.heading, required this.episodes});
  final String heading;
  final List<Episode> episodes;
}

String normalizeAudioUrl(String url) {
  if (url.isEmpty) return '';
  return url.startsWith('http://') ? 'https://${url.substring(7)}' : url;
}

/// Matches nio-podcast-web/src/catalog.js getBeijingDayKey (JS month is 0-based).
String beijingDayKey(int timestampMs) {
  final shifted = DateTime.fromMillisecondsSinceEpoch(timestampMs + 8 * 60 * 60 * 1000, isUtc: true);
  return '${shifted.year}-${shifted.month - 1}-${shifted.day}';
}

HomeSelection selectHomeEpisodes(List<Album> albums, {DateTime? now}) {
  final nowMs = (now ?? DateTime.now()).millisecondsSinceEpoch;
  final seen = <int>{};
  final latest = <Episode>[];
  for (final album in albums) {
    if (album.evergreen) continue;
    final episode = album.latestEpisode;
    if (episode == null || !seen.add(episode.id)) continue;
    latest.add(episode);
  }
  final today = latest.where((episode) => beijingDayKey(episode.onlineTime) == beijingDayKey(nowMs)).take(12).toList();
  if (today.isNotEmpty) {
    return HomeSelection(heading: '今日更新', episodes: today);
  }
  return HomeSelection(heading: '最新更新', episodes: latest.take(12).toList());
}

class NioApi {
  NioApi({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Future<Catalog> fetchCatalog() async {
    final response = await _get(catalogUrl);
    return Catalog.fromJson(jsonDecode(response) as Map<String, dynamic>);
  }

  Future<List<Episode>> fetchAlbumEpisodes(int albumId, {int page = 1, int pageSize = 20}) async {
    final response = await _client
        .post(
          Uri.parse(albumListUrl),
          headers: {'Content-Type': 'application/x-www-form-urlencoded'},
          body: {
            'albumId': '$albumId',
            'sorttype': '2',
            'pagenum': '$page',
            'pageSize': '$pageSize',
          },
        )
        .timeout(fetchTimeout);
    if (response.statusCode != 200) {
      throw ApiException('HTTP_ERROR', '音频服务返回 ${response.statusCode} 状态');
    }
    final payload = jsonDecode(response.body);
    final result = payload is Map ? payload['result'] : null;
    final dataList = result is Map ? result['dataList'] : null;
    if (dataList is! List) {
      throw ApiException('INVALID_RESPONSE', '音频服务返回了无法读取的数据');
    }
    return dataList.whereType<Map>().map((item) => Episode.fromApi(Map<String, dynamic>.from(item))).toList();
  }

  Future<List<Episode>> fetchDaytimeEpisodes() async {
    final response = await _get(daytimeUrl);
    final payload = jsonDecode(response);
    final result = payload is Map ? payload['result'] : null;
    if (result is! List) {
      throw ApiException('INVALID_RESPONSE', '日间服务返回了无法读取的数据');
    }
    return result.whereType<Map>().map((item) => Episode.fromApi(Map<String, dynamic>.from(item))).toList();
  }

  Future<String> _get(String url) async {
    final response = await _client.get(Uri.parse(url)).timeout(fetchTimeout);
    if (response.statusCode != 200) {
      throw ApiException('HTTP_ERROR', '服务返回 ${response.statusCode} 状态');
    }
    return response.body;
  }
}

int _asInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse('$value') ?? 0;
}
