import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show WidgetsBinding;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/library/presentation/history_provider.dart';
import '../../features/library/presentation/library_provider.dart';
import '../../features/library/presentation/library_state.dart';
import '../../l10n/generated/app_localizations.dart';
import '../config/sync_config.dart';
import '../config/tmdb_config.dart';
import '../domain/entity/multimedia_item.dart';
import '../network/dio_client_provider.dart';
import '../storage/storage_service.dart';

/// Semantic classification for a multi-source discovery shelf on Home.
enum DiscoveryShelfKind {
  top10World,
  top10Kenya,
  top10Local,
  pickedForYou,
  trendingSeries,
  africanSpotlight,
  criticallyAcclaimed,
  hiddenGems,
  popularMovies,
}

/// A single horizontally scrollable recommendation shelf produced by
/// [DiscoveryEngine].
class DiscoveryShelf {
  final DiscoveryShelfKind kind;
  final String id;
  final String? countryName;
  final bool ranked;
  final List<MultimediaItem> items;

  const DiscoveryShelf({
    required this.kind,
    required this.id,
    required this.items,
    this.countryName,
    this.ranked = false,
  });

  /// Returns the localized UI heading for this shelf without hardcoding copy.
  String localizedTitle(AppLocalizations l10n) {
    return switch (kind) {
      DiscoveryShelfKind.top10World => l10n.discoverTop10World,
      DiscoveryShelfKind.top10Kenya => l10n.discoverTop10Kenya,
      DiscoveryShelfKind.top10Local =>
        l10n.discoverTop10Local(countryName ?? 'Kenya'),
      DiscoveryShelfKind.pickedForYou => l10n.discoverFreshForYou,
      DiscoveryShelfKind.trendingSeries => l10n.discoverTrendingSeries,
      DiscoveryShelfKind.africanSpotlight => l10n.discoverAfricanSpotlight,
      DiscoveryShelfKind.criticallyAcclaimed =>
        l10n.discoverCriticallyAcclaimed,
      DiscoveryShelfKind.hiddenGems => l10n.discoverHiddenGems,
      DiscoveryShelfKind.popularMovies => l10n.discoverPopularToday,
    };
  }
}

/// Detected regional context used for "Top 10 in `<Country>` Today" charts.
class CountryContext {
  final String code;
  final String name;

  const CountryContext({required this.code, required this.name});

  static const CountryContext kenya = CountryContext(code: 'KE', name: 'Kenya');
}

/// User taste vector distilled from local watch history + library bookmarks.
class TasteProfile {
  final List<MultimediaItem> seedItems;
  final Set<String> excludeKeys;
  final List<int> topTmdbGenreIds;
  final List<String> topCinemetaGenres;
  final double seriesAffinity;

  const TasteProfile({
    required this.seedItems,
    required this.excludeKeys,
    required this.topTmdbGenreIds,
    required this.topCinemetaGenres,
    required this.seriesAffinity,
  });

  static const List<String> _defaultMovieGenres = <String>[
    'Action',
    'Sci-Fi',
    'Thriller',
    'Mystery',
    'Drama',
    'Adventure',
    'Crime',
    'Comedy',
    'Animation',
    'Fantasy',
  ];

  static const Map<String, int> _tagToTmdbGenre = <String, int>{
    'action': 28,
    'adventure': 12,
    'animation': 16,
    'anime': 16,
    'comedy': 35,
    'crime': 80,
    'documentary': 99,
    'drama': 18,
    'family': 10751,
    'fantasy': 14,
    'history': 36,
    'horror': 27,
    'mystery': 9648,
    'romance': 10749,
    'sci-fi': 878,
    'science fiction': 878,
    'thriller': 53,
    'war': 10752,
    'western': 37,
  };

  static const Map<String, String> _tagToCinemetaGenre = <String, String>{
    'action': 'Action',
    'adventure': 'Adventure',
    'animation': 'Animation',
    'anime': 'Animation',
    'comedy': 'Comedy',
    'crime': 'Crime',
    'documentary': 'Documentary',
    'drama': 'Drama',
    'family': 'Family',
    'fantasy': 'Fantasy',
    'history': 'History',
    'horror': 'Horror',
    'mystery': 'Mystery',
    'romance': 'Romance',
    'sci-fi': 'Sci-Fi',
    'science fiction': 'Sci-Fi',
    'thriller': 'Thriller',
    'war': 'War',
  };

