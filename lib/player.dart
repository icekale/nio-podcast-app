import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';

import 'api.dart';

class RadioPlayer extends ChangeNotifier {
  RadioPlayer({this.audio, this.skipAudio = false}) {
    if (!skipAudio) {
      _positionSub = engine.positionStream.listen((value) {
        // Guard against the engine still streaming pre-seek positions right after seek().
        if (DateTime.now().difference(_lastSeekAt).inMilliseconds < 400) return;
        final now = DateTime.now();
        if (now.difference(_lastPositionAt).inMilliseconds < 1000 && value < position + const Duration(seconds: 2)) {
          position = value;
          return;
        }
        _lastPositionAt = now;
        position = value;
        notifyListeners();
      });
      _durationSub = engine.durationStream.listen((value) {
        duration = value ?? Duration.zero;
        notifyListeners();
      });
      _completeSub = engine.processingStateStream.listen((state) {
        if (state != ProcessingState.completed) return;
        if (stopAfterEpisode) {
          stopAfterEpisode = false;
          playing = false;
          notifyListeners();
          unawaited(engine.pause());
          return;
        }
        unawaited(next());
      });
    }
  }

  final AudioPlayer? audio;
  final bool skipAudio;
  AudioPlayer? _owned;
  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<Duration?>? _durationSub;
  StreamSubscription<ProcessingState>? _completeSub;
  DateTime _lastPositionAt = DateTime.fromMillisecondsSinceEpoch(0);
  DateTime _lastSeekAt = DateTime.fromMillisecondsSinceEpoch(0);
  bool _loaded = false;

  Episode? current;
  List<Episode> queue = const [];
  List<Episode> history = const [];
  int index = -1;
  bool playing = false;
  Duration position = Duration.zero;
  Duration duration = Duration.zero;
  String? error;
  bool stopAfterEpisode = false;

  AudioPlayer get engine {
    if (audio != null) return audio!;
    return _owned ??= AudioPlayer();
  }

  void restore({
    required List<Episode> queue,
    required int index,
    required List<Episode> history,
    Duration position = Duration.zero,
    Duration duration = Duration.zero,
  }) {
    this.history = history;
    if (queue.isEmpty || index < 0 || index >= queue.length) return;
    this.queue = List.of(queue);
    this.index = index;
    current = queue[index];
    this.position = position;
    this.duration = duration;
    playing = false;
    _loaded = false;
    notifyListeners();
  }

  bool hasNeighbor(int direction) {
    for (var cursor = index + direction; cursor >= 0 && cursor < queue.length; cursor += direction) {
      if (queue[cursor].audioUrl.isNotEmpty) return true;
    }
    return false;
  }

  Future<void> playQueue(List<Episode> nextQueue, int nextIndex) async {
    if (nextIndex < 0 || nextIndex >= nextQueue.length) return;
    final next = nextQueue[nextIndex];
    if (current?.id == next.id) {
      queue = List.of(nextQueue);
      index = nextIndex;
      notifyListeners();
      if (!playing && next.audioUrl.isNotEmpty) {
        playing = true;
        notifyListeners();
        await _play();
      }
      return;
    }
    queue = List.of(nextQueue);
    index = nextIndex;
    current = queue[index];
    playing = current!.audioUrl.isNotEmpty;
    position = Duration.zero;
    duration = Duration.zero;
    _loaded = false;
    error = playing ? null : '该节目没有可播放音频，请稍后重试';
    history = [
      current!,
      ...history.where((episode) => episode.id != current!.id),
    ].take(100).toList();
    notifyListeners();
    if (skipAudio || current!.audioUrl.isEmpty) return;
    await _play(reload: true);
  }

  Future<void> playEpisode(Episode episode, [List<Episode>? visibleQueue]) async {
    final nextQueue = visibleQueue != null && visibleQueue.isNotEmpty ? visibleQueue : (queue.isEmpty ? [episode] : queue);
    final found = nextQueue.indexWhere((item) => item.id == episode.id);
    final withEpisode = found >= 0 ? nextQueue : [...nextQueue, episode];
    await playQueue(withEpisode, found >= 0 ? found : withEpisode.length - 1);
  }

  Future<void> toggle() async {
    final episode = current;
    if (episode == null) return;
    if (playing) {
      playing = false;
      notifyListeners();
      if (!skipAudio) await engine.pause();
      return;
    }
    if (episode.audioUrl.isEmpty) {
      error = '该节目没有可播放音频，请稍后重试';
      notifyListeners();
      return;
    }
    playing = true;
    notifyListeners();
    await _play();
  }

  Future<void> seek(Duration value) async {
    _lastSeekAt = DateTime.now();
    position = value;
    notifyListeners();
    if (!skipAudio && _loaded) await engine.seek(value);
  }

  Future<void> next() async {
    await _step(1);
  }

  Future<void> previous() async {
    await _step(-1);
  }

  Future<void> playNext(Episode episode) async {
    if (current?.id == episode.id) return;
    final next = queue.where((item) => item.id != episode.id).toList();
    final insertAt = (index + 1).clamp(0, next.length);
    next.insert(insertAt, episode);
    queue = next;
    index = next.indexWhere((item) => item.id == current?.id);
    notifyListeners();
  }

  Future<void> removeFromQueue(int episodeId) async {
    final removed = queue.indexWhere((item) => item.id == episodeId);
    if (removed < 0) return;
    final next = [...queue]..removeAt(removed);
    if (next.isEmpty) {
      queue = const [];
      index = -1;
      current = null;
      playing = false;
      notifyListeners();
      if (!skipAudio) await engine.stop();
      return;
    }
    if (removed == index) {
      await playQueue(next, removed.clamp(0, next.length - 1));
      return;
    }
    queue = next;
    if (removed < index) index -= 1;
    notifyListeners();
  }

  Future<void> _play({bool reload = false}) async {
    if (skipAudio) return;
    try {
      if (reload || !_loaded) {
        await engine.setAudioSource(AudioSource.uri(Uri.parse(current!.audioUrl), tag: _mediaItem(current!)));
        if (!reload && position > Duration.zero) await engine.seek(position);
        _loaded = true;
      }
      await engine.play();
    } catch (_) {
      error = '无法播放该节目';
      playing = false;
      _loaded = false;
      notifyListeners();
    }
  }

  MediaItem _mediaItem(Episode episode) {
    return MediaItem(
      id: '${episode.id}',
      title: episode.title,
      album: episode.albumName.isEmpty ? 'NIO Radio' : episode.albumName,
      artist: episode.host.isEmpty ? 'NIO Radio' : episode.host,
      artUri: episode.albumPic.isNotEmpty ? Uri.parse(episode.albumPic) : null,
      duration: episode.durationMs > 0 ? Duration(milliseconds: episode.durationMs) : null,
    );
  }

  Future<void> _step(int direction) async {
    var cursor = index + direction;
    while (cursor >= 0 && cursor < queue.length) {
      if (queue[cursor].audioUrl.isNotEmpty) {
        await playQueue(queue, cursor);
        return;
      }
      cursor += direction;
    }
  }

  @override
  void dispose() {
    unawaited(_positionSub?.cancel());
    unawaited(_durationSub?.cancel());
    unawaited(_completeSub?.cancel());
    _owned?.dispose();
    super.dispose();
  }
}
