import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/domain/entity/multimedia_item.dart';
import '../../../core/extensions/extension_manager.dart';
import '../../../core/config/tmdb_config.dart';
import 'explore_filter_provider.dart';
import 'explore_language_provider.dart';
import 'explore_tmdb_provider.dart';
import 'anilist_repository.dart';

final exploreDiscoveryProvider =
    FutureProvider.autoDispose<List<MultimediaItem>>((ref) async {
  final filters = ref.watch(exploreFilterProvider);
  final lang = ref.watch(languageProvider);
  final activeProvider = ref.watch(activeProviderProvider);
  final tmdbService = ref.watch(tmdbServiceProvider);

  // 1. Anime mode or Anime media type selection
  if (filters.mediaType == 'anime') {
    final titleLang = ref.watch(animeTitleLanguageProvider);
    final anilist = ref.watch(anilistRepositoryProvider);
    final animeList = await anilist.fetchSection(
      'trending',
      genre: filters.selectedGenre?.name,
      year: filters.selectedYear,
      minRating: filters.minRating,
      titleLang: titleLang,
    );
    if (animeList.isNotEmpty) return animeList;
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
          ),
        );
      }

      final results = await Future.wait(futures);
      for (final list in results) {
        tmdbItems.addAll(list);
      }
    } catch (_) {
      // Gracefully continue to provider catalog
    }
  }

  // 2. Fetch Native Provider content for independence & offline resilience
  final providerItems = <MultimediaItem>[];
  if (activeProvider != null) {
    try {
      final homeCategories = await activeProvider.getHome();
      for (final entry in homeCategories.entries) {
        final categoryName = entry.key.toLowerCase();
        final items = entry.value;

        for (final item in items) {
          // Filter by mediaType
          if (filters.mediaType == 'movie' &&
              item.contentType == MultimediaContentType.series) {
            continue;
          }
          if (filters.mediaType == 'series' &&
              item.contentType == MultimediaContentType.movie) {
            continue;
          }

          // Filter by genre if selected
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

          // Filter by year if selected
          if (filters.selectedYear != null) {
            final yearStr = '${filters.selectedYear}';
            if (!item.releaseDate.contains(yearStr) &&
                !(item.description ?? '').contains(yearStr)) {
              continue;
            }
          }

          providerItems.add(item);
        }
      }
    } catch (_) {
      // Non-fatal
    }
  }

  // 3. Blend & Deduplicate
  final seenTitles = <String>{};
  final combined = <MultimediaItem>[];

  // TMDB items first if available (rich metadata), followed by direct provider items
  for (final item in [...tmdbItems, ...providerItems]) {
    final key = item.title.trim().toLowerCase();
    if (key.isNotEmpty && seenTitles.add(key)) {
      combined.add(item);
    }
  }

  // 4. Sort results
  if (filters.sortBy == 'rating') {
    combined.sort((a, b) => b.voteAverage.compareTo(a.voteAverage));
  } else if (filters.sortBy == 'newest') {
    combined.sort((a, b) => b.releaseDate.compareTo(a.releaseDate));
  } else if (filters.sortBy == 'title') {
    combined.sort(
      (a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()),
    );
  }

  return combined;
});
