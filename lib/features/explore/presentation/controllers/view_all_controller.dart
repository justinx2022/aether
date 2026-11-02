import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/domain/entity/multimedia_item.dart';
import '../../data/explore_tmdb_provider.dart';
import '../../data/explore_language_provider.dart';
import '../../data/explore_filter_provider.dart';
import '../view_all_screen.dart'; // for ViewAllCategory

part 'view_all_controller.g.dart';

class ViewAllState {
  final ViewAllCategory? category;
  final List<MultimediaItem> items;
  final int page;
  final bool isLoading;
  final bool hasMore;

  const ViewAllState({
    this.category,
    this.items = const [],
    this.page = 1,
    this.isLoading = false,
    this.hasMore = true,
  });

  ViewAllState copyWith({
    ViewAllCategory? category,
    List<MultimediaItem>? items,
    int? page,
    bool? isLoading,
    bool? hasMore,
  }) {
    return ViewAllState(
      category: category ?? this.category,
      items: items ?? this.items,
      page: page ?? this.page,
      isLoading: isLoading ?? this.isLoading,
      hasMore: hasMore ?? this.hasMore,
    );
  }
}

@riverpod
class ViewAllController extends _$ViewAllController {
  int _providerGeneration = 0;

  @override
  ViewAllState build(ViewAllCategory category) {
    ref.watch(languageProvider);
    ref.watch(exploreFilterProvider);
    return ViewAllState(category: category);
  }

  void init(
    List<MultimediaItem> initialItems, {
    bool supportsPagination = false,
  }) {
    if (category == ViewAllCategory.providerContent) {
      _providerGeneration++;
      state = ViewAllState(
        category: category,
        items: List.from(initialItems),
        page: 1,
        hasMore: supportsPagination,
      );
      return;
    }
    if (state.items.isEmpty && state.page == 1) {
      state = state.copyWith(items: List.from(initialItems));
    }
  }

  Future<void> fetchNextPage({
    Future<List<MultimediaItem>?> Function(int page, int offset)?
    providerLoader,
  }) async {
    if (state.isLoading || !state.hasMore) return;

    state = state.copyWith(isLoading: true);
    final providerGeneration = _providerGeneration;

    try {
      final tmdbService = ref.read(tmdbServiceProvider);
      final lang = ref.read(languageProvider);
      final filters = ref.read(exploreFilterProvider);
      final bool isEmpty = state.items.isEmpty;
      final nextPage = isEmpty ? 1 : state.page + 1;
      List<MultimediaItem> newItems = [];

      switch (category) {
        case ViewAllCategory.popularMovies:
          newItems = await tmdbService.getPopularMovies(
            language: lang,
            genreId: filters.selectedGenre?.id,
            year: filters.selectedYear,
            minRating: filters.minRating,
            page: nextPage,
          );
          break;
        case ViewAllCategory.popularTV:
          newItems = await tmdbService.getPopularTV(
            language: lang,
            genreId: filters.selectedGenre?.id,
            year: filters.selectedYear,
            minRating: filters.minRating,
            page: nextPage,
          );
          break;
        case ViewAllCategory.nowPlayingMovies:
          newItems = await tmdbService.getNowPlayingMovies(
            language: lang,
            genreId: filters.selectedGenre?.id,
            year: filters.selectedYear,
            minRating: filters.minRating,
            page: nextPage,
          );
          break;
        case ViewAllCategory.onTheAirTV:
          newItems = await tmdbService.getOnTheAirTV(
            language: lang,
            genreId: filters.selectedGenre?.id,
            year: filters.selectedYear,
            minRating: filters.minRating,
            page: nextPage,
          );
          break;
        case ViewAllCategory.topRatedMovies:
          newItems = await tmdbService.getTopRated(
            language: lang,
            genreId: filters.selectedGenre?.id,
            year: filters.selectedYear,
            minRating: filters.minRating,
            page: nextPage,
          );
          break;
        case ViewAllCategory.topRatedTV:
          newItems = await tmdbService.getTopRatedTV(
            language: lang,
            genreId: filters.selectedGenre?.id,
            year: filters.selectedYear,
            minRating: filters.minRating,
            page: nextPage,
          );
          break;
        case ViewAllCategory.airingTodayTV:
          newItems = await tmdbService.getAiringTodayTV(
            language: lang,
            genreId: filters.selectedGenre?.id,
            year: filters.selectedYear,
            minRating: filters.minRating,
            page: nextPage,
          );
          break;
        case ViewAllCategory.trending:
          newItems = await tmdbService.getTrending(
            language: lang,
            genreId: filters.selectedGenre?.id,
            year: filters.selectedYear,
            minRating: filters.minRating,
            page: nextPage,
          );
          break;
        case ViewAllCategory.trendingTV:
          newItems = await tmdbService.getTrendingTV(
            language: lang,
            genreId: filters.selectedGenre?.id,
            year: filters.selectedYear,
            minRating: filters.minRating,
            page: nextPage,
          );
          break;
        case ViewAllCategory.providerContent:
          final loader = providerLoader;
          if (loader == null) {
            state = state.copyWith(hasMore: false, isLoading: false);
            return;
          }
          final fetched = await loader(nextPage, state.items.length);
          if (!ref.mounted || providerGeneration != _providerGeneration) return;
          if (fetched == null) {
            state = state.copyWith(hasMore: false, isLoading: false);
            return;
          }
          final existingUrls = state.items.map((item) => item.url).toSet();
          newItems = fetched
              .where((item) => existingUrls.add(item.url))
              .toList(growable: false);
          if (newItems.isEmpty) {
            state = state.copyWith(hasMore: false, isLoading: false);
            return;
          }
          state = state.copyWith(
            items: [...state.items, ...newItems],
            page: nextPage,
            isLoading: false,
          );
          return;
      }

      if (newItems.isEmpty) {
        state = state.copyWith(hasMore: false, isLoading: false);
      } else {
        state = state.copyWith(
          items: [...state.items, ...newItems],
          page: nextPage,
          isLoading: false,
        );
      }
    } catch (e) {
      if (!ref.mounted) return;
      state = state.copyWith(isLoading: false);
    }
  }
}
