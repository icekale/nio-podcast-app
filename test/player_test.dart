import 'package:flutter_test/flutter_test.dart';
import 'package:nio_radio/api.dart';
import 'package:nio_radio/player.dart';

Episode _episode(int id) => Episode(
      id: id,
      title: '节目$id',
      albumId: 1,
      albumName: '专辑',
      albumPic: '',
      host: '',
      durationMs: 60000,
      onlineTime: 0,
      audioUrl: 'https://cdn.example/$id.m4a',
    );

void main() {
  test('playQueue same episode keeps position', () async {
    final player = RadioPlayer(skipAudio: true);
    final episode = _episode(11);
    await player.playQueue([episode], 0);
    player.position = const Duration(seconds: 12);
    await player.playQueue([episode, _episode(12)], 0);
    expect(player.current?.id, 11);
    expect(player.playing, isTrue);
    expect(player.position, const Duration(seconds: 12));
    expect(player.queue.length, 2);
  });

  test('playQueue marks episode without audio as not playing', () async {
    final player = RadioPlayer(skipAudio: true);
    await player.playQueue([
      Episode(
        id: 13,
        title: '无声',
        albumId: 1,
        albumName: '专辑',
        albumPic: '',
        host: '',
        durationMs: 60000,
        onlineTime: 0,
        audioUrl: '',
      ),
    ], 0);
    expect(player.playing, isFalse);
    expect(player.error, isNotNull);
  });

  test('restore resumes queue and position without autoplay', () {
    final player = RadioPlayer(skipAudio: true);
    player.restore(
      queue: [_episode(11), _episode(12)],
      index: 1,
      history: [_episode(11)],
      position: const Duration(seconds: 45),
      duration: const Duration(seconds: 60),
    );
    expect(player.current?.id, 12);
    expect(player.playing, isFalse);
    expect(player.position, const Duration(seconds: 45));
    expect(player.duration, const Duration(seconds: 60));
    expect(player.history.single.id, 11);
  });

  test('toggle resumes a restored episode', () async {
    final player = RadioPlayer(skipAudio: true);
    player.restore(queue: [_episode(11)], index: 0, history: const [], position: const Duration(seconds: 45));
    await player.toggle();
    expect(player.playing, isTrue);
  });

  test('restore ignores broken queue payloads', () {
    final player = RadioPlayer(skipAudio: true);
    player.restore(queue: [], index: -1, history: [_episode(11)]);
    expect(player.current, isNull);
    expect(player.history.single.id, 11);
  });
}
