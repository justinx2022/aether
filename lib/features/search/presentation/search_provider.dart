import 'dart:async';
import 'dart:io' as io;

import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:dio/dio.dart';

import '../../../../core/extensions/extension_manager.dart';
import '../../../../core/extensions/base_provider.dart';
import '../../../../core/domain/entity/multimedia_item.dart';
import '../../../../core/utils/fuzzy_matcher.dart';
import '../../explore/data/explore_tmdb_provider.dart';
import '../../settings/presentation/general_settings_provider.dart';
import 'search_history_provider.dart';

part 'search_provider.g.dart';

enum SearchFilter { content, live }

class ProviderSearchResult {
  final String providerId;
  final String providerName;
  final List<MultimediaItem> results;
  final String? error;

  ProviderSearchResult({
    required this.providerId,
    required this.providerName,
    required this.results,
    this.error,
  });
}

class SearchAggregateState {
  final List<ProviderSearchResult> results;
  final bool isLoading;

  const SearchAggregateState({this.results = const [], this.isLoading = false});
}

// ---------------------------------------------------------------------------
// Background isolate helper — runs title filtering off the main thread.
// ---------------------------------------------------------------------------
class _FilterParams {
  final List<MultimediaItem> items;
  final String query;
  final bool smartFuzzy;
  const _FilterParams(this.items, this.query, {this.smartFuzzy = true});
}

List<MultimediaItem> _filterItems(_FilterParams params) {
  final query = params.query.trim();
  if (query.isEmpty) return params.items;

  final scored = <(MultimediaItem, int)>[];
  for (final item in params.items) {
    final score = params.smartFuzzy
        ? FuzzyMatcher.matchScore(item.title, query)
        : (item.title.toLowerCase().contains(query.toLowerCase()) ? 100 : 0);
    if (score > 0) {
      scored.add((item, score));
    }
  }
  // Sort descending by relevance score (highest score first)
  scored.sort((a, b) => b.$2.compareTo(a.$2));
  return scored.map((e) => e.$1).toList();
}

