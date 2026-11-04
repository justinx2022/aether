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
      String? targetImdb = item.imdbId;

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

          final poster = entry['poster'] as String? ?? '';
          final banner = entry['background'] as String?;
          final desc = entry['description'] as String?;
          final year = entry['year'] as String? ?? entry['releaseInfo'] as String?;

            results.add(
              MultimediaItem(
                title: name,
                url: 'cinemeta:$id',
                posterUrl: poster,
                bannerUrl: banner,
                description: desc,
                year: int.tryParse(year?.split('-').first ?? ''),
                contentType: isSeries
                    ? MultimediaContentType.series
                    : MultimediaContentType.movie,
                imdbId: id.startsWith('tt') ? id : null,
                provider: 'cinemeta',
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
