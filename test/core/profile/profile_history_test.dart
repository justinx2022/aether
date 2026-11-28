import 'package:flutter_test/flutter_test.dart';
import 'package:skystream/core/domain/entity/multimedia_item.dart';
import 'package:skystream/core/profile/profile_history.dart';
import 'package:skystream/core/profile/user_profile.dart';
import 'package:skystream/core/storage/history_repository.dart';

HistoryItem _row({
  required String title,
  String? profileId,
  int timestamp = 1,
}) {
  return HistoryItem(
    item: MultimediaItem(
      title: title,
      url: 'https://example.test/$title',
      posterUrl: '',
    ),
    position: 10,
    duration: 100,
    timestamp: timestamp,
    profileId: profileId,
  );
}

UserProfile _profile(String id, DateTime created) {
  return UserProfile(
    id: id,
    name: id,
    avatarId: 'avatar',
    createdAt: created,
  );
}

void main() {
  final older = _profile('first', DateTime.utc(2020));
  final newer = _profile('second', DateTime.utc(2024));

  test('untagged history stays with the first profile', () {
    final rows = [
      _row(title: 'MobLand', profileId: null),
      _row(title: 'Other', profileId: 'second'),
    ];

    final first = historyForProfile(rows, older, [newer, older]);
    final second = historyForProfile(rows, newer, [newer, older]);

    expect(first.map((row) => row.item.title), ['MobLand']);
    expect(second.map((row) => row.item.title), ['Other']);
  });

  test('a profile does not see another profile because-you-watched source', () {
    final rows = [_row(title: 'MobLand', profileId: 'first', timestamp: 5)];

    expect(historyForProfile(rows, newer, [older, newer]), isEmpty);
    expect(
      historyForProfile(rows, older, [older, newer]).single.item.title,
      'MobLand',
    );
  });
}
