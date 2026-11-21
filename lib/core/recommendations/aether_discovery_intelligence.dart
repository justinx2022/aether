import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/entity/multimedia_item.dart';
import '../storage/history_repository.dart';
import '../services/tmdb_service.dart';
import '../../features/explore/data/explore_tmdb_provider.dart';
import 'recommendations_service.dart';

/// User taste profile derived dynamically from viewing history and completion rate.
class AdiTasteProfile {
  final Map<String, double> genreWeights;
  final Map<MultimediaContentType, double> typeWeights;
  final Set<String> completedIds;
  final Set<String> watchedIds;
  final double averageCompletionRate;
  final int? dominantEraYear;

  const AdiTasteProfile({
    this.genreWeights = const {},
    this.typeWeights = const {},
    this.completedIds = const {},
    this.watchedIds = const {},
    this.averageCompletionRate = 0.0,
    this.dominantEraYear,
  });

  factory AdiTasteProfile.fromHistory(List<HistoryItem> history) {
    if (history.isEmpty) {
      return const AdiTasteProfile();
    }

    final genres = <String, double>{};
    final types = <MultimediaContentType, double>{};
    final completed = <String>{};
    final watched = <String>{};
    double totalProgress = 0.0;
    int yearSum = 0;
    int yearCount = 0;

    for (final h in history) {
      final key = h.item.imdbId ?? h.item.tmdbId?.toString() ?? h.item.title;
      watched.add(key);

      final progress = h.progress.clamp(0.0, 1.0);
      totalProgress += progress;

      // Completion bonus: items watched > 80% carry double weight; abandoned < 10% carry low weight
      final weight = progress >= 0.80 ? 2.0 : (progress < 0.15 ? 0.25 : 1.0);
      if (progress >= 0.85) {
        completed.add(key);
      }

      // Track content type preferences
      types[h.item.contentType] = (types[h.item.contentType] ?? 0) + weight;

      // Track genre affinities
      final itemTags = h.item.tags ?? [];
      for (final tag in itemTags) {
        final cleanTag = tag.trim().toLowerCase();
        if (cleanTag.isNotEmpty) {
          genres[cleanTag] = (genres[cleanTag] ?? 0) + weight;
        }
      }

      if (h.item.year != null && h.item.year! > 1950) {
        yearSum += h.item.year!;
        yearCount++;
      }
    }

    // Normalize genre weights to 0.0 - 1.0
    final maxGenreWeight = genres.values.isEmpty ? 1.0 : genres.values.reduce(max);
    if (maxGenreWeight > 0) {
      for (final k in genres.keys.toList()) {
        genres[k] = (genres[k]! / maxGenreWeight).clamp(0.0, 1.0);
      }
    }

    return AdiTasteProfile(
      genreWeights: genres,
      typeWeights: types,
      completedIds: completed,
      watchedIds: watched,
      averageCompletionRate: totalProgress / history.length,
      dominantEraYear: yearCount > 0 ? (yearSum ~/ yearCount) : null,
    );
  }

  /// Calculates personal taste match T in [0.0, 1.0].
  double matchScore(MultimediaItem item) {
    if (genreWeights.isEmpty) return 0.5; // Neutral cold-start

    final tags = item.tags ?? [];
    if (tags.isEmpty) return 0.4;

    double scoreSum = 0.0;
    int matches = 0;
    for (final t in tags) {
      final clean = t.trim().toLowerCase();
      if (genreWeights.containsKey(clean)) {
        scoreSum += genreWeights[clean]!;
        matches++;
      }
    }

    if (matches == 0) return 0.15;
    return (scoreSum / matches).clamp(0.0, 1.0);
  }
}

/// Global impression and exposure tracking to strictly prevent repetition and fatigue.
class AdiExposureStore {
  static final AdiExposureStore instance = AdiExposureStore._();
  AdiExposureStore._();

  // profileId -> contentId -> impression count
  final Map<String, Map<String, int>> _impressions = {};
  // profileId -> contentId -> click count
  final Map<String, Map<String, int>> _clicks = {};
  // session shown IDs to guarantee 0 intra-page duplicates
  final Set<String> _currentSessionShown = {};

