import '../domain/entity/multimedia_item.dart';
import 'user_profile.dart';

/// Home shelves after the active profile's feed, genre, and kids choices.
class ShapedHome {
  final Map<String, List<MultimediaItem>> sections;

  /// Titles from the current shelves that match [UserProfile.preferredGenres].
  final List<MultimediaItem> forYou;

  const ShapedHome({required this.sections, required this.forYou});
}

/// Whether [item] belongs on a kids profile.
///
/// Uses the item's own adult flag and a mature rating when the catalogue
/// sent one. A description that merely mentions violence is left alone:
/// that word shows up on ordinary action titles.
bool blockedForKids(MultimediaItem item) {
  if (item.isAdult) return true;
  final rating = (item.contentRating ?? '').trim().toUpperCase();
  const mature = {
    'R',
    'NC-17',
    'TV-MA',
    '18',
    '18+',
    'X',
    'XXX',
    'AO',
    'R18',
    'R18+',
    'MA',
  };
  if (mature.contains(rating)) return true;
  final title = item.title.toLowerCase();
  final desc = (item.description ?? '').toLowerCase();
  return title.contains('18+') ||
      desc.contains('erotic') ||
      desc.contains('nudity');
}

/// `all` keeps everything. The other modes keep that content type, and anime
/// also keeps a series whose tags say it is anime.
bool matchesFeedMode(MultimediaItem item, String feedMode) {
  switch (feedMode) {
    case 'movies':
      return item.contentType == MultimediaContentType.movie;
    case 'series':
      return item.contentType == MultimediaContentType.series;
    case 'anime':
      return item.contentType == MultimediaContentType.anime ||
          _hasTag(item, 'anime');
    default:
      return true;
  }
}

/// Feed mode and the kids gate. Genre preference is a shelf, not a filter,
/// so a profile that likes sci-fi still sees the rest of home.
bool itemFitsProfile(MultimediaItem item, UserProfile profile) {
  if (profile.isKids && blockedForKids(item)) return false;
  return matchesFeedMode(item, profile.feedMode);
}

ShapedHome shapeHomeForProfile(
  Map<String, List<MultimediaItem>> sections,
  UserProfile? profile,
) {
  if (profile == null) {
    return ShapedHome(sections: sections, forYou: const []);
  }

  final shaped = <String, List<MultimediaItem>>{};
  for (final entry in sections.entries) {
    final kept = entry.value
        .where((item) => itemFitsProfile(item, profile))
        .toList();
    if (kept.isNotEmpty) shaped[entry.key] = kept;
  }

  return ShapedHome(
    sections: shaped,
    forYou: _forYou(shaped, profile.preferredGenres),
  );
}

List<MultimediaItem> _forYou(
  Map<String, List<MultimediaItem>> sections,
  List<String> genres,
) {
  if (genres.isEmpty) return const [];
  final matches = <MultimediaItem>[];
  final seen = <String>{};
  for (final items in sections.values) {
    for (final item in items) {
      if (!_matchesGenres(item, genres)) continue;
      final key = item.url.isNotEmpty
          ? item.url
          : item.title.trim().toLowerCase();
      if (seen.add(key)) matches.add(item);
    }
  }
  return matches;
}

bool _matchesGenres(MultimediaItem item, List<String> genres) {
  final tags = item.tags;
  if (tags == null || tags.isEmpty) return false;
  final normalized = tags.map((tag) => tag.toLowerCase()).toList();
  for (final genre in genres) {
    final wanted = genre.trim().toLowerCase();
    if (wanted.isEmpty) continue;
    for (final tag in normalized) {
      if (tag == wanted || tag.contains(wanted)) return true;
    }
  }
  return false;
}

bool _hasTag(MultimediaItem item, String tag) {
  final tags = item.tags;
  if (tags == null) return false;
  final wanted = tag.toLowerCase();
  return tags.any((entry) => entry.toLowerCase() == wanted);
}