Stream<SearchAggregateState> searchAllProviders(
  Ref ref,
  String query,
  ExtensionManager manager, {
  required SearchFilter filter,
  required bool Function() isCancelled,
}) async* {
  final allProviders = manager.getAllProviders();
  final providers = allProviders.where((p) {
    final isLiveOnly =
        p.supportedTypes.isNotEmpty &&
        p.supportedTypes.every((t) => t == ProviderType.livestream);
    return filter == SearchFilter.live ? isLiveOnly : !isLiveOnly;
  }).toList();
  debugPrint(
    '[SEARCH DBG] searchAllProviders called: query="$query", providers=${providers.length}, cancelled=${isCancelled()}',
  );

  if (query.isEmpty || providers.isEmpty) {
    yield const SearchAggregateState(results: [], isLoading: false);
    return;
  }

  yield const SearchAggregateState(results: [], isLoading: true);

  final results = <ProviderSearchResult>[];
  final smartFuzzy = ref.read(generalSettingsProvider).smartFuzzySearch;

  final controller = StreamController<SearchAggregateState>();

  // Semaphore sizing based on hardware
  int getSemaphoreSize() {
    int maxSlots = 8;
    try {
      final cores = io.Platform.numberOfProcessors;
      if (io.Platform.isMacOS || io.Platform.isWindows || io.Platform.isLinux) {
        maxSlots = 32;
      } else {
        // Mobile: eval burst queue serializes HTTP callbacks, but CF bypass
        // WebView GPU init is still expensive — cap at 8 to avoid triggering
        // too many concurrent CF solves while the spawn semaphore queues them.
        maxSlots = (cores).clamp(4, 8);
      }
    } catch (_) {}
    return maxSlots;
  }

  final maxSlots = getSemaphoreSize();
  int activeJobs = 0;

  // Livestream-only providers (large M3U playlists) are deprioritized to the
  // back of the queue. They still run and IPTV channel searches work; we just
  // let movie/series providers finish their burst first to reduce peak jank.
  final sortedProviders = List<AetherProvider>.from(providers)
    ..sort((a, b) {
      final aLiveOnly =
          a.supportedTypes.isNotEmpty &&
          a.supportedTypes.every((t) => t == ProviderType.livestream);
      final bLiveOnly =
          b.supportedTypes.isNotEmpty &&
          b.supportedTypes.every((t) => t == ProviderType.livestream);
      if (aLiveOnly == bLiveOnly) return 0;
      return aLiveOnly ? 1 : -1;
    });
  final queue = List<AetherProvider>.from(sortedProviders);
  final List<CancelToken> activeTokens = [];
  final List<AetherProvider> activeProviders = [];
  bool isCompleted = false;

  Timer? throttleTimer;
  bool pendingEmit = false;
  // Track what was last emitted so we skip rebuilds when nothing new arrived.
  int lastEmittedResultCount = 0;

  void doEmit({bool force = false}) {
    if (controller.isClosed || isCancelled()) {
      return;
    }
    final stillLoading = queue.isNotEmpty || activeJobs > 0;
    // Skip the rebuild if no new results have arrived since the last emit
    // (e.g. a batch of providers all returned empty). Always emit on the
    // final event so isLoading flips to false.
    if (!force && stillLoading && results.length == lastEmittedResultCount) {
      pendingEmit = false;
      return;
    }
    lastEmittedResultCount = results.length;
    final totalItems = results.fold<int>(0, (sum, r) => sum + r.results.length);
    debugPrint(
      '[SEARCH DBG] doEmit — ${results.length} providers, $totalItems items, loading=$stillLoading',
    );
    controller.add(
      SearchAggregateState(
        results: List.from(results),
        isLoading: stillLoading,
      ),
    );
    pendingEmit = false;
  }

  void scheduleEmit({bool force = false}) {
    if (isCancelled() || controller.isClosed) return;

    if (force) {
      throttleTimer?.cancel();
      throttleTimer = null;
      doEmit(force: true);
      return;
    }

    pendingEmit = true;
    // Mobile gets a wider throttle window to reduce rebuild frequency
    // during high-concurrency search phases (70 providers).
    final throttleDuration = (io.Platform.isAndroid || io.Platform.isIOS)
        ? const Duration(milliseconds: 500)
        : const Duration(milliseconds: 150);
    throttleTimer ??= Timer(throttleDuration, () {
      throttleTimer = null;
      if (pendingEmit) doEmit();
    });
  }

  void processNext() {
    if (isCancelled()) {
      for (final t in activeTokens) {
        if (!t.isCancelled) t.cancel('Search cancelled');
      }
      activeTokens.clear();
      // Drop any IIFE evals still waiting in the JS queue for active providers.
      for (final p in activeProviders) {
        p.cancelInit();
      }
      activeProviders.clear();
      return;
    }

    // Fill up to max slots
    while (activeJobs < maxSlots && queue.isNotEmpty) {
      final provider = queue.removeAt(0);
      activeJobs++;
      final token = CancelToken();
      activeTokens.add(token);
      activeProviders.add(provider);

      Future(() async {
        if (isCancelled() || token.isCancelled) {
          debugPrint(
            '[SEARCH DBG] SKIP ${provider.packageName} — cancelled before start',
          );
          return;
        }

        try {
          debugPrint('[SEARCH DBG] START ${provider.packageName}');
          final rawResults = await provider.search(query, cancelToken: token);
          debugPrint(
            '[SEARCH DBG] DONE ${provider.packageName} — rawResults=${rawResults.length}',
          );
          if (isCancelled() || token.isCancelled) {
            debugPrint(
              '[SEARCH DBG] CANCELLED after search ${provider.packageName}',
            );
            return;
          }

          final providerItems = rawResults
              .map(
                (item) => MultimediaItem(
                  title: item.title,
                  url: item.url,
                  posterUrl: item.posterUrl,
                  bannerUrl: item.bannerUrl,
                  description: item.description,
                  contentType: item.contentType,
                  episodes: item.episodes,
                  provider: provider.packageName,
                ),
              )
              .toList();

          // For small result sets, skip the compute() isolate overhead
          // (spawn + serialize + deserialize costs more than the filter work).
          final filtered = providerItems.length < 30
              ? _filterItems(_FilterParams(providerItems, query, smartFuzzy: smartFuzzy))
              : await compute(
                  _filterItems,
                  _FilterParams(providerItems, query, smartFuzzy: smartFuzzy),
                );
          debugPrint(
            '[SEARCH DBG] FILTERED ${provider.packageName} — ${filtered.length}/${providerItems.length} items',
          );

          if (isCancelled() || token.isCancelled) {
            debugPrint(
              '[SEARCH DBG] CANCELLED after filter ${provider.packageName}',
            );
            return;
          }

          // Only add to state when there are actual results — empty entries
          // grow the list, force larger List.from() copies in doEmit, and
          // cause needless ListView rebuilds for no visual change.
          if (filtered.isNotEmpty) {
            results.add(
              ProviderSearchResult(
                providerId: provider.packageName,
                providerName: provider.name,
                results: filtered,
              ),
            );
            debugPrint(
              '[SEARCH DBG] ADDED ${provider.packageName} — total results sets=${results.length}',
            );
          }
        } catch (e) {
          debugPrint('[SEARCH DBG] ERROR ${provider.packageName}: $e');
          if (isCancelled() || token.isCancelled) {
            debugPrint(
              '[SEARCH DBG] CANCELLED during error ${provider.packageName}',
            );
            return;
          }
          if (e is DioException && e.type == DioExceptionType.cancel) return;
          // Don't add error entries with empty results — they add state size
          // with no user-visible benefit.
        } finally {
          activeJobs--;
          activeTokens.remove(token);
          activeProviders.remove(provider);

          final isLast = activeJobs == 0 && queue.isEmpty;
          debugPrint(
            '[SEARCH DBG] FINALLY ${provider.packageName} — activeJobs=$activeJobs, queueLeft=${queue.length}, isLast=$isLast, cancelled=${isCancelled()}, controllerClosed=${controller.isClosed}',
          );
          scheduleEmit(force: isLast);

          if (isLast && !isCompleted) {
            isCompleted = true;
            debugPrint(
              '[SEARCH DBG] ALL DONE — total result sets=${results.length}',
            );
            manager.runGC();
            if (!controller.isClosed) {
              unawaited(
                Future.microtask(() {
                  if (!controller.isClosed) controller.close();
                }),
              );
            }
          } else if (!isCancelled()) {
            processNext();
          }
        }
      });
    }
  }

  processNext();

  yield* controller.stream;
}

