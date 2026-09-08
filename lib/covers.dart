import 'dart:io';

import 'package:http/http.dart' as http;

import 'api.dart';

class CoverStore {
  static Directory? overrideDir;
  static http.Client? client;
  static final _inflight = <String, Future<File?>>{};
  /// ponytail: cap is a file count, not bytes — cheap trim, upgrade to LRU-by-bytes if covers grow past ~50MB.
  static var maxFiles = 3000;

  static Directory get directory {
    final dir = overrideDir ?? Directory('${Directory.systemTemp.path}/nio_covers');
    dir.createSync(recursive: true);
    return dir;
  }

  static File fileFor(String url) => File('${directory.path}/${url.hashCode & 0xffffffff}');

  static File? lookup(String url) {
    if (url.isEmpty) return null;
    final file = fileFor(url);
    return file.existsSync() && file.lengthSync() > 0 ? file : null;
  }

  static Future<File?> ensure(String url) {
    if (url.isEmpty) return Future<File?>.value();
    return _inflight.putIfAbsent(url, () async {
      try {
        final existing = lookup(url);
        if (existing != null) return existing;
        final response = await (client ?? http.Client()).get(Uri.parse(url)).timeout(const Duration(seconds: 8));
        if (response.statusCode != 200 || response.bodyBytes.isEmpty) return null;
        final file = fileFor(url);
        await file.writeAsBytes(response.bodyBytes, flush: true);
        return file;
      } catch (_) {
        return null;
      } finally {
        _inflight.remove(url);
      }
    });
  }

  static void _trimExcess() {
    final files = directory.listSync().whereType<File>().toList();
    if (files.length <= maxFiles) return;
    files.sort((a, b) => a.lastModifiedSync().compareTo(b.lastModifiedSync()));
    for (final file in files.take(files.length - maxFiles)) {
      try {
        file.deleteSync();
      } catch (_) {}
    }
  }

  static Future<void> prefetch(Iterable<Album> albums) async {
    _trimExcess();
    final urls = <String>[
      for (final album in albums) ...[
        if (album.imageUrl.isNotEmpty) album.imageUrl,
        if (album.imageUrlDark.isNotEmpty) album.imageUrlDark,
      ],
    ];
    var index = 0;
    Future<void> worker() async {
      while (index < urls.length) {
        final url = urls[index++];
        await ensure(url);
      }
    }

    await Future.wait(List.generate(4, (_) => worker()));
  }

  static void reset() {
    _inflight.clear();
    overrideDir = null;
    client = null;
  }
}
