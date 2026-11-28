import 'package:flutter_test/flutter_test.dart';
import 'package:skystream/core/domain/entity/multimedia_item.dart';
import 'package:skystream/core/profile/profile_feed.dart';
import 'package:skystream/core/profile/user_profile.dart';

MultimediaItem _item({
  required String title,
  MultimediaContentType type = MultimediaContentType.movie,
  List<String>? tags,
  bool isAdult = false,
  String? contentRating,
  String? description,
}) {
  return MultimediaItem(
    title: title,
    url: 'https://example.test/$title',
    posterUrl: '',
    contentType: type,
    tags: tags,
    isAdult: isAdult,
    contentRating: contentRating,
    description: description,
  );
}

UserProfile _profile({
  String feedMode = 'all',
  bool isKids = false,
  List<String> genres = const [],
}) {
  return UserProfile(
    id: 'p1',
    name: 'Alex',
    avatarId: 'avatar_cinema',
    isKids: isKids,
    preferredGenres: genres,
    feedMode: feedMode,
    createdAt: DateTime.utc(2026, 1, 1),
  );
}

void main() {
  final home = {
    'Trending': [
      _item(title: 'Dune', tags: const ['Sci-Fi', 'Adventure']),
      _item(
        title: 'Late Show',
        type: MultimediaContentType.series,
        tags: const ['Comedy'],
        contentRating: 'TV-MA',
      ),
      _item(
        title: 'Spirited',
        type: MultimediaContentType.series,
        tags: const ['Anime', 'Action'],
      ),
    ],
    'New': [
      _item(title: 'After Hours', isAdult: true, tags: const ['Drama']),
    ],
  };

  test('movies feed drops series and builds a genre shelf', () {
    final shaped = shapeHomeForProfile(
      home,
      _profile(feedMode: 'movies', genres: const ['Sci-Fi']),
    );

    expect(shaped.sections['Trending']!.map((e) => e.title), ['Dune']);
    expect(shaped.sections['New']!.map((e) => e.title), ['After Hours']);
    expect(shaped.forYou.map((e) => e.title), ['Dune']);
  });

  test('kids profile hides adult flags and mature ratings', () {
    final shaped = shapeHomeForProfile(home, _profile(isKids: true));
    final titles = shaped.sections.values
        .expand((items) => items)
        .map((item) => item.title);

    expect(titles, containsAll(['Dune', 'Spirited']));
    expect(titles, isNot(contains('Late Show')));
    expect(titles, isNot(contains('After Hours')));
  });

  test('a mention of violence is not treated as adult', () {
    final item = _item(
      title: 'Space Race',
      description: 'A story about violence on the frontier.',
    );
    expect(blockedForKids(item), isFalse);
  });

  test('anime feed keeps a series tagged anime', () {
    final shaped = shapeHomeForProfile(home, _profile(feedMode: 'anime'));
    expect(
      shaped.sections['Trending']!.map((e) => e.title),
      ['Spirited'],
    );
  });
}
