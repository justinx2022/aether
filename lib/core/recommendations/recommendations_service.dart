import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/entity/multimedia_item.dart';
import '../network/dio_client_provider.dart';

final recommendationsServiceProvider = Provider<RecommendationsService>((ref) {
  final dio = ref.watch(dioClientProvider);
  return RecommendationsService(dio);
});

final similarItemsProvider =
    FutureProvider.family<List<MultimediaItem>, MultimediaItem>((ref, item) async {
  final service = ref.watch(recommendationsServiceProvider);
  return service.getSimilarItems(item);
});

class RecommendationsService {
  final Dio _dio;
  static const String cinemetaUrl = 'https://v3-cinemeta.strem.io';
  final Map<String, List<MultimediaItem>> _cache = {};

  RecommendationsService(this._dio);

  /// The catalogue that owns playback for these cards.
  ///
  /// Every recommendation is discovered through Cinemeta, so it has to be
  /// handed to the plugin that is built on the same ids and knows how to turn
  /// them into direct HLS links. That is Justin's Catalogue, not the generic
  /// add-on stack: the viewer taps a poster and the stream opens, with no
  /// source list to choose from.
  static const String catalogueProvider = 'dev.justin.catalogue';

  /// A row in the catalogue's own shape.
  ///
  /// `dev.justin.catalogue` parses this token in `loadStreams` and resolves the
  /// IMDb id, type, title and year from it. A card built from a bare id or a
  /// `cinemeta:` pseudo-URL is a token it never issued, which is what surfaced
  /// as "Title not found" when a recommendation was pressed.
  static String catalogueToken({
    required String imdbId,
    required String type,
    required String title,
    String? year,
  }) => jsonEncode({
    'id': imdbId,
    'type': type,
    'title': title,
    if (year != null && year.isNotEmpty) 'year': year,
  });

  /// The IMDb id inside an existing catalogue row, if [url] is one.
  ///
  /// History and bookmarks saved from the catalogue carry the same JSON token,
  /// so this avoids a title search when a shelf is built from them.
  static String? imdbFromCatalogueToken(String url) {
    try {
      final parsed = jsonDecode(url);
      if (parsed is Map) {
        final id = parsed['id'] ?? parsed['imdbId'];
        if (id is String && id.startsWith('tt')) return id;
      }
    } catch (_) {}
    return null;
  }

  Future<List<MultimediaItem>> getSimilarItems(MultimediaItem item) async {
    // 1. If item already has recommendations embedded, use them directly
    if (item.recommendations != null && item.recommendations!.isNotEmpty) {
      return item.recommendations!;
    }

    final cacheKey = '${item.imdbId ?? item.title}_${item.contentType.name}';
    if (_cache.containsKey(cacheKey)) {
      return _cache[cacheKey]!;
    }

    try {
      final isSeries = item.contentType == MultimediaContentType.series;
      final type = isSeries ? 'series' : 'movie';
      String? targetImdb = item.imdbId ?? imdbFromCatalogueToken(item.url);

      // 2. Resolve IMDb ID if missing
      if (targetImdb == null || !targetImdb.startsWith('tt')) {
        final searchUrl =
            '$cinemetaUrl/catalog/$type/top/search=${Uri.encodeComponent(item.title)}.json';
        final searchResp = await _dio.get<dynamic>(
          searchUrl,
          options: Options(receiveTimeout: const Duration(seconds: 8)),
        );
        if (searchResp.data is Map && searchResp.data['metas'] is List) {
          final metas = searchResp.data['metas'] as List;
          if (metas.isNotEmpty && metas.first is Map) {
            targetImdb = (metas.first['imdb_id'] ?? metas.first['id']) as String?;
          }
        }
      }

      // 3. Extract primary genre from meta
      String primaryGenre = isSeries ? 'Drama' : 'Action';
      if (targetImdb != null && targetImdb.startsWith('tt')) {
        final metaUrl = '$cinemetaUrl/meta/$type/$targetImdb.json';
        final metaResp = await _dio.get<dynamic>(
          metaUrl,
          options: Options(receiveTimeout: const Duration(seconds: 8)),
        );
        if (metaResp.data is Map && metaResp.data['meta'] is Map) {
          final meta = metaResp.data['meta'] as Map;
          final genres = meta['genres'] ?? meta['genre'];
          if (genres is List && genres.isNotEmpty) {
            primaryGenre = genres.first.toString();
          }
        }
      }

      // 4. Query top titles in the discovered genre
      final catalogUrl =
          '$cinemetaUrl/catalog/$type/top/genre=${Uri.encodeComponent(primaryGenre)}.json';
      final catResp = await _dio.get<dynamic>(
        catalogUrl,
        options: Options(receiveTimeout: const Duration(seconds: 10)),
      );

      final results = <MultimediaItem>[];
      if (catResp.data is Map && catResp.data['metas'] is List) {
        final list = catResp.data['metas'] as List;
        for (final entry in list) {
          if (entry is! Map) continue;
          final name = entry['name'] as String? ?? '';
          final id = (entry['imdb_id'] ?? entry['id']) as String? ?? '';
          if (name.isEmpty) continue;

          // Exclude the source item itself
          if (name.toLowerCase() == item.title.toLowerCase() ||
              (targetImdb != null && id == targetImdb)) {
            continue;
          }

          // A Cinemeta catalogue only ever yields IMDb ids, so a card without
          // one has no row in the catalogue and nothing to play.
          if (!id.startsWith('tt')) continue;

          final poster = entry['poster'] as String? ?? '';
          final banner = entry['background'] as String?;
          final desc = entry['description'] as String?;
          final year = entry['year'] as String? ?? entry['releaseInfo'] as String?;

          results.add(
            MultimediaItem(
              title: name,
              // Same token a home/search row from `dev.justin.catalogue`
              // carries, so `loadStreams` resolves it straight to the
              // catalogue's direct HLS links.
              url: catalogueToken(
                imdbId: id,
                type: type,
                title: name,
                year: year,
              ),
              posterUrl: poster,
              bannerUrl: banner,
              description: desc,
              year: int.tryParse(year?.split('-').first ?? ''),
              contentType: isSeries
                  ? MultimediaContentType.series
                  : MultimediaContentType.movie,
              imdbId: id,
              provider: catalogueProvider,
            ),
          );

          if (results.length >= 20) break;
        }
      }

      _cache[cacheKey] = results;
      return results;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[RecommendationsService] Failed to load similar items: $e');
      }
      return const [];
    }
  }
}