  /// Derives a diverse, non-repetitive taste profile without requiring setup.
  static TasteProfile build({
    required List<HistoryItem> history,
    required List<MultimediaItem> library,
    DateTime? now,
  }) {
    final exclude = <String>{};
    final seeds = <MultimediaItem>[];
    final seenSeeds = <String>{};
    final tmdbScores = <int, double>{};
    final cinemetaScores = <String, double>{};
    int seriesCount = 0;
    int totalCount = 0;

    void absorbItem(MultimediaItem item, {required double weight}) {
      totalCount++;
      if (item.contentType == MultimediaContentType.series ||
          item.contentType == MultimediaContentType.anime) {
        seriesCount++;
      }
      final key = DiscoveryEngine.canonicalKey(item);
      if (key.isNotEmpty && seenSeeds.add(key) && seeds.length < 6) {
        seeds.add(item);
      }

      final tags = item.tags ?? const <String>[];
      for (final raw in tags) {
        final norm = raw.trim().toLowerCase();
        final tmdbId = _tagToTmdbGenre[norm];
        if (tmdbId != null) {
          tmdbScores[tmdbId] = (tmdbScores[tmdbId] ?? 0) + weight;
        }
        final cm = _tagToCinemetaGenre[norm];
        if (cm != null) {
          cinemetaScores[cm] = (cinemetaScores[cm] ?? 0) + weight;
        }
      }

      // Soft lexical hints from description when tags haven't been hydrated yet.
      final text = '${item.title} ${item.description ?? ''}'.toLowerCase();
      if (tags.isEmpty && text.trim().isNotEmpty) {
        if (text.contains('space') ||
            text.contains('future') ||
            text.contains('cyber') ||
            text.contains('alien')) {
          tmdbScores[878] = (tmdbScores[878] ?? 0) + weight * 0.5;
          cinemetaScores['Sci-Fi'] =
              (cinemetaScores['Sci-Fi'] ?? 0) + weight * 0.5;
        }
        if (text.contains('murder') ||
            text.contains('detective') ||
            text.contains('crime') ||
            text.contains('cartel')) {
          tmdbScores[80] = (tmdbScores[80] ?? 0) + weight * 0.5;
          cinemetaScores['Crime'] =
              (cinemetaScores['Crime'] ?? 0) + weight * 0.5;
        }
      }
    }

    for (var i = 0; i < history.length; i++) {
      final entry = history[i];
      final recencyWeight = math.max(0.4, 2.0 - i * 0.15);
      absorbItem(entry.item, weight: recencyWeight);
      if (entry.progress >= 0.85 || i < 4) {
        final k = DiscoveryEngine.canonicalKey(entry.item);
        if (k.isNotEmpty) exclude.add(k);
      }
    }

    for (final fav in library) {
      absorbItem(fav, weight: 1.4);
      final k = DiscoveryEngine.canonicalKey(fav);
      if (k.isNotEmpty) exclude.add(k);
    }

    final sortedTmdb = tmdbScores.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final topTmdb = sortedTmdb.map((e) => e.key).take(3).toList();

    final sortedCm = cinemetaScores.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final clock = now ?? DateTime.now();
    final daySalt = clock.year * 366 + clock.month * 31 + clock.day;
    final pickedCm = sortedCm.map((e) => e.key).take(3).toList();
    // Rotate fallback discovery genres by date so cold starts stay varied.
    final fallbackShift = daySalt % _defaultMovieGenres.length;
    for (var i = 0; pickedCm.length < 3 && i < _defaultMovieGenres.length; i++) {
      final candidate =
          _defaultMovieGenres[(fallbackShift + i * 3) %
              _defaultMovieGenres.length];
      if (!pickedCm.contains(candidate)) {
        pickedCm.add(candidate);
      }
    }

    return TasteProfile(
      seedItems: seeds,
      excludeKeys: exclude,
      topTmdbGenreIds: topTmdb,
      topCinemetaGenres: pickedCm,
      seriesAffinity: totalCount == 0 ? 0.35 : seriesCount / totalCount,
    );
  }
}

/// Multi-signal recommendation engine combining TMDB, Trakt public/background
/// endpoints, Apple iTunes regional charts, and Cinemeta catalogs with
/// zero mandatory user configuration.
class DiscoveryEngine {
  static const String _cinemetaBase = 'https://v3-cinemeta.strem.io';
  static const String _traktBase = 'https://api.trakt.tv';
  static const String _metahubPoster = 'https://images.metahub.space/poster/medium';
  static const String _metahubBg = 'https://images.metahub.space/background/medium';
  static const String _countryCacheKey = 'discovery_country_ctx_v1';
  static const Duration _countryCacheTtl = Duration(hours: 24);
  static const Duration _remoteTimeout = Duration(seconds: 7);

  static const Map<String, String> _countryNames = <String, String>{
    'KE': 'Kenya',
    'UG': 'Uganda',
    'TZ': 'Tanzania',
    'NG': 'Nigeria',
    'ZA': 'South Africa',
    'GH': 'Ghana',
    'US': 'United States',
    'GB': 'United Kingdom',
    'CA': 'Canada',
    'IN': 'India',
    'AU': 'Australia',
    'DE': 'Germany',
    'FR': 'France',
    'JP': 'Japan',
    'KR': 'South Korea',
    'BR': 'Brazil',
    'AE': 'UAE',
  };

  final Dio _dio;
  final StorageService? _storage;
  final String _tmdbKey;
  final String _traktClientId;
  final DateTime Function() _now;

  DiscoveryEngine({
    required Dio dio,
    StorageService? storage,
    String? tmdbApiKey,
    String? traktClientId,
    DateTime Function()? now,
  }) : _dio = dio,
       _storage = storage,
       _tmdbKey = (tmdbApiKey ?? TmdbConfig.apiKey).trim(),
       _traktClientId = (traktClientId ?? SyncConfig.traktClientId).trim(),
       _now = now ?? DateTime.now;

