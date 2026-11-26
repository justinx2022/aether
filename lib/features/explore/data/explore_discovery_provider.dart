import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';

import '../../../core/network/dio_client_provider.dart';
import '../../../core/domain/entity/multimedia_item.dart';
import '../../../core/extensions/extension_manager.dart';
import '../../../core/config/tmdb_config.dart';
import '../../../core/recommendations/aether_discovery_intelligence.dart';
import '../../../core/recommendations/recommendations_service.dart';
import 'explore_filter_provider.dart';
import 'explore_language_provider.dart';
import 'explore_tmdb_provider.dart';
import 'anilist_repository.dart';

/// State for infinite Explore discovery feeds.
class ExploreDiscoveryState {
  final List<MultimediaItem> items;
  final int page;
  final bool isLoadingMore;
  final bool hasMore;
  final bool isRefreshing;
  final Object? error;

  const ExploreDiscoveryState({
    this.items = const [],
    this.page = 1,
    this.isLoadingMore = false,
    this.hasMore = true,
    this.isRefreshing = false,
    this.error,
  });

  ExploreDiscoveryState copyWith({
    List<MultimediaItem>? items,
    int? page,
    bool? isLoadingMore,
    bool? hasMore,
    bool? isRefreshing,
    Object? error,
  }) {
    return ExploreDiscoveryState(
      items: items ?? this.items,
      page: page ?? this.page,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      hasMore: hasMore ?? this.hasMore,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      error: error,
    );
  }
}

/// Notifier driving infinite pagination and ADI recommendation scoring for Explore.
class ExploreDiscoveryNotifier extends Notifier<ExploreDiscoveryState> {
  @override
  ExploreDiscoveryState build() {
    ref.watch(exploreFilterProvider);
    ref.watch(languageProvider);
    Future.microtask(() => loadInitial());
    return const ExploreDiscoveryState(isRefreshing: true);
  }

  Future<void> loadInitial() async {
    state = state.copyWith(isRefreshing: true, error: null);
    try {
      final items = await _fetchPage(1);
      state = state.copyWith(
        items: items,
        page: 1,
        hasMore: items.isNotEmpty,
        isRefreshing: false,
      );
    } catch (e) {
      state = state.copyWith(isRefreshing: false, error: e);
    }
  }

  Future<void> loadMore() async {
    if (state.isLoadingMore || !state.hasMore || state.isRefreshing) return;

    state = state.copyWith(isLoadingMore: true);
    final nextPage = state.page + 1;

    try {
      // Endless discovery: fetch next 2 pages in parallel for massive, seamless depth (1000+ items)
      final p1Future = _fetchPage(nextPage);
      final p2Future = nextPage < 60 ? _fetchPage(nextPage + 1) : Future.value(<MultimediaItem>[]);
      final pages = await Future.wait([p1Future, p2Future]);
      final newItems = [...pages[0], ...pages[1]];

      if (newItems.isEmpty && nextPage > 50) {
        state = state.copyWith(isLoadingMore: false, hasMore: false);
        return;
      }

      // De-duplicate newly fetched items against existing items
      final existingKeys = state.items.map((i) => _itemKey(i)).toSet();
      final fresh = newItems.where((i) => !existingKeys.contains(_itemKey(i))).toList();

      // An empty (or fully duplicate) page means the feed is exhausted.
      // Keeping hasMore true here made the grid fetch forever with nothing
      // new to show.
      if (fresh.isEmpty) {
        state = state.copyWith(isLoadingMore: false, hasMore: false);
        return;
      }

      final advancedPage = pages[1].isNotEmpty ? (nextPage + 1) : nextPage;
      state = state.copyWith(
        items: [...state.items, ...fresh],
        page: advancedPage,
        isLoadingMore: false,
        hasMore: advancedPage < 80,
      );
    } catch (e) {
      if (kDebugMode) debugPrint('ExploreDiscoveryNotifier loadMore error: $e');
      state = state.copyWith(isLoadingMore: false);
    }
  }

  String _itemKey(MultimediaItem item) {
    if (item.imdbId != null && item.imdbId!.isNotEmpty) return item.imdbId!;
    if (item.tmdbId != null && item.tmdbId! > 0) return 'tmdb_${item.tmdbId}';
    return item.title.trim().toLowerCase();
  }

