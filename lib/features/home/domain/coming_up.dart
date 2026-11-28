import '../../../core/domain/entity/multimedia_item.dart';

/// Titles in the current home rows that air within the next seven days.
List<MultimediaItem> comingThisWeek(
  Map<String, List<MultimediaItem>> sections, {
  DateTime? now,
}) {
  final clock = now ?? DateTime.now();
  final start = clock.millisecondsSinceEpoch ~/ 1000;
  final end = start + 7 * 24 * 3600;
  final seen = <String>{};
  final items = <MultimediaItem>[];
  for (final row in sections.values) {
    for (final item in row) {
      final air = item.nextAiring;
      if (air == null) continue;
      if (air.unixTime < start || air.unixTime > end) continue;
      if (seen.add(item.url)) items.add(item);
    }
  }
  items.sort(
    (a, b) => a.nextAiring!.unixTime.compareTo(b.nextAiring!.unixTime),
  );
  return items;
}
