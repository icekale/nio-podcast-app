import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

import 'api.dart';

class RadioPlayer extends ChangeNotifier {
  RadioPlayer({this.audio, this.skipAudio = false});

  final AudioPlayer? audio;
  final bool skipAudio;
  AudioPlayer? _owned;

  Episode? current;
  List<Episode> queue = const [];
  int index = -1;
  bool playing = false;

  AudioPlayer get engine {
    if (audio != null) return audio!;
    return _owned ??= AudioPlayer();
  }

  Future<void> playQueue(List<Episode> nextQueue, int nextIndex) async {
    if (nextIndex < 0 || nextIndex >= nextQueue.length) return;
    queue = List.of(nextQueue);
    index = nextIndex;
    current = queue[index];
    playing = true;
    notifyListeners();
    if (skipAudio || current!.audioUrl.isEmpty) return;
    await engine.setUrl(current!.audioUrl);
    await engine.play();
  }

  Future<void> toggle() async {
    if (current == null) return;
    if (playing) {
      playing = false;
      notifyListeners();
      if (!skipAudio) await engine.pause();
      return;
    }
    playing = true;
    notifyListeners();
    if (!skipAudio) await engine.play();
  }

  Future<void> next() async {
    if (index + 1 < queue.length) await playQueue(queue, index + 1);
  }

  Future<void> previous() async {
    if (index > 0) await playQueue(queue, index - 1);
  }

  @override
  void dispose() {
    _owned?.dispose();
    super.dispose();
  }
}
