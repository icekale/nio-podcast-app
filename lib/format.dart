String formatDuration(int milliseconds) {
  if (milliseconds < 0) return '--:--';
  final totalSeconds = milliseconds ~/ 1000;
  final hours = totalSeconds ~/ 3600;
  final minutes = (totalSeconds % 3600) ~/ 60;
  final seconds = totalSeconds % 60;
  if (hours > 0) {
    return '$hours:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
  return '$minutes:${seconds.toString().padLeft(2, '0')}';
}

String formatClock(num seconds) {
  if (seconds.isNaN || seconds < 0) return '0:00';
  return formatDuration((seconds.floor()) * 1000);
}

String formatDate(int timestampMs) {
  if (timestampMs <= 0) return '';
  final date = DateTime.fromMillisecondsSinceEpoch(timestampMs);
  return '${date.month}/${date.day}';
}