  /// Canonical cross-provider deduplication key (`imdbId`, `tmdbId`, or
  /// normalized title + year).
  static String canonicalKey(MultimediaItem item) {
    final imdb = item.imdbId?.trim().toLowerCase();
    if (imdb != null && imdb.isNotEmpty) return 'imdb:$imdb';
    if (item.tmdbId != null && item.tmdbId! > 0) {
      return 'tmdb:${item.tmdbId}';
    }
    final cleanTitle = item.title
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]'), '');
    if (cleanTitle.isEmpty) return '';
    return 'title:$cleanTitle';
  }

  /// Auto-detects the viewer's country seamlessly from cached IP geolocation or
  /// device locale, defaulting safely offline without any setup flow.
  Future<CountryContext?> detectCountry() async {
    try {
      final cachedRaw = _storage?.getString(_countryCacheKey);
      if (cachedRaw != null && cachedRaw.isNotEmpty) {
        final decoded = jsonDecode(cachedRaw);
        if (decoded is Map<String, dynamic>) {
          final ts = (decoded['ts'] as num?)?.toInt() ?? 0;
          final ageMs = _now().millisecondsSinceEpoch - ts;
          if (ageMs >= 0 && ageMs < _countryCacheTtl.inMilliseconds) {
            final code = (decoded['code'] as String?)?.toUpperCase() ?? '';
            final name = decoded['name'] as String? ?? '';
            if (code.length == 2 && name.isNotEmpty) {
              return CountryContext(code: code, name: name);
            }
          }
        }
      }
    } catch (_) {}

    try {
      final resp = await _dio
          .get<dynamic>('https://ipwho.is/?fields=success,country,country_code')
          .timeout(const Duration(seconds: 3));
      final data = resp.data;
      if (data is Map) {
        final ok = data['success'] != false;
        final code = (data['country_code'] as String?)?.trim().toUpperCase();
        final name = (data['country'] as String?)?.trim();
        if (ok &&
            code != null &&
            code.length == 2 &&
            name != null &&
            name.isNotEmpty) {
          await _cacheCountry(code, name);
          return CountryContext(code: code, name: name);
        }
      }
    } catch (_) {}

    try {
      final localeCountry =
          WidgetsBinding.instance.platformDispatcher.locale.countryCode
              ?.trim()
              .toUpperCase();
      if (localeCountry != null && localeCountry.length == 2) {
        final friendly = _countryNames[localeCountry] ?? localeCountry;
        return CountryContext(code: localeCountry, name: friendly);
      }
    } catch (_) {}

    return null;
  }

  Future<void> _cacheCountry(String code, String name) async {
    try {
      await _storage?.setString(
        _countryCacheKey,
        jsonEncode(<String, dynamic>{
          'code': code,
          'name': name,
          'ts': _now().millisecondsSinceEpoch,
        }),
      );
    } catch (_) {}
  }

  /// Generates a diverse set of rich discovery shelves across global charts,
  /// regional Top 10 Kenya / local charts, personalized picks, hidden gems,
  /// series trending, and African spotlight.
  Future<List<DiscoveryShelf>> buildHomeDiscoveryShelves({
    required List<HistoryItem> history,
    required List<MultimediaItem> library,
  }) async {
    final now = _now();
    final taste = TasteProfile.build(
      history: history,
      library: library,
      now: now,
    );
    final country = await detectCountry();
    final primaryGenre = taste.topCinemetaGenres.first;
    final secondaryGenre = taste.topCinemetaGenres.length > 1
        ? taste.topCinemetaGenres[1]
        : 'Thriller';
    final primaryTmdbGenre = taste.topTmdbGenreIds.isNotEmpty
        ? taste.topTmdbGenreIds.first
        : null;
    final seed = taste.seedItems.firstOrNull;

    final includeLocalChart =
        country != null && country.code.toUpperCase() != 'KE';

    // Run every data source in parallel so latency is bounded by the fastest
    // responses and any failed provider degrades cleanly.
    final results = await Future.wait<List<MultimediaItem>>(<Future<List<MultimediaItem>>>[
      // 0: World trending (TMDB trending all day + Trakt trending + Cinemeta top)
      _buildWorldTop10(),
      // 1: Kenya Top 10 (TMDB KE discover + Apple iTunes KE chart)
      _buildKenyaTop10(),
      // 2: Local country Top 10 (when user is outside KE)
      includeLocalChart
          ? _buildRegionalTop10(country.code)
          : Future<List<MultimediaItem>>.value(const <MultimediaItem>[]),
      // 3: Picked for you (seed related + TMDB genre discover + Cinemeta taste genre)
      _buildPickedForYou(
        seed: seed,
        tmdbGenreId: primaryTmdbGenre,
        cinemetaGenre: primaryGenre,
        seriesFirst: taste.seriesAffinity >= 0.5,
      ),
      // 4: Trending Series worldwide
      _buildTrendingSeries(),
      // 5: Kenyan & African Spotlight
      _buildAfricanSpotlight(),
      // 6: Critically Acclaimed
      _buildCriticallyAcclaimed(),
      // 7: Hidden Gems to Explore
      _buildHiddenGems(secondaryGenre: secondaryGenre),
      // 8: Popular Movies Right Now
      _buildPopularMovies(),
    ]);

    final rawShelves = <DiscoveryShelf>[
      DiscoveryShelf(
        kind: DiscoveryShelfKind.top10World,
        id: 'top10_world',
        ranked: true,
        items: results[0],
      ),
      DiscoveryShelf(
        kind: DiscoveryShelfKind.top10Kenya,
        id: 'top10_kenya',
        countryName: 'Kenya',
        ranked: true,
        items: results[1],
      ),
      if (includeLocalChart)
        DiscoveryShelf(
          kind: DiscoveryShelfKind.top10Local,
          id: 'top10_${country.code.toLowerCase()}',
          countryName: country.name,
          ranked: true,
          items: results[2],
        ),
      DiscoveryShelf(
        kind: DiscoveryShelfKind.pickedForYou,
        id: 'picked_for_you',
        items: results[3],
      ),
      DiscoveryShelf(
        kind: DiscoveryShelfKind.trendingSeries,
        id: 'trending_series',
        items: results[4],
      ),
      DiscoveryShelf(
        kind: DiscoveryShelfKind.africanSpotlight,
        id: 'african_spotlight',
        items: results[5],
      ),
      DiscoveryShelf(
        kind: DiscoveryShelfKind.criticallyAcclaimed,
        id: 'critically_acclaimed',
        items: results[6],
      ),
      DiscoveryShelf(
        kind: DiscoveryShelfKind.hiddenGems,
        id: 'hidden_gems',
        items: results[7],
      ),
      DiscoveryShelf(
        kind: DiscoveryShelfKind.popularMovies,
        id: 'popular_movies',
        items: results[8],
      ),
    ];

    return dedupeAndBalanceShelves(
      rawShelves,
      excludeKeys: taste.excludeKeys,
    );
  }

  /// Removes duplicates across shelves so consecutive shelves feel genuinely
  /// varied while preserving authentic chart order on Top 10 shelves.
  @visibleForTesting
  static List<DiscoveryShelf> dedupeAndBalanceShelves(
    List<DiscoveryShelf> rawShelves, {
    Set<String> excludeKeys = const <String>{},
    int maxTop10Items = 10,
    int maxItemsPerShelf = 15,
  }) {
    final seenInDiscovery = <String>{...excludeKeys};
    final out = <DiscoveryShelf>[];

    for (final shelf in rawShelves) {
      if (shelf.items.isEmpty) continue;
      final limit = shelf.ranked ? maxTop10Items : maxItemsPerShelf;
      final seenInShelf = <String>{};
      final filtered = <MultimediaItem>[];

      for (final item in shelf.items) {
        if (item.title.trim().isEmpty || item.posterUrl.trim().isEmpty) {
          continue;
        }
        final key = canonicalKey(item);
        if (key.isEmpty || !seenInShelf.add(key)) continue;

        if (!shelf.ranked && !seenInDiscovery.add(key)) {
          continue;
        }
        // Track Top 10 items in seenInDiscovery so downstream non-chart shelves
        // do not simply echo the same Top 10 titles over and over.
        if (shelf.ranked) {
          seenInDiscovery.add(key);
        }

        filtered.add(item);
        if (filtered.length >= limit) break;
      }

      if (filtered.isNotEmpty) {
        out.add(
          DiscoveryShelf(
            kind: shelf.kind,
            id: shelf.id,
            countryName: shelf.countryName,
            ranked: shelf.ranked,
            items: filtered,
          ),
        );
      }
    }
    return out;
  }

  Future<List<MultimediaItem>> _buildWorldTop10() async {
    final futures = await Future.wait<List<MultimediaItem>>(<Future<List<MultimediaItem>>>[
      _fetchTmdbEndpoint('/trending/all/day'),
      _fetchTraktChart('/movies/trending?extended=full&limit=12', isSeries: false),
      _fetchItunesChart('us'),
      _fetchCinemetaCatalog('$_cinemetaBase/catalog/movie/top.json',
          fallbackType: MultimediaContentType.movie),
    ]);
    return _interleaveUnique(futures, maxCount: 14);
  }

  Future<List<MultimediaItem>> _buildKenyaTop10() async {
    final futures = await Future.wait<List<MultimediaItem>>(<Future<List<MultimediaItem>>>[
      _fetchTmdbEndpoint(
        '/discover/movie',
        queryParameters: const <String, dynamic>{
          'watch_region': 'KE',
          'sort_by': 'popularity.desc',
          'include_adult': false,
        },
        forcedMediaType: 'movie',
      ),
      _fetchItunesChart('ke'),
      _fetchTmdbEndpoint(
        '/discover/tv',
        queryParameters: const <String, dynamic>{
          'watch_region': 'KE',
          'sort_by': 'popularity.desc',
          'include_adult': false,
        },
        forcedMediaType: 'tv',
      ),
      _fetchTraktChart('/movies/popular?extended=full&limit=12', isSeries: false),
    ]);
    final merged = _interleaveUnique(futures, maxCount: 14);
    if (merged.isNotEmpty) return merged;
    return _fetchCinemetaCatalog(
      '$_cinemetaBase/catalog/movie/top/genre=Action.json',
      fallbackType: MultimediaContentType.movie,
    );
  }

  Future<List<MultimediaItem>> _buildRegionalTop10(String countryCode) async {
    final futures = await Future.wait<List<MultimediaItem>>(<Future<List<MultimediaItem>>>[
      _fetchTmdbEndpoint(
        '/discover/movie',
        queryParameters: <String, dynamic>{
          'watch_region': countryCode.toUpperCase(),
          'sort_by': 'popularity.desc',
          'include_adult': false,
        },
        forcedMediaType: 'movie',
      ),
      _fetchItunesChart(countryCode),
      _fetchTmdbEndpoint(
        '/discover/tv',
        queryParameters: <String, dynamic>{
          'watch_region': countryCode.toUpperCase(),
          'sort_by': 'popularity.desc',
          'include_adult': false,
        },
        forcedMediaType: 'tv',
      ),
    ]);
    return _interleaveUnique(futures, maxCount: 12);
  }

  Future<List<MultimediaItem>> _buildPickedForYou({
    required MultimediaItem? seed,
    required int? tmdbGenreId,
    required String cinemetaGenre,
    required bool seriesFirst,
  }) async {
    final futures = await Future.wait<List<MultimediaItem>>(<Future<List<MultimediaItem>>>[
      if (seed != null) _fetchSeedRelated(seed),
      if (tmdbGenreId != null)
        _fetchTmdbEndpoint(
          seriesFirst ? '/discover/tv' : '/discover/movie',
          queryParameters: <String, dynamic>{
            'with_genres': '$tmdbGenreId',
            'sort_by': 'vote_average.desc',
            'vote_count.gte': 180,
            'include_adult': false,
          },
          forcedMediaType: seriesFirst ? 'tv' : 'movie',
        ),
      _fetchCinemetaCatalog(
        '$_cinemetaBase/catalog/${seriesFirst ? 'series' : 'movie'}/top/genre=${Uri.encodeComponent(cinemetaGenre)}.json',
        fallbackType: seriesFirst
            ? MultimediaContentType.series
            : MultimediaContentType.movie,
      ),
      _fetchTraktChart('/movies/anticipated?extended=full&limit=15',
          isSeries: false),
    ]);
    return _interleaveUnique(futures, maxCount: 18);
  }

  Future<List<MultimediaItem>> _buildTrendingSeries() async {
    final futures = await Future.wait<List<MultimediaItem>>(<Future<List<MultimediaItem>>>[
      _fetchTmdbEndpoint('/trending/tv/day', forcedMediaType: 'tv'),
      _fetchTraktChart('/shows/trending?extended=full&limit=15', isSeries: true),
      _fetchCinemetaCatalog(
        '$_cinemetaBase/catalog/series/top.json',
        fallbackType: MultimediaContentType.series,
      ),
    ]);
    return _interleaveUnique(futures, maxCount: 18);
  }

  Future<List<MultimediaItem>> _buildAfricanSpotlight() async {
    final futures = await Future.wait<List<MultimediaItem>>(<Future<List<MultimediaItem>>>[
      _fetchTmdbEndpoint(
        '/discover/movie',
        queryParameters: const <String, dynamic>{
          'with_origin_country': 'KE|NG|ZA|GH',
          'sort_by': 'popularity.desc',
          'include_adult': false,
        },
        forcedMediaType: 'movie',
      ),
      _fetchTmdbEndpoint(
        '/discover/tv',
        queryParameters: const <String, dynamic>{
          'with_origin_country': 'KE|NG|ZA|GH',
          'sort_by': 'popularity.desc',
          'include_adult': false,
        },
        forcedMediaType: 'tv',
      ),
      _fetchItunesChart('ke'),
      _fetchItunesChart('za'),
    ]);
    return _interleaveUnique(futures, maxCount: 16);
  }

  Future<List<MultimediaItem>> _buildCriticallyAcclaimed() async {
    final futures = await Future.wait<List<MultimediaItem>>(<Future<List<MultimediaItem>>>[
      _fetchTmdbEndpoint('/movie/top_rated', forcedMediaType: 'movie'),
      _fetchTmdbEndpoint('/tv/top_rated', forcedMediaType: 'tv'),
      _fetchCinemetaCatalog(
        '$_cinemetaBase/catalog/movie/imdbRating.json',
        fallbackType: MultimediaContentType.movie,
      ),
      _fetchCinemetaCatalog(
        '$_cinemetaBase/catalog/series/imdbRating.json',
        fallbackType: MultimediaContentType.series,
      ),
    ]);
    return _interleaveUnique(futures, maxCount: 18);
  }

  Future<List<MultimediaItem>> _buildHiddenGems({
    required String secondaryGenre,
  }) async {
    final futures = await Future.wait<List<MultimediaItem>>(<Future<List<MultimediaItem>>>[
      _fetchTmdbEndpoint(
        '/discover/movie',
        queryParameters: const <String, dynamic>{
          'vote_average.gte': 7.5,
          'vote_count.gte': 250,
          'vote_count.lte': 4500,
          'sort_by': 'vote_average.desc',
          'include_adult': false,
        },
        forcedMediaType: 'movie',
      ),
      _fetchCinemetaCatalog(
        '$_cinemetaBase/catalog/movie/imdbRating/genre=${Uri.encodeComponent(secondaryGenre)}.json',
        fallbackType: MultimediaContentType.movie,
      ),
    ]);
    return _interleaveUnique(futures, maxCount: 16);
  }

  Future<List<MultimediaItem>> _buildPopularMovies() async {
    final futures = await Future.wait<List<MultimediaItem>>(<Future<List<MultimediaItem>>>[
      _fetchTmdbEndpoint('/movie/popular', forcedMediaType: 'movie'),
      _fetchTraktChart('/movies/popular?extended=full&limit=18', isSeries: false),
      _fetchCinemetaCatalog(
        '$_cinemetaBase/catalog/movie/top.json',
        fallbackType: MultimediaContentType.movie,
      ),
    ]);
    return _interleaveUnique(futures, maxCount: 18);
  }

  /// Multi-signal similarity engine fusing TMDB recommendations/similar,
  /// Trakt public related titles, and multi-genre Cinemeta scoring instead
  /// of single-genre fallback loops.
  Future<List<MultimediaItem>> getSimilarItems(MultimediaItem item) async {
    final isSeries = item.contentType == MultimediaContentType.series ||
        item.contentType == MultimediaContentType.anime;
    final tmdbType = isSeries ? 'tv' : 'movie';
    final cmType = isSeries ? 'series' : 'movie';
    final selfKey = canonicalKey(item);

    int? resolvedTmdbId = item.tmdbId;
    if (_tmdbKey.isNotEmpty && resolvedTmdbId == null) {
      resolvedTmdbId = await _resolveTmdbId(item, tmdbType: tmdbType);
    }

    var genres = (item.tags ?? const <String>[])
        .where((g) => g.trim().isNotEmpty)
        .take(2)
        .toList();
    if (genres.isEmpty &&
        item.imdbId != null &&
        item.imdbId!.startsWith('tt')) {
      genres = await _fetchCinemetaGenres(cmType, item.imdbId!);
    }

    final traktId = (item.imdbId != null && item.imdbId!.startsWith('tt'))
        ? item.imdbId
        : null;

    final sources = await Future.wait<List<MultimediaItem>>(<Future<List<MultimediaItem>>>[
      if (_tmdbKey.isNotEmpty && resolvedTmdbId != null && resolvedTmdbId > 0)
        _fetchTmdbEndpoint(
          '/$tmdbType/$resolvedTmdbId/recommendations',
          forcedMediaType: tmdbType,
        ),
      if (_tmdbKey.isNotEmpty && resolvedTmdbId != null && resolvedTmdbId > 0)
        _fetchTmdbEndpoint(
          '/$tmdbType/$resolvedTmdbId/similar',
          forcedMediaType: tmdbType,
        ),
      if (_traktClientId.isNotEmpty && traktId != null)
        _fetchTraktChart(
          '/${isSeries ? 'shows' : 'movies'}/$traktId/related?extended=full&limit=15',
          isSeries: isSeries,
        ),
      for (var i = 0; i < genres.length; i++)
        _fetchCinemetaCatalog(
          '$_cinemetaBase/catalog/$cmType/${i == 0 ? 'top' : 'imdbRating'}/genre=${Uri.encodeComponent(genres[i])}.json',
          fallbackType: isSeries
              ? MultimediaContentType.series
              : MultimediaContentType.movie,
        ),
      if (genres.isEmpty)
        _fetchCinemetaCatalog(
          '$_cinemetaBase/catalog/$cmType/imdbRating.json',
          fallbackType: isSeries
              ? MultimediaContentType.series
              : MultimediaContentType.movie,
        ),
    ]);

    final combined = _interleaveUnique(sources, maxCount: 20);
    final filtered = combined
        .where((c) => canonicalKey(c) != selfKey)
        .take(15)
        .toList(growable: false);
    return filtered;
  }

  Future<int?> _resolveTmdbId(
    MultimediaItem item, {
    required String tmdbType,
  }) async {
    try {
      if (item.imdbId != null && item.imdbId!.startsWith('tt')) {
        final resp = await _dio
            .get<dynamic>(
              '${TmdbConfig.baseUrl}/find/${item.imdbId}',
              queryParameters: <String, dynamic>{
                'api_key': _tmdbKey,
                'external_source': 'imdb_id',
              },
            )
            .timeout(const Duration(seconds: 4));
        final data = resp.data;
        if (data is Map) {
          final bucket = data['${tmdbType}_results'];
          if (bucket is List && bucket.isNotEmpty && bucket.first is Map) {
            return (bucket.first['id'] as num?)?.toInt();
          }
        }
      }
      if (item.title.trim().isNotEmpty) {
        final resp = await _dio
            .get<dynamic>(
              '${TmdbConfig.baseUrl}/search/$tmdbType',
              queryParameters: <String, dynamic>{
                'api_key': _tmdbKey,
                'query': item.title.trim(),
                if (item.year != null) 'year': item.year,
              },
            )
            .timeout(const Duration(seconds: 4));
        final data = resp.data;
        if (data is Map && data['results'] is List) {
          final results = data['results'] as List;
          if (results.isNotEmpty && results.first is Map) {
            return (results.first['id'] as num?)?.toInt();
          }
        }
      }
    } catch (_) {}
    return null;
  }

  Future<List<String>> _fetchCinemetaGenres(String cmType, String imdbId) async {
    try {
      final resp = await _dio
          .get<dynamic>('$_cinemetaBase/meta/$cmType/$imdbId.json')
          .timeout(const Duration(seconds: 4));
      final data = resp.data;
      if (data is Map && data['meta'] is Map) {
        final genres = data['meta']['genres'];
        if (genres is List) {
          return genres
              .map((g) => g.toString().trim())
              .where((g) => g.isNotEmpty)
              .take(2)
              .toList();
        }
      }
    } catch (_) {}
    return const <String>[];
  }

  Future<List<MultimediaItem>> _fetchSeedRelated(MultimediaItem seed) async {
    final isSeries = seed.contentType == MultimediaContentType.series ||
        seed.contentType == MultimediaContentType.anime;
    final tasks = <Future<List<MultimediaItem>>>[];
    if (_tmdbKey.isNotEmpty && seed.tmdbId != null && seed.tmdbId! > 0) {
      final path = isSeries
          ? '/tv/${seed.tmdbId}/recommendations'
          : '/movie/${seed.tmdbId}/recommendations';
      tasks.add(
        _fetchTmdbEndpoint(path, forcedMediaType: isSeries ? 'tv' : 'movie'),
      );
    }
    if (_traktClientId.isNotEmpty &&
        seed.imdbId != null &&
        seed.imdbId!.startsWith('tt')) {
      final type = isSeries ? 'shows' : 'movies';
      tasks.add(
        _fetchTraktChart(
          '/$type/${seed.imdbId}/related?extended=full&limit=15',
          isSeries: isSeries,
        ),
      );
    }
    if (tasks.isEmpty) return const <MultimediaItem>[];
    final res = await Future.wait<List<MultimediaItem>>(tasks);
    return _interleaveUnique(res, maxCount: 15);
  }

  Future<List<MultimediaItem>> _fetchTmdbEndpoint(
    String path, {
    Map<String, dynamic> queryParameters = const <String, dynamic>{},
    String? forcedMediaType,
  }) async {
    if (_tmdbKey.isEmpty) return const <MultimediaItem>[];
    try {
      final resp = await _dio
          .get<dynamic>(
            '${TmdbConfig.baseUrl}$path',
            queryParameters: <String, dynamic>{
              'api_key': _tmdbKey,
              'language': 'en-US',
              ...queryParameters,
            },
          )
          .timeout(_remoteTimeout);
      final data = resp.data;
      if (data is! Map || data['results'] is! List) {
        return const <MultimediaItem>[];
      }
      final list = data['results'] as List;
      final out = <MultimediaItem>[];
      for (final raw in list) {
        if (raw is! Map) continue;
        final map = Map<String, dynamic>.from(raw);
        if (forcedMediaType != null && !map.containsKey('media_type')) {
          map['media_type'] = forcedMediaType;
        }
        final item = MultimediaItem.fromTmdbJson(map);
        if (item.title.trim().isNotEmpty && item.posterUrl.trim().isNotEmpty) {
          out.add(item);
        }
      }
      return out;
    } catch (_) {
      return const <MultimediaItem>[];
    }
  }

  Future<List<MultimediaItem>> _fetchTraktChart(
    String pathAndQuery, {
    required bool isSeries,
  }) async {
    if (_traktClientId.isEmpty) return const <MultimediaItem>[];
    try {
      final resp = await _dio
          .get<dynamic>(
            '$_traktBase$pathAndQuery',
            options: Options(
              headers: <String, String>{
                'Content-Type': 'application/json',
                'trakt-api-version': '2',
                'trakt-api-key': _traktClientId,
              },
            ),
          )
          .timeout(_remoteTimeout);
      final data = resp.data;
      if (data is! List) return const <MultimediaItem>[];
      final out = <MultimediaItem>[];
      for (final entry in data) {
        if (entry is! Map) continue;
        final mediaRaw = isSeries
            ? (entry['show'] ?? entry)
            : (entry['movie'] ?? entry);
        if (mediaRaw is! Map) continue;
        final media = Map<String, dynamic>.from(mediaRaw);
        final title = (media['title'] as String?)?.trim() ?? '';
        final ids = media['ids'] is Map
            ? Map<String, dynamic>.from(media['ids'] as Map)
            : const <String, dynamic>{};
        final imdb = (ids['imdb'] as String?)?.trim();
        final tmdb = (ids['tmdb'] as num?)?.toInt();
        if (title.isEmpty || imdb == null || imdb.isEmpty) continue;

        final typeStr = isSeries ? 'series' : 'movie';
        out.add(
          MultimediaItem(
            title: title,
            url: jsonEncode(<String, dynamic>{
              'id': imdb,
              'imdbId': imdb,
              'tmdbId': ?tmdb,
              'type': typeStr,
              'title': title,
            }),
            posterUrl: '$_metahubPoster/$imdb/img',
            bannerUrl: '$_metahubBg/$imdb/img',
            description: media['overview'] as String?,
            contentType: isSeries
                ? MultimediaContentType.series
                : MultimediaContentType.movie,
            provider: 'cinemeta',
            imdbId: imdb,
            tmdbId: tmdb,
            year: (media['year'] as num?)?.toInt(),
            score: (media['rating'] as num?)?.toDouble(),
            tags: (media['genres'] is List)
                ? (media['genres'] as List)
                      .map((g) => g.toString())
                      .toList(growable: false)
                : null,
          ),
        );
      }
      return out;
    } catch (_) {
      return const <MultimediaItem>[];
    }
  }

  /// Keyless real-time Apple iTunes Storefront chart (e.g. `ke`, `us`, `gb`),
  /// enriched with Cinemeta IMDb IDs where fast search succeeds so playback
  /// opens seamlessly without any setup.
  Future<List<MultimediaItem>> _fetchItunesChart(String countryCode) async {
    try {
      final cc = countryCode.trim().toLowerCase();
      if (cc.length != 2) return const <MultimediaItem>[];
      final resp = await _dio
          .get<dynamic>(
            'https://itunes.apple.com/$cc/rss/topmovies/limit=15/json',
          )
          .timeout(_remoteTimeout);
      final raw = resp.data;
      final decoded = raw is String ? jsonDecode(raw) : raw;
      if (decoded is! Map) return const <MultimediaItem>[];
      final feed = decoded['feed'];
      if (feed is! Map || feed['entry'] is! List) {
        return const <MultimediaItem>[];
      }
      final entries = feed['entry'] as List;
      final parsed = <_ItunesSeed>[];
      for (final e in entries) {
        if (e is! Map) continue;
        final nameRaw = (e['im:name'] is Map)
            ? (e['im:name']['label'] as String?)
            : null;
        if (nameRaw == null || nameRaw.trim().isEmpty) continue;
        final cleanTitle = nameRaw
            .replaceAll(RegExp(r'\s*\(\d{4}\)\s*$'), '')
            .trim();
        String poster = '';
        if (e['im:image'] is List && (e['im:image'] as List).isNotEmpty) {
          final lastImg = (e['im:image'] as List).last;
          if (lastImg is Map) {
            poster = ((lastImg['label'] as String?) ?? '').replaceAll(
              RegExp(r'\d+x\d+bb'),
              '600x600bb',
            );
          }
        }
        if (poster.isEmpty) continue;
        final summary = (e['summary'] is Map)
            ? (e['summary']['label'] as String?)
            : null;
        final releaseStr = (e['im:releaseDate'] is Map)
            ? (e['im:releaseDate']['label'] as String?)
            : null;
        final year = releaseStr != null && releaseStr.length >= 4
            ? int.tryParse(releaseStr.substring(0, 4))
            : null;
        final genreLabel = (e['category'] is Map &&
                e['category']['attributes'] is Map)
            ? (e['category']['attributes']['label'] as String?)
            : null;
        parsed.add(
          _ItunesSeed(
            title: cleanTitle,
            posterUrl: poster,
            summary: summary,
            year: year,
            genre: genreLabel,
          ),
        );
      }

      if (parsed.isEmpty) return const <MultimediaItem>[];

      // Enrich top 10 entries concurrently with Cinemeta IMDb IDs.
      final resolved = await Future.wait<MultimediaItem>(
        parsed.take(10).map((seed) => _enrichItunesSeed(seed)),
      );
      return resolved;
    } catch (_) {
      return const <MultimediaItem>[];
    }
  }

  Future<MultimediaItem> _enrichItunesSeed(_ItunesSeed seed) async {
    try {
      final resp = await _dio
          .get<dynamic>(
            '$_cinemetaBase/catalog/movie/top/search=${Uri.encodeComponent(seed.title)}.json',
          )
          .timeout(const Duration(seconds: 3));
      final metas = resp.data is Map ? resp.data['metas'] : null;
      if (metas is List && metas.isNotEmpty && metas.first is Map) {
        final match = Map<String, dynamic>.from(metas.first as Map);
        final imdb = (match['imdb_id'] ?? match['id'])?.toString();
        if (imdb != null && imdb.startsWith('tt')) {
          final title = (match['name'] as String?)?.trim() ?? seed.title;
          return MultimediaItem(
            title: title,
            url: jsonEncode(<String, dynamic>{
              'id': imdb,
              'imdbId': imdb,
              'type': 'movie',
              'title': title,
            }),
            posterUrl:
                (match['poster'] as String?)?.trim().isNotEmpty == true
                    ? (match['poster'] as String).trim()
                    : seed.posterUrl,
            bannerUrl: match['background'] as String?,
            description: (match['description'] as String?) ?? seed.summary,
            contentType: MultimediaContentType.movie,
            provider: 'cinemeta',
            imdbId: imdb,
            year: seed.year ??
                int.tryParse(match['releaseInfo']?.toString() ?? ''),
            tags: seed.genre != null ? <String>[seed.genre!] : null,
          );
        }
      }
    } catch (_) {}

    return MultimediaItem(
      title: seed.title,
      url: jsonEncode(<String, dynamic>{
        'title': seed.title,
        'type': 'movie',
        if (seed.year != null) 'year': seed.year,
      }),
      posterUrl: seed.posterUrl,
      description: seed.summary,
      contentType: MultimediaContentType.movie,
      provider: 'cinemeta',
      year: seed.year,
      tags: seed.genre != null ? <String>[seed.genre!] : null,
    );
  }

  Future<List<MultimediaItem>> _fetchCinemetaCatalog(
    String url, {
    required MultimediaContentType fallbackType,
  }) async {
    try {
      final resp = await _dio.get<dynamic>(url).timeout(_remoteTimeout);
      final data = resp.data;
      if (data is! Map || data['metas'] is! List) {
        return const <MultimediaItem>[];
      }
      final metas = data['metas'] as List;
      final out = <MultimediaItem>[];
      for (final raw in metas) {
        if (raw is! Map) continue;
        final meta = Map<String, dynamic>.from(raw);
        final title = (meta['name'] as String?)?.trim() ?? '';
        final poster = (meta['poster'] as String?)?.trim() ?? '';
        final id = (meta['imdb_id'] ?? meta['id'])?.toString().trim() ?? '';
        if (title.isEmpty || poster.isEmpty || id.isEmpty) continue;
        final typeStr = (meta['type'] as String?) ??
            (fallbackType == MultimediaContentType.series ? 'series' : 'movie');
        out.add(
          MultimediaItem(
            title: title,
            url: jsonEncode(<String, dynamic>{
              'id': id,
              'imdbId': id,
              'type': typeStr,
              'title': title,
            }),
            posterUrl: poster,
            bannerUrl: meta['background'] as String?,
            description: meta['description'] as String?,
            contentType: typeStr == 'series'
                ? MultimediaContentType.series
                : MultimediaContentType.movie,
            provider: 'cinemeta',
            imdbId: id.startsWith('tt') ? id : null,
            year: int.tryParse(
              (meta['releaseInfo']?.toString() ?? '').split('-').first,
            ),
            score: double.tryParse(meta['imdbRating']?.toString() ?? ''),
            tags: meta['genres'] is List
                ? (meta['genres'] as List)
                      .map((g) => g.toString())
                      .toList(growable: false)
                : null,
          ),
        );
      }
      return out;
    } catch (_) {
      return const <MultimediaItem>[];
    }
  }

  static List<MultimediaItem> _interleaveUnique(
    List<List<MultimediaItem>> sources, {
    required int maxCount,
  }) {
    final out = <MultimediaItem>[];
    final seen = <String>{};
    final maxLen = sources.fold<int>(0, (m, l) => math.max(m, l.length));

    for (var i = 0; i < maxLen && out.length < maxCount; i++) {
      for (final list in sources) {
        if (i >= list.length) continue;
        final item = list[i];
        final key = canonicalKey(item);
        if (key.isEmpty || !seen.add(key)) continue;
        out.add(item);
        if (out.length >= maxCount) break;
      }
    }
    return out;
  }
}

