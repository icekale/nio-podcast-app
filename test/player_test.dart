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
}