  Future<List<MultimediaItem>> _fetchPage(int page) async {
    final filters = ref.read(exploreFilterProvider);
    final lang = ref.read(languageProvider);
    final activeProvider = ref.read(activeProviderProvider);
    final tmdbService = ref.read(tmdbServiceProvider);

    // 1. Anime mode or Anime media type selection
    if (filters.mediaType == 'anime') {
      final titleLang = ref.read(animeTitleLanguageProvider);
      final anilist = ref.read(anilistRepositoryProvider);
      final animeList = await anilist.fetchSection(
        'trending',
        genre: filters.selectedGenre?.name,
        year: filters.selectedYear,
        minRating: filters.minRating,
        titleLang: titleLang,
      );
      return animeList.map((item) => _prepareResolvableItem(item)).toList();
    }

    // Map sort order for TMDB
    String tmdbSort;
    switch (filters.sortBy) {
      case 'rating':
        tmdbSort = 'vote_average.desc';
        break;
      case 'newest':
        tmdbSort = 'primary_release_date.desc';
        break;
      case 'title':
        tmdbSort = 'title.asc';
        break;
      case 'popularity':
      default:
        tmdbSort = 'popularity.desc';
        break;
    }

    final tmdbItems = <MultimediaItem>[];
    if (TmdbConfig.apiKey.isNotEmpty) {
      try {
        final shouldFetchMovies =
            filters.mediaType == 'all' || filters.mediaType == 'movie';
        final shouldFetchTV =
            filters.mediaType == 'all' || filters.mediaType == 'series';

        final futures = <Future<List<MultimediaItem>>>[];

        if (shouldFetchMovies) {
          futures.add(
            tmdbService.discoverMedia(
              isMovie: true,
              language: lang,
              genreId: filters.selectedGenre?.id,
              year: filters.selectedYear,
              country: filters.selectedCountry,
              sortBy: tmdbSort,
              minRating: filters.minRating,
              page: page,
            ),
          );
        }

        if (shouldFetchTV) {
          final tvSort = filters.sortBy == 'newest'
              ? 'first_air_date.desc'
              : (filters.sortBy == 'title' ? 'name.asc' : tmdbSort);
          futures.add(
            tmdbService.discoverMedia(
              isMovie: false,
              language: lang,
              genreId: filters.selectedGenre?.id,
              year: filters.selectedYear,
              country: filters.selectedCountry,
              sortBy: tvSort,
              minRating: filters.minRating,
              page: page,
            ),
          );
        }

        final results = await Future.wait(futures);
        for (final list in results) {
          for (final item in list) {
            tmdbItems.add(_prepareResolvableItem(item));
          }
        }
      } catch (e) {
        if (kDebugMode) debugPrint('TMDB discovery fetch error: $e');
      }
    }

    // 2. Open Cinemeta Infinite Catalog fallback (ensures thousands of titles even without TMDB key)
    final cinemetaItems = <MultimediaItem>[];
    if (tmdbItems.isEmpty) {
      try {
        final cineFutures = <Future<List<MultimediaItem>>>[];
        final genreName = filters.selectedGenre?.name;
        final shouldFetchMovies =
            filters.mediaType == 'all' || filters.mediaType == 'movie';
        final shouldFetchTV =
            filters.mediaType == 'all' || filters.mediaType == 'series';

        if (shouldFetchMovies) {
          cineFutures.add(_fetchCinemetaCatalog(
            type: 'movie',
            genre: genreName,
            page: page,
          ));
        }
        if (shouldFetchTV) {
          cineFutures.add(_fetchCinemetaCatalog(
            type: 'series',
            genre: genreName,
            page: page,
          ));
        }
        final cineResults = await Future.wait(cineFutures);
        for (final list in cineResults) {
          cinemetaItems.addAll(list);
        }
      } catch (e) {
        if (kDebugMode) debugPrint('Cinemeta catalog fetch error: $e');
      }
    }

    // 3. Fetch Native Provider content on page 1 for independence & offline resilience
    final providerItems = <MultimediaItem>[];
    if (page == 1 && activeProvider != null) {
      try {
        final homeCategories = await activeProvider.getHome();
        for (final entry in homeCategories.entries) {
          final categoryName = entry.key.toLowerCase();
          final items = entry.value;

          for (final item in items) {
            if (filters.mediaType == 'movie' &&
                item.contentType == MultimediaContentType.series) {
              continue;
            }
            if (filters.mediaType == 'series' &&
                item.contentType == MultimediaContentType.movie) {
              continue;
            }

            if (filters.selectedGenre != null) {
              final genreName = filters.selectedGenre!.name.toLowerCase();
              final matchesCategory = categoryName.contains(genreName);
              final matchesDesc =
                  (item.description ?? '').toLowerCase().contains(genreName);
              final matchesTag =
                  item.tags?.any((t) => t.toLowerCase().contains(genreName)) ??
                  false;

              if (!matchesCategory && !matchesDesc && !matchesTag) {
                continue;
              }
            }

            if (filters.selectedYear != null) {
              final yearStr = '${filters.selectedYear}';
              if (!item.releaseDate.contains(yearStr) &&
                  !(item.description ?? '').contains(yearStr)) {
                continue;
              }
            }

            providerItems.add(_prepareResolvableItem(item));
          }
        }
      } catch (_) {}
    }

    // 4. Blend & Deduplicate via ADI Exposure Store
    final combined = <MultimediaItem>[...tmdbItems, ...cinemetaItems, ...providerItems];
    final unique = AdiExposureStore.instance.deduplicate(combined);

    // 4. Sort results
    if (filters.sortBy == 'rating') {
      unique.sort((a, b) => b.voteAverage.compareTo(a.voteAverage));
    } else if (filters.sortBy == 'newest') {
      unique.sort((a, b) => b.releaseDate.compareTo(a.releaseDate));
    } else if (filters.sortBy == 'title') {
      unique.sort(
        (a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()),
      );
    }

    return unique;
  }

