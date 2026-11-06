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

/// Loads title-to-title recommendations from TMDB rather than substituting
/// popular titles in a broad genre.
class RecommendationsService {
  final Dio _dio;
  final Map<String, List<MultimediaItem>> _cache = {};

  RecommendationsService(Dio baseDio)
    : _dio = Dio(baseDio.options.copyWith(baseUrl: TmdbConfig.baseUrl)) {
    _dio.httpClientAdapter = baseDio.httpClientAdapter;
    _dio.interceptors.addAll(baseDio.interceptors);
  }

  Future<List<MultimediaItem>> getSimilarItems(MultimediaItem item) async {
    if (item.recommendations case final recommendations?
        when recommendations.isNotEmpty) {
      return recommendations;
    }
    if (TmdbConfig.apiKey.isEmpty) return const [];

    final cacheKey =
        '${item.tmdbId ?? item.imdbId ?? item.title}_${_tmdbType(item)}';
    final cached = _cache[cacheKey];
    if (cached != null) return cached;

    try {
      final id = await _resolveTmdbId(item);
      if (id == null) return const [];

      final type = _tmdbType(item);
      final response = await _dio.get<Map<String, dynamic>>(
        '/$type/$id/recommendations',
        queryParameters: {'api_key': TmdbConfig.apiKey, 'page': 1},
      );
      final rawResults = response.data?['results'];
      if (rawResults is! List) return const [];

      final results = <MultimediaItem>[];
      for (final raw in rawResults) {
        if (raw is! Map) continue;
        final json = Map<String, dynamic>.from(raw);
        json['media_type'] = type;
        final result = MultimediaItem.fromTmdbJson(json);
        if (result.tmdbId == null || result.title.trim().isEmpty) continue;
        if (result.tmdbId == item.tmdbId ||
            _normalizedTitle(result.title) == _normalizedTitle(item.title)) {
          continue;
        }
        results.add(
          result.copyWith(
            url: 'tmdb:$type:${result.tmdbId}',
            provider: 'tmdb',
            source: 'tmdb',
          ),
        );
        if (results.length == 20) break;
      }

      _cache[cacheKey] = results;
      return results;
    } catch (error) {
      if (kDebugMode) {
        debugPrint('[RecommendationsService] TMDB lookup failed: $error');
      }
      return const [];
    }
  }

  Future<int?> _resolveTmdbId(MultimediaItem item) async {
    if (item.tmdbId != null) return item.tmdbId;

    final type = _tmdbType(item);
    final imdbId = item.imdbId?.trim();
    if (imdbId != null && RegExp(r'^tt\d{6,}$').hasMatch(imdbId)) {
      final response = await _dio.get<Map<String, dynamic>>(
        '/find/${Uri.encodeComponent(imdbId)}',
        queryParameters: {
          'api_key': TmdbConfig.apiKey,
          'external_source': 'imdb_id',
        },
      );
      final matches = response.data?['${type}_results'];
      if (matches is List) {
        for (final match in matches) {
          if (match is Map && match['id'] is int) return match['id'] as int;
        }
      }
    }

    final response = await _dio.get<Map<String, dynamic>>(
      '/search/$type',
      queryParameters: {
        'api_key': TmdbConfig.apiKey,
        'query': item.title,
        if (item.year != null) 'year': item.year,
      },
    );
    final matches = response.data?['results'];
    if (matches is! List) return null;
    for (final match in matches) {
      if (match is! Map) continue;
      final title = (match['title'] ?? match['name'])?.toString() ?? '';
      if (_normalizedTitle(title) != _normalizedTitle(item.title)) continue;
      final date = (match['release_date'] ?? match['first_air_date'])
          ?.toString();
      final year = date == null || date.length < 4
          ? null
          : int.tryParse(date.substring(0, 4));
      if (item.year != null && year != null && item.year != year) continue;
      final id = match['id'];
      if (id is int) return id;
    }
    return null;
  }

  static String _tmdbType(MultimediaItem item) =>
      item.contentType == MultimediaContentType.series ||
          item.contentType == MultimediaContentType.anime
      ? 'tv'
      : 'movie';

  static String _normalizedTitle(String value) =>
      value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
}
