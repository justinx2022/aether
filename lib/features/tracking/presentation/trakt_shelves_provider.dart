import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/domain/entity/multimedia_item.dart';
import '../../../core/network/dio_client_provider.dart';
import '../../../core/recommendations/recommendations_service.dart';
import '../data/trakt_service.dart';

/// Turns a raw Trakt sync/recommendations entry (`{movie: ...}` or
/// `{show: ...}`) into a catalogue card in the exact token shape
/// [RecommendationsService] issues, so tapping a card opens playback
/// directly instead of falling into a title search.
MultimediaItem? traktEntryToItem(Map<String, dynamic> entry) {
  final media = entry['movie'] ?? entry['show'];
  if (media is! Map) return null;
  final mediaMap = Map<String, dynamic>.from(media);
  final ids = Map<String, dynamic>.from((mediaMap['ids'] as Map?) ?? const {});
  final title = (mediaMap['title'] ?? '') as String;
  if (title.isEmpty) return null;

  final isSeries = entry.containsKey('show');
  final type = isSeries ? 'series' : 'movie';
  final imdbId = ids['imdb'] as String?;
  final tmdbRaw = ids['tmdb'];
  final tmdbId = tmdbRaw is int ? tmdbRaw : int.tryParse('$tmdbRaw');
  final yearRaw = mediaMap['year'];
  final year = yearRaw is int ? yearRaw : int.tryParse('$yearRaw');

  final hasImdb = imdbId != null && imdbId.startsWith('tt');
  if (!hasImdb && tmdbId == null) return null;

  return MultimediaItem(
    title: title,
    url: RecommendationsService.catalogueToken(
      imdbId: hasImdb ? imdbId : 'tmdb:$tmdbId',
      type: type,
      title: title,
      year: year?.toString(),
    ),
    posterUrl: '',
    year: year,
    contentType: isSeries
        ? MultimediaContentType.series
        : MultimediaContentType.movie,
    imdbId: hasImdb ? imdbId : null,
    tmdbId: tmdbId,
    provider: RecommendationsService.catalogueProvider,
  );
}

/// Fills in posters, backdrops and descriptions Cinemeta-side; Trakt's sync
/// endpoints don't carry artwork. Best-effort: an item that fails enrichment
/// keeps its placeholder poster rather than dropping off the shelf.
Future<List<MultimediaItem>> _enrichArtwork(
  Dio dio,
  List<MultimediaItem> items,
) async {
  return Future.wait(items.map((item) async {
    final id = item.imdbId;
    if (id == null || !id.startsWith('tt')) return item;
    try {
      final type = item.contentType == MultimediaContentType.series
          ? 'series'
          : 'movie';
      final resp = await dio.get<dynamic>(
        'https://v3-cinemeta.strem.io/meta/$type/$id.json',
        options: Options(receiveTimeout: const Duration(seconds: 6)),
      );
      if (resp.data is! Map || resp.data['meta'] is! Map) return item;
      final meta = resp.data['meta'] as Map;
      final poster = meta['poster'] as String? ?? '';
      return MultimediaItem(
        title: item.title,
        url: item.url,
        posterUrl: poster.isNotEmpty ? poster : item.posterUrl,
        bannerUrl: meta['background'] as String? ?? item.bannerUrl,
        description:
            (meta['description'] as String?) ?? item.description,
        contentType: item.contentType,
        provider: item.provider,
        year: item.year,
        score: (meta['imdbRating'] as num?)?.toDouble() ?? item.score,
        imdbId: item.imdbId,
        tmdbId: item.tmdbId,
      );
    } catch (_) {
      return item;
    }
  }));
}

/// The user's Trakt watchlist as a home rail. Empty (and thus invisible)
/// when Trakt is not connected or the list is empty.
final traktWatchlistProvider = FutureProvider<List<MultimediaItem>>((ref) async {
  final service = ref.watch(traktServiceProvider);
  if (!await service.isLoggedIn) return const [];
  final entries = await service.fetchWatchlist();
  final items = entries
      .map(traktEntryToItem)
      .whereType<MultimediaItem>()
      .take(20)
      .toList();
  if (items.isEmpty) return const [];
  return _enrichArtwork(ref.watch(dioClientProvider), items);
});

/// Trakt's personalized recommendations — what its own "Recommended for
/// You" row serves, computed from the user's watch history, collection and
/// lists across all connected apps.
final traktRecommendationsProvider =
    FutureProvider<List<MultimediaItem>>((ref) async {
  final service = ref.watch(traktServiceProvider);
  if (!await service.isLoggedIn) return const [];
  final entries = await service.fetchRecommendations();
  final items = entries
      .map(traktEntryToItem)
      .whereType<MultimediaItem>()
      .take(20)
      .toList();
  if (items.isEmpty) return const [];
  return _enrichArtwork(ref.watch(dioClientProvider), items);
});

/// The user's Trakt watch history — everything scrobbled from any app,
/// newest first, deduped by title so one binged show doesn't fill the rail.
final traktHistoryProvider = FutureProvider<List<MultimediaItem>>((ref) async {
  final service = ref.watch(traktServiceProvider);
  if (!await service.isLoggedIn) return const [];
  final entries = await service.fetchHistory();
  final seen = <String>{};
  final items = <MultimediaItem>[];
  for (final entry in entries) {
    final item = traktEntryToItem(entry);
    if (item == null) continue;
    final key = item.title.trim().toLowerCase();
    if (!seen.add(key)) continue;
    items.add(item);
    if (items.length >= 20) break;
  }
  if (items.isEmpty) return const [];
  return _enrichArtwork(ref.watch(dioClientProvider), items);
});
