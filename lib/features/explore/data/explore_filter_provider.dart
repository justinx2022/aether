import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/models/tmdb_genre.dart';

part 'explore_filter_provider.g.dart';

class FilterState {
  final TmdbGenre? selectedGenre; // {id: 123, name: 'Action'}
  final int? selectedYear;
  final double? minRating;
  final String mediaType; // 'all', 'movie', 'series', 'anime'
  final String? selectedCountry; // 'US', 'GB', 'KR', 'JP', etc.
  final String sortBy; // 'popularity', 'rating', 'newest', 'title'

  const FilterState({
    this.selectedGenre,
    this.selectedYear,
    this.minRating,
    this.mediaType = 'all',
    this.selectedCountry,
    this.sortBy = 'popularity',
  });

  FilterState copyWith({
    TmdbGenre? selectedGenre,
    int? selectedYear,
    double? minRating,
    String? mediaType,
    String? selectedCountry,
    String? sortBy,
    bool clearGenre = false,
    bool clearYear = false,
    bool clearRating = false,
    bool clearCountry = false,
  }) {
    return FilterState(
      selectedGenre: clearGenre ? null : (selectedGenre ?? this.selectedGenre),
      selectedYear: clearYear ? null : (selectedYear ?? this.selectedYear),
      minRating: clearRating ? null : (minRating ?? this.minRating),
      mediaType: mediaType ?? this.mediaType,
      selectedCountry: clearCountry ? null : (selectedCountry ?? this.selectedCountry),
      sortBy: sortBy ?? this.sortBy,
    );
  }
}

@Riverpod(keepAlive: true)
class ExploreFilter extends _$ExploreFilter {
  @override
  FilterState build() => const FilterState();

  void setGenre(TmdbGenre? genre) {
    state = state.copyWith(selectedGenre: genre, clearGenre: genre == null);
  }

  void setYear(int? year) {
    state = state.copyWith(selectedYear: year, clearYear: year == null);
  }

  void setRating(double? rating) {
    state = state.copyWith(minRating: rating, clearRating: rating == null);
  }

  void setMediaType(String type) {
    state = state.copyWith(mediaType: type);
  }

  void setCountry(String? country) {
    state = state.copyWith(selectedCountry: country, clearCountry: country == null);
  }

  void setSortBy(String sort) {
    state = state.copyWith(sortBy: sort);
  }

  void clearAll() {
    state = const FilterState();
  }
}

@Riverpod(keepAlive: true)
class AnimeTitleLanguage extends _$AnimeTitleLanguage {
  @override
  String build() => 'english';

  void setLanguage(String lang) {
    state = lang;
  }
}
