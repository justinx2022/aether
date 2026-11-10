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

final globalCatalogueProvider =
    FutureProvider<Map<String, List<MultimediaItem>>>((ref) async {
  final service = ref.watch(recommendationsServiceProvider);
  return service.getGlobalCatalogue();
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
    if (_cache.containsKey(cacheKey) && _cache[cacheKey]!.isNotEmpty) {
      return _cache[cacheKey]!;
    }

    try {
      final isSeries = item.contentType == MultimediaContentType.series;
      var type = isSeries ? 'series' : 'movie';
      String? targetImdb = item.imdbId;

      // 2. Resolve IMDb ID if missing
      if (targetImdb == null || !targetImdb.startsWith('tt')) {
        Future<String?> searchImdb(String searchType) async {
          final searchUrl =
              '$cinemetaUrl/catalog/$searchType/top/search=${Uri.encodeComponent(item.title)}.json';
          final searchResp = await _dio.get<dynamic>(
            searchUrl,
            options: Options(receiveTimeout: const Duration(seconds: 8)),
          );
          if (searchResp.data is Map && searchResp.data['metas'] is List) {
            final metas = searchResp.data['metas'] as List;
            if (metas.isNotEmpty && metas.first is Map) {
              return (metas.first['imdb_id'] ?? metas.first['id']) as String?;
            }
          }
          return null;
        }

        targetImdb = await searchImdb(type);
        if (targetImdb == null) {
          // Try opposite type
          final altType = isSeries ? 'movie' : 'series';
          targetImdb = await searchImdb(altType);
          if (targetImdb != null) {
            type = altType;
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
              contentType: type == 'series'
                  ? MultimediaContentType.series
                  : MultimediaContentType.movie,
              imdbId: id.startsWith('tt') ? id : null,
              provider: 'cinemeta',
            ),
          );

          if (results.length >= 20) break;
        }
      }

      // 5. Fallback: If genre query had no results, pull top items in category
      if (results.isEmpty) {
        final fallback = await getCatalog(type: type);
        for (final f in fallback) {
          if (f.title.toLowerCase() != item.title.toLowerCase()) {
            results.add(f);
          }
          if (results.length >= 15) break;
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

  Future<List<MultimediaItem>> getCatalog({
    required String type,
    String? genre,
    String? search,
  }) async {
    final cacheKey = 'cat_${type}_${genre ?? ""}_${search ?? ""}';
    if (_cache.containsKey(cacheKey) && _cache[cacheKey]!.isNotEmpty) {
      return _cache[cacheKey]!;
    }

    try {
      String url;
      if (search != null && search.isNotEmpty) {
        url = '$cinemetaUrl/catalog/$type/top/search=${Uri.encodeComponent(search)}.json';
      } else if (genre != null && genre.isNotEmpty) {
        url = '$cinemetaUrl/catalog/$type/top/genre=${Uri.encodeComponent(genre)}.json';
      } else {
        url = '$cinemetaUrl/catalog/$type/top.json';
      }

      final resp = await _dio.get<dynamic>(
        url,
        options: Options(receiveTimeout: const Duration(seconds: 10)),
      );

      final results = <MultimediaItem>[];
      if (resp.data is Map && resp.data['metas'] is List) {
        final list = resp.data['metas'] as List;
        final isSeries = type == 'series';
        for (final entry in list) {
          if (entry is! Map) continue;
          final name = entry['name'] as String? ?? '';
          final id = (entry['imdb_id'] ?? entry['id']) as String? ?? '';
          if (name.isEmpty) continue;

          final poster = entry['poster'] as String? ?? '';
          final banner = entry['background'] as String?;
          final desc = entry['description'] as String?;
          final year = entry['year'] as String? ?? entry['releaseInfo'] as String?;

          final parsedYear = int.tryParse(year?.split('-').first ?? '');
          results.add(
            MultimediaItem(
              title: name,
              url: jsonEncode({
                'id': id,
                'imdbId': id,
                'type': isSeries ? 'series' : 'movie',
                'title': name,
                'year': parsedYear,
              }),
              posterUrl: poster,
              bannerUrl: banner,
              description: desc,
              year: parsedYear,
              contentType: isSeries
                  ? MultimediaContentType.series
                  : MultimediaContentType.movie,
              imdbId: id.startsWith('tt') ? id : null,
              provider: 'dev.justin.catalogue',
            ),
          );
          if (results.length >= 25) break;
        }
      }
      _cache[cacheKey] = results;
      return results;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[RecommendationsService] Failed to load catalog: $e');
      }
      return const [];
    }
  }

  Future<List<MultimediaItem>> searchCatalog(String query) async {
    final movieResults = await getCatalog(type: 'movie', search: query);
    final seriesResults = await getCatalog(type: 'series', search: query);
    return [...movieResults, ...seriesResults];
  }

  Future<MultimediaItem?> getCinemetaDetails(
    String imdbId, {
    bool isSeries = false,
  }) async {
    final cleanId = imdbId.startsWith('tt') ? imdbId : 'tt$imdbId';
    final cacheKey = 'meta_${cleanId}_$isSeries';
    if (_cache.containsKey(cacheKey) && _cache[cacheKey]!.isNotEmpty) {
      return _cache[cacheKey]!.first;
    }

    Future<Map<String, dynamic>?> fetchMeta(String type) async {
      try {
        final url = '$cinemetaUrl/meta/$type/$cleanId.json';
        final resp = await _dio.get<dynamic>(
          url,
          options: Options(receiveTimeout: const Duration(seconds: 8)),
        );
        if (resp.data is Map && resp.data['meta'] is Map) {
          return Map<String, dynamic>.from(resp.data['meta'] as Map);
        }
      } catch (_) {}
      return null;
    }

    var meta = await fetchMeta(isSeries ? 'series' : 'movie');
    var detectedSeries = isSeries;
    if (meta == null) {
      meta = await fetchMeta(isSeries ? 'movie' : 'series');
      if (meta != null) {
        detectedSeries = !isSeries;
      }
    }

    if (meta == null) return null;

    final name = meta['name'] as String? ?? '';
    final desc = meta['description'] as String?;
    final poster = meta['poster'] as String? ?? '';
    final background = meta['background'] as String?;
    final yearStr = meta['year'] as String? ?? meta['releaseInfo'] as String?;
    final year = int.tryParse(yearStr?.split('-').first ?? '');
    final rating = double.tryParse(meta['imdbRating']?.toString() ?? '');

    // Parse genres
    final rawGenres = meta['genres'] ?? meta['genre'];
    final genres = rawGenres is List
        ? rawGenres.map((g) => g.toString()).toList()
        : <String>[];

    // Parse cast
    final rawCast = meta['cast'];
    final castList = <Actor>[];
    if (rawCast is List) {
      for (final c in rawCast) {
        if (c is String && c.isNotEmpty) {
          castList.add(Actor(name: c));
        }
      }
    }

    // Parse trailers
    final rawTrailers = meta['trailers'] ?? meta['trailerStreams'];
    final trailersList = <Trailer>[];
    if (rawTrailers is List) {
      for (final t in rawTrailers) {
        if (t is Map) {
          final src = (t['source'] ?? t['ytId']) as String?;
          if (src != null && src.isNotEmpty) {
            trailersList.add(Trailer(
              url: 'https://www.youtube.com/watch?v=$src',
            ));
          }
        }
      }
    }

    // Parse episodes
    final episodesList = <Episode>[];
    final videos = meta['videos'];
    final dynamic moviedbId = meta['moviedb_id'];
    if (videos is List && videos.isNotEmpty) {
      for (final v in videos) {
        if (v is! Map) continue;
        final int s = (v['season'] as num?)?.toInt() ?? 1;
        final int ep = ((v['number'] ?? v['episode']) as num?)?.toInt() ?? 1;
        final epName = v['name'] as String? ?? v['title'] as String? ?? 'Episode $ep';
        final epThumb = v['thumbnail'] as String?;
        final epDesc = v['overview'] as String? ?? v['description'] as String?;

        episodesList.add(
          Episode(
            name: epName,
            season: s,
            episode: ep,
            url: jsonEncode({
              'imdbId': cleanId,
              if (moviedbId != null) 'tmdbId': moviedbId,
              'type': 'series',
              'season': s,
              'episode': ep,
              'title': name,
              'epTitle': epName,
            }),
            posterUrl: epThumb ?? poster,
            description: epDesc,
          ),
        );
      }
    }

    if (episodesList.isEmpty) {
      episodesList.add(
        Episode(
          name: name,
          season: 1,
          episode: 1,
          url: jsonEncode({
            'imdbId': cleanId,
            if (moviedbId != null) 'tmdbId': moviedbId,
            'type': detectedSeries ? 'series' : 'movie',
            'season': 1,
            'episode': 1,
            'title': name,
          }),
          posterUrl: poster,
        ),
      );
    }

    final item = MultimediaItem(
      title: name,
      url: jsonEncode({
        'id': cleanId,
        'imdbId': cleanId,
        if (moviedbId != null) 'tmdbId': moviedbId,
        'type': detectedSeries ? 'series' : 'movie',
        'title': name,
        'year': year,
      }),
      description: desc,
      posterUrl: poster,
      bannerUrl: background,
      year: year,
      score: rating,
      tags: genres,
      cast: castList,
      trailers: trailersList,
      episodes: episodesList,
      contentType: detectedSeries
          ? MultimediaContentType.series
          : MultimediaContentType.movie,
      imdbId: cleanId,
      provider: 'dev.justin.catalogue',
    );

    _cache[cacheKey] = [item];
    return item;
  }

  Future<List<MultimediaItem>> getCuratedItems(
    List<String> imdbIds, {
    bool isSeries = true,
  }) async {
    final list = <MultimediaItem>[];
    for (final id in imdbIds) {
      try {
        final item = await getCinemetaDetails(id, isSeries: isSeries);
        if (item != null) list.add(item);
      } catch (_) {}
    }
    return list;
  }

  Future<Map<String, List<MultimediaItem>>> getGlobalCatalogue() async {
    final results = <String, List<MultimediaItem>>{};

    final trendingMovies = await getCatalog(type: 'movie');
    if (trendingMovies.isNotEmpty) results['Trending Movies'] = trendingMovies;

    final trendingSeries = await getCatalog(type: 'series');
    if (trendingSeries.isNotEmpty) results['Trending Series'] = trendingSeries;

    // International: Turkish Dizis & Crime Hits (including Çember, Kuruluş Osman, Yargı, Çukur, etc.)
    final turkishCurated = await getCuratedItems([
      'tt7130992', // Çember
      'tt10633870', // Kuruluş: Osman
      'tt15291778', // Yargı
      'tt7394206', // Çukur
      'tt4320258', // Diriliş: Ertuğrul
      'tt5189670', // Kara Sevda
      'tt6061986', // İçerde
      'tt7920978', // Şahsiyet
      'tt1570110', // Ezel
      'tt22941584', // Kızılcık Şerbeti
      'tt21908044', // Yalı Çapkını
      'tt13788240', // Teşkilat
    ], isSeries: true);
    final turkishSearch = await getCatalog(type: 'series', search: 'Turkish');
    final turkishCombined = [
      ...turkishCurated,
      ...turkishSearch.where((s) => !turkishCurated.any((c) => c.title.toLowerCase() == s.title.toLowerCase())),
    ];
    if (turkishCombined.isNotEmpty) results['Turkish Dizis & Dramas'] = turkishCombined;

    // International: Arabic Spotlight (Al Hayba, Bab Al Hara, etc.)
    final arabicCurated = await getCuratedItems([
      'tt7065982', // Al Hayba
      'tt5889700', // Bab Al-Hara
      'tt10408544', // Paranormal
      'tt25432022', // Al Thaman
      'tt13854746', // Rashash
      'tt14300300', // Finding Ola
    ], isSeries: true);
    final arabicSearch = await getCatalog(type: 'series', search: 'Al Hayba');
    final arabicCombined = [
      ...arabicCurated,
      ...arabicSearch.where((s) => !arabicCurated.any((c) => c.title.toLowerCase() == s.title.toLowerCase())),
    ];
    if (arabicCombined.isNotEmpty) results['Arabic Spotlight (Al Hayba & More)'] = arabicCombined;

    // International: Telenovelas & Latino Series
    final telenovelaCurated = await getCuratedItems([
      'tt14442116', // Café con aroma de mujer
      'tt1814674', // La Reina del Sur
      'tt0384752', // Pasión de Gavilanes
      'tt8963500', // El Dragón
      'tt6468322', // La Casa de Papel
      'tt15174542', // Pálpito
    ], isSeries: true);
    final telenovelas = await getCatalog(type: 'series', genre: 'Soap');
    final telenovelaCombined = [
      ...telenovelaCurated,
      ...telenovelas.where((s) => !telenovelaCurated.any((c) => c.title.toLowerCase() == s.title.toLowerCase())),
    ];
    if (telenovelaCombined.isNotEmpty) results['Telenovelas & Latino Series'] = telenovelaCombined;

    // Action & Adventure
    final action = await getCatalog(type: 'movie', genre: 'Action');
    if (action.isNotEmpty) results['Action & Adventure'] = action;

    // Sci-Fi & Fantasy
    final scifi = await getCatalog(type: 'movie', genre: 'Sci-Fi');
    if (scifi.isNotEmpty) results['Sci-Fi & Fantasy'] = scifi;

    // Animation & Anime Hits
    final animation = await getCatalog(type: 'series', genre: 'Animation');
    if (animation.isNotEmpty) results['Animation & Anime Hits'] = animation;

    // Comedy Nights
    final comedy = await getCatalog(type: 'series', genre: 'Comedy');
    if (comedy.isNotEmpty) results['Comedy Nights'] = comedy;

    return results;
  }
}