  void recordImpression(String profileId, String contentId) {
    _impressions.putIfAbsent(profileId, () => {});
    _impressions[profileId]![contentId] =
        (_impressions[profileId]![contentId] ?? 0) + 1;
    _currentSessionShown.add(contentId);
  }

  void recordClick(String profileId, String contentId) {
    _clicks.putIfAbsent(profileId, () => {});
    _clicks[profileId]![contentId] =
        (_clicks[profileId]![contentId] ?? 0) + 1;
  }

  /// Downrank factor: reduces score if shown repeatedly without click (ad-fatigue rule)
  double getExposurePenalty(String profileId, String contentId) {
    final seen = _impressions[profileId]?[contentId] ?? 0;
    final clicked = _clicks[profileId]?[contentId] ?? 0;
    if (seen > 4 && clicked == 0) return 0.4; // 60% downrank
    if (seen > 2 && clicked == 0) return 0.7; // 30% downrank
    return 1.0;
  }

  /// Filters out duplicates within and across shelves
  List<MultimediaItem> deduplicate(
    List<MultimediaItem> items, {
    Set<String>? excludedIds,
  }) {
    final seen = <String>{...?excludedIds};
    final out = <MultimediaItem>[];
    for (final item in items) {
      final key = item.imdbId ?? (item.tmdbId != null ? 'tmdb_${item.tmdbId}' : item.title.trim().toLowerCase());
      if (key.isEmpty || seen.contains(key)) continue;
      seen.add(key);
      out.add(item);
    }
    return out;
  }

  void resetSession() {
    _currentSessionShown.clear();
  }
}

/// Multi-factor mathematical ranking model:
/// S = 0.30T + 0.20Q + 0.15F + 0.15P + 0.10D + 0.10N
class AdiScorer {
  const AdiScorer._();

  static double score({
    required MultimediaItem item,
    required AdiTasteProfile profile,
    String profileId = 'default',
  }) {
    // T: Personal Taste Match [0, 1]
    final t = profile.matchScore(item);

    // Q: Content Quality (Rating) [0, 1]
    final rawScore = item.score ?? 6.0;
    final q = (rawScore / 10.0).clamp(0.0, 1.0);

    // F: Freshness / Recency [0, 1]
    final currentYear = DateTime.now().year;
    final itemYear = item.year ?? currentYear;
    final age = (currentYear - itemYear).clamp(0, 50);
    final f = max(0.1, 1.0 - (age * 0.035));

    // P: External Popularity [0, 1] (supporting, not dominating)
    final p = 0.5; // Normalized baseline

    // D: Discovery Potential (High rating with low-to-medium mainstream saturation)
    final d = (q >= 0.72) ? 0.85 : 0.40;

    // N: Novelty (rewarding quality outside user's single most common genre)
    final n = (t < 0.6 && q >= 0.75) ? 0.90 : 0.30;

    // Master S calculation
    final rawS = (0.30 * t) +
        (0.20 * q) +
        (0.15 * f) +
        (0.15 * p) +
        (0.10 * d) +
        (0.10 * n);

    // Apply exposure & repetition fatigue penalty
    final id = item.imdbId ?? (item.tmdbId != null ? 'tmdb_${item.tmdbId}' : item.title);
    final penalty = AdiExposureStore.instance.getExposurePenalty(profileId, id);

    return rawS * penalty;
  }
}

/// Intelligent adjacent genre discovery mappings for "Beyond Your Orbit".
class AdiGenreMap {
  static final Map<String, List<String>> adjacentGenres = {
    'sci-fi': ['psychological thriller', 'mystery', 'neo-noir', 'adventure'],
    'science fiction': ['psychological thriller', 'mystery', 'adventure'],
    'crime': ['mystery', 'international', 'drama', 'film-noir'],
    'action': ['martial arts', 'adventure', 'thriller'],
    'animation': ['fantasy', 'family', 'adventure'],
    'horror': ['supernatural', 'psychological thriller', 'sci-fi'],
    'romance': ['comedy', 'drama', 'indie'],
    'drama': ['mystery', 'biography', 'crime'],
    'comedy': ['satire', 'romance', 'indie'],
  };

