import 'package:flutter_test/flutter_test.dart';
import 'package:nio_radio/format.dart';

void main() {
  test('formatDuration matches web clock', () {
    expect(formatDuration(-1), '--:--');
    expect(formatDuration(0), '0:00');
    expect(formatDuration(65000), '1:05');
    expect(formatDuration(3600000), '1:00:00');
    expect(formatClock(65), '1:05');
    expect(formatDate(DateTime(2026, 8, 27).millisecondsSinceEpoch), '8/27');
  });
}