  Future<List<MultimediaItem>> _fetchCinemetaCatalog({
    required String type,
    String? genre,
    required int page,
  }) async {
    try {
      final dio = ref.read(dioClientProvider);
      final skip = (page - 1) * 50;
      final genreSegment = (genre != null && genre.isNotEmpty && genre != 'All Genres')
          ? '/genre=${Uri.encodeComponent(genre)}'
          : '';
      final skipSegment = skip > 0 ? '/skip=$skip' : '';
      final url = 'https://cinemeta-catalogs.strem.io/top/catalog/$type/top$genreSegment$skipSegment.json';
      final response = await dio.get<Map<String, dynamic>>(
        url,
        options: Options(receiveTimeout: const Duration(seconds: 8)),
      );
      if (response.statusCode == 200 && response.data != null && response.data!['metas'] is List) {
        final metas = response.data!['metas'] as List;
        return metas.map((m) {
          final map = m as Map<String, dynamic>;
          final id = map['id']?.toString() ?? '';
          final title = map['name']?.toString() ?? '';
          final year = map['year']?.toString();
          final poster = map['poster']?.toString() ?? '';
          final banner = map['background']?.toString();
          final desc = map['description']?.toString() ?? '';
          final genres = (map['genres'] as List?)?.map((g) => g.toString()).toList() ?? [];

          return _prepareResolvableItem(
            MultimediaItem(
              title: title,
              url: RecommendationsService.catalogueToken(
                imdbId: id.startsWith('tt') ? id : '',
                type: type == 'series' ? 'series' : 'movie',
                title: title,
                year: year,
              ),
              posterUrl: poster,
              bannerUrl: banner,
              description: desc,
              contentType: type == 'series' ? MultimediaContentType.series : MultimediaContentType.movie,
              provider: RecommendationsService.catalogueProvider,
              imdbId: id.startsWith('tt') ? id : null,
              year: int.tryParse(year?.split(RegExp(r'[\D]')).first ?? ''),
              releaseDateIso: year,
              tags: genres,
            ),
          );
        }).toList();
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[ExploreDiscovery] Cinemeta fetch error: $e');
    }
    return [];
  }

  /// Ensures every card in Explore is 100% clickable and resolves into stream playback
  MultimediaItem _prepareResolvableItem(MultimediaItem item) {
    final effectiveUrl = item.url.isNotEmpty && !item.url.startsWith('aether:')
        ? item.url
        : RecommendationsService.catalogueToken(
            imdbId: item.imdbId ?? (item.tmdbId != null ? 'tmdb:${item.tmdbId}' : ''),
            type: item.contentType == MultimediaContentType.series ? 'series' : 'movie',
            title: item.title,
            year: item.year?.toString(),
          );

    return item.copyWith(
      url: effectiveUrl,
      provider: RecommendationsService.catalogueProvider,
    );
  }
}

/// Global Notifier provider for infinite Explore discovery
final exploreDiscoveryNotifierProvider =
    NotifierProvider<ExploreDiscoveryNotifier, ExploreDiscoveryState>(
  ExploreDiscoveryNotifier.new,
);

/// Backwards-compatible AsyncValue provider for existing consumers
final exploreDiscoveryProvider = Provider<AsyncValue<List<MultimediaItem>>>((ref) {
  final state = ref.watch(exploreDiscoveryNotifierProvider);
  if (state.items.isEmpty && state.isRefreshing) {
    return const AsyncLoading();
  }
  if (state.error != null && state.items.isEmpty) {
    return AsyncError(state.error!, StackTrace.current);
  }
  return AsyncData(state.items);
});