class _ItunesSeed {
  final String title;
  final String posterUrl;
  final String? summary;
  final int? year;
  final String? genre;

  const _ItunesSeed({
    required this.title,
    required this.posterUrl,
    this.summary,
    this.year,
    this.genre,
  });
}

/// Provides a shared [DiscoveryEngine] instance backed by app Dio & Storage.
final discoveryEngineProvider = Provider<DiscoveryEngine>((ref) {
  final dio = ref.watch(dioClientProvider);
  final storage = ref.watch(storageServiceProvider);
  return DiscoveryEngine(dio: dio, storage: storage);
});

/// Live multi-signal recommendation shelves reacting to watch history and
/// library changes with zero mandatory configuration.
final smartDiscoveryProvider = FutureProvider<List<DiscoveryShelf>>((ref) async {
  final history = ref.watch(watchHistoryProvider);
  final libraryState = ref.watch(libraryProvider);
  final library = switch (libraryState) {
    LibrarySuccess(items: final items) => items,
    _ => const <MultimediaItem>[],
  };
  final engine = ref.watch(discoveryEngineProvider);
  return engine.buildHomeDiscoveryShelves(
    history: history,
    library: library,
  );
});

/// Multi-signal similarity provider replacing single-genre Cinemeta lookups.
final deepSimilarItemsProvider =
    FutureProvider.family<List<MultimediaItem>, MultimediaItem>((ref, item) {
      return ref.watch(discoveryEngineProvider).getSimilarItems(item);
    });