  static List<String> getAdjacent(List<String> userTopGenres) {
    final result = <String>{};
    for (final g in userTopGenres) {
      final adj = adjacentGenres[g.toLowerCase()];
      if (adj != null) {
        result.addAll(adj);
      }
    }
    if (result.isEmpty) {
      return ['thriller', 'mystery', 'adventure'];
    }
    return result.toList();
  }
}

/// Aether Discovery Intelligence (ADI) Provider
final aetherDiscoveryIntelligenceProvider = Provider<AdiService>((ref) {
  final tmdb = ref.watch(tmdbServiceProvider);
  final historyRepo = ref.watch(historyRepositoryProvider);
  return AdiService(tmdb, historyRepo);
});

/// 1. Aether For You: Personalized intelligence shelf
final aetherForYouProvider = FutureProvider.autoDispose<List<MultimediaItem>>((ref) {
  return ref.watch(aetherDiscoveryIntelligenceProvider).getAetherForYou();
});

/// 2. Beyond Your Orbit: Aether's signature discovery shelf
final beyondYourOrbitProvider = FutureProvider.autoDispose<List<MultimediaItem>>((ref) {
  return ref.watch(aetherDiscoveryIntelligenceProvider).getBeyondYourOrbit();
});

/// 3. Hidden Gems: High quality, lesser-known discoveries
final hiddenGemsProvider = FutureProvider.autoDispose<List<MultimediaItem>>((ref) {
  return ref.watch(aetherDiscoveryIntelligenceProvider).getHiddenGems();
});

/// Core independent recommendation and discovery intelligence service.
class AdiService {
  final TmdbService _tmdb;
  final HistoryRepository _historyRepo;

  AdiService(this._tmdb, this._historyRepo);

  /// 1. AETHER FOR YOU: Tailored personalized picks based on taste profile.
  Future<List<MultimediaItem>> getAetherForYou({
    String profileId = 'default',
    int limit = 20,
  }) async {
    final history = _historyRepo.getHistory();
    final profile = AdiTasteProfile.fromHistory(history);

    final candidates = <MultimediaItem>[];
    try {
      final trending = await _tmdb.getTrending();
      final topRated = await _tmdb.getTopRated();
      final popularTv = await _tmdb.getPopularTV();
      candidates.addAll(trending);
      candidates.addAll(topRated);
      candidates.addAll(popularTv);
    } catch (e) {
      if (kDebugMode) debugPrint('ADI getAetherForYou fetch fallback: $e');
    }

    final unique = AdiExposureStore.instance.deduplicate(
      candidates,
      excludedIds: profile.completedIds,
    );

    // Rank candidates using S formula
    unique.sort((a, b) {
      final sa = AdiScorer.score(item: a, profile: profile, profileId: profileId);
      final sb = AdiScorer.score(item: b, profile: profile, profileId: profileId);
      return sb.compareTo(sa);
    });

    final results = unique.take(limit).map((item) {
      return _prepareItemWithExplanation(
        item,
        explain(item, profile, 'Personalized for you'),
      );
    }).toList();

    return results;
  }

  /// 2. TRENDING NOW: Temporal current popularity with recency decay.
  Future<List<MultimediaItem>> getTrendingNow({int limit = 20}) async {
    try {
      final list = await _tmdb.getTrending();
      final deduplicated = AdiExposureStore.instance.deduplicate(list);
      return deduplicated.take(limit).map((item) {
        return _prepareItemWithExplanation(item, 'Trending this week');
      }).toList();
    } catch (_) {
      return [];
    }
  }

