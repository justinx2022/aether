import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/tmdb_config.dart';
import '../domain/entity/multimedia_item.dart';
import '../network/dio_client_provider.dart';

final recommendationsServiceProvider = Provider<RecommendationsService>((ref) {
  final dio = ref.watch(dioClientProvider);
  return RecommendationsService(dio);
});

final similarItemsProvider =
    FutureProvider.family<List<MultimediaItem>, MultimediaItem>((
      ref,
      item,
    ) async {
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

    final cacheKey = '${item.imdbId ?? item.tmdbId ?? item.title}_${item.contentType.name}';
    if (_cache.containsKey(cacheKey)) {
      return _cache[cacheKey]!;
    }

    try {
      final isSeries = item.contentType == MultimediaContentType.series;
      final type = isSeries ? 'series' : 'movie';
      final tmdbType = isSeries ? 'tv' : 'movie';
      int? resolvedTmdb = item.tmdbId;
      String? targetImdb = item.imdbId ?? imdbFromCatalogueToken(item.url);

      // A. Primary High-Accuracy Recommendation Engine: TMDB
      if (resolvedTmdb == null && targetImdb != null && targetImdb.startsWith('tt')) {
        try {
          final findUrl = 'https://api.themoviedb.org/3/find/$targetImdb?api_key=${TmdbConfig.apiKey}&external_source=imdb_id';
          final findResp = await _dio.get<dynamic>(findUrl, options: Options(receiveTimeout: const Duration(seconds: 6)));
          if (findResp.data is Map) {
            final hits = (isSeries ? findResp.data['tv_results'] : findResp.data['movie_results']) as List?;
            if (hits != null && hits.isNotEmpty && hits.first is Map) {
              resolvedTmdb = hits.first['id'] as int?;
            }
          }
        } catch (_) {}
      }

      if (resolvedTmdb == null && item.title.isNotEmpty) {
        try {
          final sUrl = 'https://api.themoviedb.org/3/search/$tmdbType?api_key=${TmdbConfig.apiKey}&query=${Uri.encodeComponent(item.title)}';
          final sResp = await _dio.get<dynamic>(sUrl, options: Options(receiveTimeout: const Duration(seconds: 6)));
          if (sResp.data is Map && sResp.data['results'] is List) {
            final rList = sResp.data['results'] as List;
            if (rList.isNotEmpty && rList.first is Map) {
              resolvedTmdb = rList.first['id'] as int?;
            }
          }
        } catch (_) {}
      }

      if (resolvedTmdb != null) {
        final recsFuture = _dio.get<dynamic>(
          'https://api.themoviedb.org/3/$tmdbType/$resolvedTmdb/recommendations?api_key=${TmdbConfig.apiKey}&language=en-US',
          options: Options(receiveTimeout: const Duration(seconds: 8)),
        );
        final simFuture = _dio.get<dynamic>(
          'https://api.themoviedb.org/3/$tmdbType/$resolvedTmdb/similar?api_key=${TmdbConfig.apiKey}&language=en-US',
          options: Options(receiveTimeout: const Duration(seconds: 8)),
        );

        final responses = await Future.wait([
          recsFuture.catchError((_) => Response<dynamic>(requestOptions: RequestOptions(), statusCode: 500)),
          simFuture.catchError((_) => Response<dynamic>(requestOptions: RequestOptions(), statusCode: 500)),
        ]);

        final candidateList = <Map<String, dynamic>>[];
        for (final resp in responses) {
          if (resp.statusCode == 200 && resp.data is Map && resp.data['results'] is List) {
            for (final entry in (resp.data['results'] as List)) {
              if (entry is Map<String, dynamic>) {
                candidateList.add(entry);
              } else if (entry is Map) {
                candidateList.add(Map<String, dynamic>.from(entry));
              }
            }
          }
        }

        if (candidateList.isNotEmpty) {
          final seenIds = <int>{resolvedTmdb};
          final tmdbResults = <MultimediaItem>[];

          for (final hit in candidateList) {
            final id = hit['id'] as int?;
            if (id == null || seenIds.contains(id)) continue;
            seenIds.add(id);

            final hitTitle = (hit['title'] ?? hit['name'] ?? '') as String;
            if (hitTitle.isEmpty) continue;
            final posterPath = hit['poster_path'] as String?;
            final backdropPath = hit['backdrop_path'] as String?;
            final dateStr = (hit['release_date'] ?? hit['first_air_date'] ?? '') as String;
            final hitYear = int.tryParse(dateStr.split('-').first);
            final overview = hit['overview'] as String?;
            final rating = (hit['vote_average'] as num?)?.toDouble();

            tmdbResults.add(
              MultimediaItem(
                title: hitTitle,
                url: catalogueToken(
                  imdbId: 'tmdb:$id',
                  type: type,
                  title: hitTitle,
                  year: hitYear?.toString(),
                ),
                posterUrl: posterPath != null ? '${TmdbConfig.imageBaseUrl}$posterPath' : '',
                bannerUrl: backdropPath != null ? '${TmdbConfig.imageBaseUrl}$backdropPath' : null,
                description: overview,
                year: hitYear,
                score: rating,
                contentType: isSeries ? MultimediaContentType.series : MultimediaContentType.movie,
                tmdbId: id,
                provider: catalogueProvider,
              ),
            );

            if (tmdbResults.length >= 24) break;
          }

          if (tmdbResults.isNotEmpty) {
            _cache[cacheKey] = tmdbResults;
            return tmdbResults;
          }
        }
      }

      // B. Secondary Fallback: Cinemeta
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
            targetImdb =
                (metas.first['imdb_id'] ?? metas.first['id']) as String?;
          }
        }
      }

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
          final rawId = entry['imdb_id'] ?? entry['id'];
          final id = rawId?.toString() ?? '';
          if (name.isEmpty || id.isEmpty) continue;

          if (name.toLowerCase() == item.title.toLowerCase() ||
              (targetImdb != null && id == targetImdb)) {
            continue;
          }

          if (!id.startsWith('tt')) continue;

          final poster = entry['poster'] as String? ?? '';
          final banner = entry['background'] as String?;
          final desc = entry['description'] as String?;
          final yearRaw = entry['year'] ?? entry['releaseInfo'];
          final year = yearRaw?.toString();

          results.add(
            MultimediaItem(
              title: name,
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