@Riverpod(keepAlive: true)
class SearchQuery extends _$SearchQuery {
  @override
  String build() => '';

  void set(String query) => state = query;
}

@Riverpod(keepAlive: true)
class SearchFilterNotifier extends _$SearchFilterNotifier {
  @override
  SearchFilter build() => SearchFilter.content;

  void set(SearchFilter filter) => state = filter;
}

@Riverpod(keepAlive: true)
Stream<SearchAggregateState> searchResults(Ref ref) {
  final query = ref.watch(searchQueryProvider);
  final filter = ref.watch(searchFilterProvider);
  final manager = ref.read(extensionManagerProvider.notifier);

  debugPrint('[SEARCH DBG] searchResults PROVIDER BUILT — query="$query"');

  var cancelled = false;
  ref.onDispose(() {
    debugPrint('[SEARCH DBG] searchResults DISPOSED — query="$query"');
    cancelled = true;
  });

  return searchAllProviders(
    ref,
    query,
    manager,
    filter: filter,
    isCancelled: () => cancelled,
  );
}

class SearchSuggestionState {
  final List<String> suggestions;
  final bool isLoading;
  final String query;

  const SearchSuggestionState({
    this.suggestions = const [],
    this.isLoading = false,
    this.query = '',
  });

  SearchSuggestionState copyWith({
    List<String>? suggestions,
    bool? isLoading,
    String? query,
  }) {
    return SearchSuggestionState(
      suggestions: suggestions ?? this.suggestions,
      isLoading: isLoading ?? this.isLoading,
      query: query ?? this.query,
    );
  }
}

@riverpod
class SearchSuggestionController extends _$SearchSuggestionController {
  Timer? _debounce;
  bool _isDisposed = false;

  @override
  SearchSuggestionState build() {
    _isDisposed = false;
    ref.onDispose(() {
      _isDisposed = true;
      _debounce?.cancel();
    });
    return const SearchSuggestionState();
  }

  void onQueryChanged(String query) {
    if (query == state.query) return;

    final trimmed = query.trim();
    if (trimmed.length < 2) {
      _debounce?.cancel();
      state = state.copyWith(
        query: query,
        suggestions: const [],
        isLoading: false,
      );
      return;
    }

    state = state.copyWith(query: query, isLoading: true);

    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () async {
      if (_isDisposed) return;
      try {
        if (_isDisposed) return;
        final tmdb = ref.read(tmdbServiceProvider);
        final history = ref.read(searchHistoryProvider);
        final fuzzyHistory = matchingSearchHistory(history, query, limit: 5);

        List<String> tmdbSuggestions = const [];
        try {
          tmdbSuggestions = await tmdb.getSuggestions(
            query: query,
            language: 'en-US',
          );
        } catch (_) {}

        if (_isDisposed) return;
        final combined = <String>{...fuzzyHistory, ...tmdbSuggestions}.toList();
        combined.sort((a, b) => FuzzyMatcher.matchScore(b, query)
            .compareTo(FuzzyMatcher.matchScore(a, query)));

        if (!_isDisposed && state.query == query) {
          state = state.copyWith(
            suggestions: combined.take(10).toList(),
            isLoading: false,
          );
        }
      } catch (_) {
        if (!_isDisposed && state.query == query) {
          state = state.copyWith(suggestions: const [], isLoading: false);
        }
      }
    });
  }

  void clear() {
    _debounce?.cancel();
    if (!_isDisposed) {
      state = const SearchSuggestionState();
    }
  }
}