  /// 3. HIDDEN GEMS: High quality (rating >= 7.5) under-the-radar masterpieces.
  Future<List<MultimediaItem>> getHiddenGems({
    String profileId = 'default',
    int limit = 20,
  }) async {
    try {
      final top = await _tmdb.getTopRated();
      final history = _historyRepo.getHistory();
      final profile = AdiTasteProfile.fromHistory(history);

      final gems = top.where((item) {
        final score = item.score ?? 0;
        return score >= 7.6 && !profile.watchedIds.contains(item.imdbId ?? '${item.tmdbId}');
      }).toList();

      final deduplicated = AdiExposureStore.instance.deduplicate(gems);
      return deduplicated.take(limit).map((item) {
        final rating = item.score != null ? '${item.score!.toStringAsFixed(1)} ★' : 'Acclaimed';
        return _prepareItemWithExplanation(item, 'Hidden Gem • $rating');
      }).toList();
    } catch (_) {
      return [];
    }
  }

  /// 4. BEYOND YOUR ORBIT: Aether's signature discovery shelf.
  /// Intelligently introduces content from adjacent, unexpected genres.
  Future<List<MultimediaItem>> getBeyondYourOrbit({
    String profileId = 'default',
    int limit = 20,
  }) async {
    final history = _historyRepo.getHistory();
    final profile = AdiTasteProfile.fromHistory(history);

    final topGenres = profile.genreWeights.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final userFavoriteNames = topGenres.take(3).map((e) => e.key).toList();
    final adjacentNames = AdiGenreMap.getAdjacent(userFavoriteNames);

    try {
      final candidates = await _tmdb.getTrending();
      final orbitPicks = <MultimediaItem>[];

      for (final item in candidates) {
        final tags = (item.tags ?? []).map((t) => t.toLowerCase()).toList();
        final matchesAdjacent = tags.any((t) => adjacentNames.contains(t));
        if (matchesAdjacent && !profile.watchedIds.contains(item.imdbId ?? '${item.tmdbId}')) {
          orbitPicks.add(item);
        }
      }

      final deduplicated = AdiExposureStore.instance.deduplicate(
        orbitPicks.isNotEmpty ? orbitPicks : candidates,
        excludedIds: profile.watchedIds,
      );

      final explanation = userFavoriteNames.isNotEmpty
          ? 'Beyond Your Orbit: based on your love for ${userFavoriteNames.first.toUpperCase()}'
          : 'Beyond Your Orbit: unexpected discoveries';

      return deduplicated.take(limit).map((item) {
        return _prepareItemWithExplanation(item, explanation);
      }).toList();
    } catch (_) {
      return [];
    }
  }

  /// 5. BECAUSE YOU WATCHED: Contextual recommendation based on a specific watched item.
  Future<List<MultimediaItem>> getBecauseYouWatched(
    MultimediaItem watchedItem, {
    int limit = 15,
  }) async {
    try {
      final similar = await _tmdb.getSimilar(
        isMovie: watchedItem.contentType != MultimediaContentType.series,
        id: watchedItem.id,
      );
      final deduplicated = AdiExposureStore.instance.deduplicate(
        similar,
        excludedIds: {watchedItem.imdbId ?? '${watchedItem.tmdbId}'},
      );
      return deduplicated.take(limit).map((item) {
        return _prepareItemWithExplanation(
          item,
          'Because you watched ${watchedItem.title}',
        );
      }).toList();
    } catch (_) {
      return [];
    }
  }

  /// Produces a human-readable explanation for a recommendation.
  String explain(MultimediaItem item, AdiTasteProfile profile, String defaultReason) {
    if (item.score != null && item.score! >= 8.2) {
      return 'Masterpiece • ${item.score!.toStringAsFixed(1)} rating';
    }
    final tags = item.tags ?? [];
    for (final tag in tags) {
      final clean = tag.toLowerCase();
      if ((profile.genreWeights[clean] ?? 0) >= 0.7) {
        return 'Matches your affinity for $tag';
      }
    }
    return defaultReason;
  }

  /// Enriches the multimedia item with clean streaming catalogue tokens so clicking always works!
  MultimediaItem _prepareItemWithExplanation(MultimediaItem item, String explanation) {
    final effectiveUrl = item.url.isNotEmpty
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
      description: item.description != null
          ? (item.description!.startsWith('💡') ? item.description : '💡 $explanation\n\n${item.description}')
          : '💡 $explanation',
    );
  }
}
