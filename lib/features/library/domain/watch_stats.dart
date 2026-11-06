import '../../../core/storage/history_repository.dart';

class WatchStats {
  final int titles;
  final Duration watched;
  final int finished;
  final List<MapEntry<String, int>> topGenres;

  const WatchStats({
    required this.titles,
    required this.watched,
    required this.finished,
    required this.topGenres,
  });
}

WatchStats watchStatsFor(List<HistoryItem> rows) {
  var millis = 0;
  var finished = 0;
  final genres = <String, int>{};
  for (final row in rows) {
    millis += row.position;
    if (row.duration > 0 && row.position >= (row.duration * 0.9)) {
      finished++;
    }
    for (final tag in row.item.tags ?? const <String>[]) {
      final name = tag.trim();
      if (name.isEmpty) continue;
      genres[name] = (genres[name] ?? 0) + 1;
    }
  }
  final ranked = genres.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  return WatchStats(
    titles: rows.length,
    watched: Duration(milliseconds: millis),
    finished: finished,
    topGenres: ranked.take(5).toList(),
  );
}
