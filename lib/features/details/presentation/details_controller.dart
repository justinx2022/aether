import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:collection/collection.dart';

import '../../../../core/domain/entity/multimedia_item.dart';
import '../../../../core/network/dio_client_provider.dart';
import '../../../core/extensions/base_provider.dart';
import '../../../core/extensions/extension_manager.dart';
import '../../../../core/storage/library_repository.dart';
import '../../../../core/storage/history_repository.dart';

import 'package:aether/core/storage/episode_watch_repository.dart';
import 'package:aether/core/storage/storage_service.dart';

import '../../library/presentation/library_provider.dart';
import '../../library/presentation/history_provider.dart';
import 'playback_launcher.dart';
import '../../../core/services/download_service.dart';
import '../data/metadata_resolution_service.dart';
import 'downloaded_file_provider.dart';
import '../../tracking/data/simkl_service.dart';
import '../../../core/services/stream_prewarmer.dart';

part 'details_controller.g.dart';

String episodeSelectionKey(Episode episode) {
  return [
    episode.season,
    episode.episode,
    episode.dubStatus.name,
    episode.url,
  ].join('|');
}

String _normalizedMediaTitle(String title) =>
    title.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

bool _compatibleSeriesType(MultimediaItem source, MultimediaItem candidate) {
  final sourceIsSeries =
      source.contentType == MultimediaContentType.series ||
      source.contentType == MultimediaContentType.anime;
  final candidateIsSeries =
      candidate.contentType == MultimediaContentType.series ||
      candidate.contentType == MultimediaContentType.anime;
  return sourceIsSeries == candidateIsSeries;
}

class DetailsState {
  final AsyncValue<MultimediaItem?> details;
  final Map<int, List<Episode>> seasonMap;
  final int selectedSeason;
  final bool isMovie;
  final MultimediaItem? item;
  final bool isLaunching;
  final Episode? targetEpisode;
  final bool isAscending;
  final int selectedRangeIndex;
  final DubStatus selectedDubStatus;
  final Set<String> selectedEpisodeKeys;

  const DetailsState({
    this.details = const AsyncLoading(),
    this.seasonMap = const {},
    this.selectedSeason = 1,
    this.isMovie = false,
    this.item,
    this.isLaunching = false,
    this.targetEpisode,
    this.isAscending = true,
    this.selectedRangeIndex = 0,
    this.selectedDubStatus = DubStatus.none,
    this.selectedEpisodeKeys = const <String>{},
  });

  DetailsState copyWith({
    AsyncValue<MultimediaItem?>? details,
    Map<int, List<Episode>>? seasonMap,
    int? selectedSeason,
    bool? isMovie,
    MultimediaItem? item,
    bool? isLaunching,
    Episode? targetEpisode,
    bool? isAscending,
    int? selectedRangeIndex,
    DubStatus? selectedDubStatus,
    Set<String>? selectedEpisodeKeys,
  }) {
    return DetailsState(
      details: details ?? this.details,
      seasonMap: seasonMap ?? this.seasonMap,
      selectedSeason: selectedSeason ?? this.selectedSeason,
      isMovie: isMovie ?? this.isMovie,
      item: item ?? this.item,
      isLaunching: isLaunching ?? this.isLaunching,
      targetEpisode: targetEpisode ?? this.targetEpisode,
      isAscending: isAscending ?? this.isAscending,
      selectedRangeIndex: selectedRangeIndex ?? this.selectedRangeIndex,
      selectedDubStatus: selectedDubStatus ?? this.selectedDubStatus,
      selectedEpisodeKeys: selectedEpisodeKeys ?? this.selectedEpisodeKeys,
    );
  }
}

@riverpod
class DetailsController extends _$DetailsController {
  @override
  DetailsState build(String itemUrl) {
    ref.listen(activeDownloadsProvider, (prev, next) {
      final details = state.details.asData?.value;
      if (details == null) return;

      // Detect URLs that were active but are no longer active (completed/failed/canceled)
      final previousSet = prev ?? <String>{};
      final finishingUrls = previousSet.difference(next);

      if (finishingUrls.isNotEmpty) {
        if (kDebugMode) {
          debugPrint(
            '[DetailsController] Re-checking status immediately after download finished: $finishingUrls',
          );
        }

        // Re-check specific item if its URL finished
        if (finishingUrls.contains(details.url)) {
          ref.read(downloadedFilesProvider.notifier).checkFile(details);
        }

        // Re-check episodes
        final episodes = details.episodes ?? [];
        for (final ep in episodes) {
          if (finishingUrls.contains(ep.url)) {
            ref
                .read(downloadedFilesProvider.notifier)
                .checkFile(details, episode: ep);
          }
        }
      }
    });

    ref.listen(watchHistoryProvider, (prev, next) {
      final details = state.details.asData?.value;
      if (details != null) {
        _processEpisodes(details.episodes, details, isInitial: false);
      }
    });

    ref.listen(episodeWatchRevisionProvider, (prev, next) {
      final details = state.details.asData?.value;
      if (details != null) {
        _processEpisodes(details.episodes, details, isInitial: false);
      }
    });

    final savedAscending =
        ref
            .read(storageServiceProvider)
            .getPlayerSetting<bool>(
              'episode_sort_ascending',
              defaultValue: true,
            ) ??
        true;

    return DetailsState(isAscending: savedAscending);
  }

  void init(MultimediaItem initialItem) {
    if (state.item == null) {
      state = state.copyWith(item: initialItem);
    }
  }

  void setSeason(int season) {
    if (state.seasonMap.containsKey(season)) {
      state = state.copyWith(selectedSeason: season, selectedRangeIndex: 0);
    }
  }

  void toggleSort() {
    final nextAscending = !state.isAscending;
    state = state.copyWith(isAscending: nextAscending);

    unawaited(
      ref
          .read(storageServiceProvider)
          .setPlayerSetting('episode_sort_ascending', nextAscending),
    );
  }

  bool isEpisodeSelected(Episode episode) {
    return state.selectedEpisodeKeys.contains(episodeSelectionKey(episode));
  }

  void toggleEpisodeSelection(Episode episode) {
    final next = Set<String>.from(state.selectedEpisodeKeys);
    final key = episodeSelectionKey(episode);

    if (!next.add(key)) {
      next.remove(key);
    }

    state = state.copyWith(selectedEpisodeKeys: next);
  }

  void selectAllEpisodes() {
    final allEpisodeKeys = state.seasonMap.values
        .expand((episodes) => episodes)
        .map(episodeSelectionKey)
        .toSet();

    if (allEpisodeKeys.isEmpty) {
      return;
    }

    state = state.copyWith(selectedEpisodeKeys: allEpisodeKeys);
  }

  void clearEpisodeSelection() {
    if (state.selectedEpisodeKeys.isEmpty) {
      return;
    }

    state = state.copyWith(selectedEpisodeKeys: const <String>{});
  }

  Future<void> setSelectedEpisodesWatched(String mainUrl, bool watched) async {
    if (state.selectedEpisodeKeys.isEmpty) {
      return;
    }

    final selectedKeys = Set<String>.from(state.selectedEpisodeKeys);

    final selectedEpisodes = state.seasonMap.values
        .expand((episodes) => episodes)
        .where((episode) => selectedKeys.contains(episodeSelectionKey(episode)))
        .toList(growable: false);

    if (selectedEpisodes.isEmpty) {
      clearEpisodeSelection();
      return;
    }

    await ref
        .read(episodeWatchRepositoryProvider)
        .setManyWatched(mainUrl, selectedEpisodes, watched);

    if (!ref.mounted) {
      return;
    }

    state = state.copyWith(selectedEpisodeKeys: const <String>{});

    final currentDetails = state.details.asData?.value;
    if (currentDetails != null) {
      _processEpisodes(
        currentDetails.episodes,
        currentDetails,
        isInitial: false,
      );
    }
  }

  void setRangeIndex(int index) {
    state = state.copyWith(selectedRangeIndex: index);
  }

  void setDubStatus(DubStatus status) {
    state = state.copyWith(selectedDubStatus: status, selectedRangeIndex: 0);
  }

  void setLaunching(bool value) {
    if (state.isLaunching != value) {
      state = state.copyWith(isLaunching: value);
    }
  }

  Future<void> loadDetails(MultimediaItem item, {bool autoPlay = false}) async {
    if (state.details is AsyncData) return;

    state = state.copyWith(details: const AsyncLoading());

    final active = ref.read(activeProviderProvider);
    final manager = ref.read(extensionManagerProvider.notifier);

    try {
      if (item.provider == 'Local' ||
          item.provider == 'Torrent' ||
          item.provider == 'Remote') {
        var itemToUse = item;
        if (itemToUse.episodes == null || itemToUse.episodes!.isEmpty) {
          itemToUse = itemToUse.copyWith(
            episodes: [
              Episode(
                name: itemToUse.title,
                url: itemToUse.url,
                posterUrl: itemToUse.posterUrl,
              ),
            ],
          );
        }

        _processEpisodes(itemToUse.episodes, itemToUse);
        state = state.copyWith(details: AsyncData(itemToUse));

        // Speculatively pre-warm stream for instant playback (Netflix Warm Start)
        final targetEp = state.targetEpisode ?? itemToUse.episodes?.firstOrNull;
        final targetUrl = targetEp?.url ?? itemToUse.url;
        unawaited(
          StreamPrewarmer.instance.prewarm(
            item: itemToUse,
            targetUrl: targetUrl,
            read: ref.read,
            episode: targetEp,
          ),
        );
        return;
      }

      final isCinemetaItem =
          item.provider == 'cinemeta' || item.url.startsWith('cinemeta:');
      final isCinemetaSeries =
          isCinemetaItem &&
          (item.contentType == MultimediaContentType.series ||
              item.contentType == MultimediaContentType.anime);
      final isCatalogItem =
          isCinemetaItem ||
          item.provider == 'dev.justin.catalogue' ||
          item.provider == 'tmdb' ||
          item.url.startsWith('tmdb:');

      SkyStreamProvider? provider;
      if (!isCatalogItem && item.provider != null) {
        try {
          provider = manager.getAllProviders().firstWhere(
            (p) => p.packageName == item.provider || p.name == item.provider,
          );
        } catch (e) {
          if (kDebugMode) debugPrint('DetailsController.loadDetails: $e');
        }
      }

      // Cinemeta cards are metadata-only. Resolve an exact title through the
      // active streaming provider first so its episode URLs remain playable.
      if (isCinemetaSeries) provider = active;

      if (!isCatalogItem) {
        provider ??= active;
      }

      MultimediaItem? fetchedItem;
      if (provider != null) {
        if (isCinemetaSeries) {
          try {
            final searchResults = await provider.search(item.title);
            final titleKey = _normalizedMediaTitle(item.title);
            final match = searchResults.firstWhereOrNull((result) {
              if (_normalizedMediaTitle(result.title) != titleKey) return false;
              if (!_compatibleSeriesType(item, result)) return false;
              return item.year == null ||
                  result.year == null ||
                  item.year == result.year;
            });
            if (match != null) {
              fetchedItem = await provider.getDetails(match.url);
            }
          } catch (e) {
            if (kDebugMode) {
              debugPrint('Provider title lookup failed for ${item.title}: $e');
            }
          }
        } else {
          try {
            fetchedItem = await provider.getDetails(item.url);
          } catch (e) {
            if (kDebugMode) {
              debugPrint(
                'Provider getDetails failed: $e. Attempting title search fallback.',
              );
            }
            try {
              final searchResults = await provider.search(item.title);
              final match = searchResults.firstWhereOrNull(
                (result) =>
                    _normalizedMediaTitle(result.title) ==
                    _normalizedMediaTitle(item.title),
              );
              if (match != null) {
                fetchedItem = await provider.getDetails(match.url);
              }
            } catch (_) {}
          }
        }
      }

      // If the selected provider has no matching series, Cinemeta still has
      // the canonical season and episode list. Its episode IDs provide
      // navigation for catalog-backed title cards.
      if (isCinemetaSeries && (fetchedItem?.episodes?.length ?? 0) < 2) {
        try {
          final catalogDetails = await _fetchCinemetaEpisodes(item);
          if (catalogDetails != null) {
            final providerEpisodes = fetchedItem?.episodes ?? const <Episode>[];
            fetchedItem = (fetchedItem ?? catalogDetails).copyWith(
              episodes: _mergeEpisodeLists(
                catalogDetails.episodes ?? const <Episode>[],
                providerEpisodes,
              ),
            );
          }
        } catch (e) {
          if (kDebugMode) {
            debugPrint('Cinemeta episode lookup failed for ${item.title}: $e');
          }
        }
      }

      if (isCinemetaSeries && fetchedItem != null) {
        fetchedItem = fetchedItem.copyWith(
          url: item.url,
          provider: provider?.packageName ?? item.provider,
        );
      }

      if (!ref.mounted) return;

      var withProvider = (fetchedItem ?? item).copyWith(
        provider: provider?.packageName ?? item.provider ?? 'cinemeta',
        tmdbId: fetchedItem?.tmdbId ?? item.tmdbId,
        imdbId: fetchedItem?.imdbId ?? item.imdbId,
      );

      // Movies can use their own item URL as a single playable entry. For a
      // series, an empty episode list means metadata resolution failed; do not
      // disguise that as a one-episode movie.
      final isSeries =
          withProvider.contentType == MultimediaContentType.series ||
          withProvider.contentType == MultimediaContentType.anime;
      if (!isSeries &&
          (withProvider.episodes == null || withProvider.episodes!.isEmpty)) {
        withProvider = withProvider.copyWith(
          episodes: [
            Episode(
              name: withProvider.title,
              url: withProvider.url,
              posterUrl: withProvider.posterUrl,
            ),
          ],
        );
      }

      // Immediately render the UI with raw provider details so it's not blocked
      final sortedEpisodes = _processEpisodes(
        withProvider.episodes,
        withProvider,
        isInitial: true,
      );
      state = state.copyWith(
        details: AsyncData(withProvider.copyWith(episodes: sortedEpisodes)),
        item: withProvider.copyWith(episodes: sortedEpisodes),
      );

      // Run Metadata Resolution in background silently (fire-and-forget).
      unawaited(_resolveMetadataInBackground(withProvider));

      // Speculatively pre-warm stream for instant playback (Netflix Warm Start)
      final targetEp = state.targetEpisode ?? sortedEpisodes?.firstOrNull;
      final targetUrl = targetEp?.url ?? withProvider.url;
      unawaited(
        StreamPrewarmer.instance.prewarm(
          item: withProvider,
          targetUrl: targetUrl,
          read: ref.read,
          episode: targetEp,
        ),
      );
    } catch (e, st) {
      if (ref.mounted) {
        state = state.copyWith(details: AsyncError(e, st));
      }
    }
  }

  Future<MultimediaItem?> _fetchCinemetaEpisodes(MultimediaItem item) async {
    final id =
        item.imdbId ?? RegExp(r'tt\d{6,}').firstMatch(item.url)?.group(0);
    if (id == null) return null;

    final response = await ref
        .read(dioClientProvider)
        .get<dynamic>(
          'https://v3-cinemeta.strem.io/meta/series/$id.json',
          options: Options(receiveTimeout: const Duration(seconds: 8)),
        );
    final data = response.data;
    if (data is! Map || data['meta'] is! Map) return null;

    final meta = Map<String, dynamic>.from(data['meta'] as Map);
    final rawVideos = meta['videos'];
    if (rawVideos is! List) return null;

    final episodes = <Episode>[];
    for (final rawVideo in rawVideos) {
      if (rawVideo is! Map) continue;
      final video = Map<String, dynamic>.from(rawVideo);
      final season = _parseCinemetaInt(video['season']);
      final number =
          _parseCinemetaInt(video['episode']) ??
          _parseCinemetaInt(video['number']);
      if (season == null || number == null) continue;

      final videoId = video['id']?.toString().trim();
      episodes.add(
        Episode(
          name: video['name']?.toString() ?? 'Episode $number',
          url: videoId == null || videoId.isEmpty
              ? '$id:$season:$number'
              : videoId,
          season: season,
          episode: number,
          description:
              video['overview']?.toString() ?? video['description']?.toString(),
          posterUrl: video['thumbnail']?.toString(),
          airDate: video['released']?.toString(),
          rating: double.tryParse(video['rating']?.toString() ?? ''),
        ),
      );
    }

    if (episodes.isEmpty) return null;
    return item.copyWith(
      title: meta['name']?.toString() ?? item.title,
      description: meta['description']?.toString() ?? item.description,
      episodes: episodes,
    );
  }

  int? _parseCinemetaInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }

  List<Episode> _mergeEpisodeLists(
    List<Episode> catalogEpisodes,
    List<Episode> providerEpisodes,
  ) {
    if (providerEpisodes.isEmpty) return catalogEpisodes;

    final playableByNumber = <(int, int), Episode>{};
    for (final episode in providerEpisodes) {
      if (episode.season > 0 && episode.episode > 0) {
        playableByNumber[(episode.season, episode.episode)] = episode;
      }
    }

    return catalogEpisodes.map((catalogEpisode) {
      final playable =
          playableByNumber[(catalogEpisode.season, catalogEpisode.episode)];
      if (playable == null || playable.url.isEmpty) return catalogEpisode;

      return Episode(
        name: playable.name.isNotEmpty ? playable.name : catalogEpisode.name,
        url: playable.url,
        season: catalogEpisode.season,
        episode: catalogEpisode.episode,
        description: playable.description ?? catalogEpisode.description,
        posterUrl: playable.posterUrl ?? catalogEpisode.posterUrl,
        headers: playable.headers,
        rating: playable.rating ?? catalogEpisode.rating,
        runtime: playable.runtime,
        airDate: playable.airDate ?? catalogEpisode.airDate,
        dubStatus: playable.dubStatus,
        playbackPolicy: playable.playbackPolicy,
        streams: playable.streams,
      );
    }).toList();
  }

  Future<void> _resolveMetadataInBackground(MultimediaItem withProvider) async {
    try {
      if (kDebugMode) {
        debugPrint(
          'DetailsController: Fetching missing IDs in background for ${withProvider.title}...',
        );
      }
      MultimediaItem enrichedItem = withProvider;

      final hasAnyWesternId =
          withProvider.tmdbId != null || withProvider.imdbId != null;

      try {
        if (!hasAnyWesternId) {
          enrichedItem = await ref
              .read(metadataResolutionServiceProvider)
              .enrichWithIds(withProvider);
          if (kDebugMode) {
            debugPrint(
              'DetailsController: Background resolution result -> tmdbId: ${enrichedItem.tmdbId}, imdbId: ${enrichedItem.imdbId}',
            );
          }
        } else {
          if (kDebugMode) {
            debugPrint(
              'DetailsController: Bypassed TMDB resolution (tmdbId or imdbId already provided by scraper)',
            );
          }
        }
      } catch (e) {
        if (kDebugMode) {
          debugPrint(
            'DetailsController: TMDB metadata resolution failed, but continuing: $e',
          );
        }
      }

      // Pre-fetch Simkl / AniList tracking IDs
      MultimediaItem finalItem = enrichedItem;
      try {
        final isAnime =
            enrichedItem.contentType == MultimediaContentType.anime ||
            enrichedItem.syncData?['anilistId'] != null ||
            enrichedItem.syncData?['anilist_id'] != null ||
            (enrichedItem.tags != null &&
                enrichedItem.tags!.any(
                  (t) =>
                      t.toLowerCase() == 'anime' ||
                      t.toLowerCase() == 'animation',
                ));

        if (isAnime) {
          final hasAnilistId =
              enrichedItem.syncData?['anilist'] != null ||
              enrichedItem.syncData?['anilistId'] != null ||
              enrichedItem.syncData?['anilist_id'] != null;

          if (!hasAnilistId) {
            final simkl = ref.read(simklServiceProvider);
            final resolved = await simkl.syncIds(enrichedItem);
            if (resolved.isNotEmpty) {
              final newSyncData = Map<String, String>.from(
                enrichedItem.syncData ?? {},
              );
              newSyncData.addAll(resolved);
              finalItem = enrichedItem.copyWith(syncData: newSyncData);
              if (kDebugMode) {
                debugPrint('DetailsController: Fetched Simkl IDs: $resolved');
              }
            }
          } else {
            if (kDebugMode) {
              debugPrint(
                'DetailsController: Bypassed Simkl fetch (AniList ID already provided by scraper)',
              );
            }
          }
        }
      } catch (e) {
        if (kDebugMode) {
          debugPrint(
            'DetailsController: Failed to fetch Simkl IDs in background: $e',
          );
        }
      }

      if (!ref.mounted) return;

      if (finalItem.tmdbId != withProvider.tmdbId ||
          finalItem.imdbId != withProvider.imdbId ||
          finalItem.syncData != withProvider.syncData) {
        // preserve the episodes from the current state just in case
        final currentDetails = state.details.asData?.value;
        if (currentDetails != null) {
          final updatedItem = currentDetails.copyWith(
            tmdbId: finalItem.tmdbId,
            imdbId: finalItem.imdbId,
            syncData: finalItem.syncData,
          );
          state = state.copyWith(
            details: AsyncData(updatedItem),
            item: updatedItem,
          );
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint(
          'DetailsController: Background metadata resolution failed: $e',
        );
      }
    }
  }

  List<Episode>? _processEpisodes(
    List<Episode>? episodes,
    MultimediaItem contextItem, {
    bool isInitial = false,
  }) {
    if (episodes == null || episodes.isEmpty) {
      state = state.copyWith(
        isMovie: contextItem.contentType == MultimediaContentType.movie,
        seasonMap: {},
      );
      return episodes;
    }

    bool isMovie =
        contextItem.contentType == MultimediaContentType.movie ||
        contextItem.contentType == MultimediaContentType.livestream;

    if (!isMovie && episodes.length == 1) {
      isMovie = true;
    }

    if (isMovie) {
      state = state.copyWith(
        isMovie: true,
        seasonMap: {1: episodes},
        selectedSeason: 1,
      );
      return episodes;
    }

    final Map<int, List<Episode>> seasonMap = {};
    for (final ep in episodes) {
      final season = ep.season > 0 ? ep.season : 1;
      seasonMap.putIfAbsent(season, () => []).add(ep);
    }

    final sortedSeasons = seasonMap.keys.toList()..sort();
    int selectedSeason = sortedSeasons.isNotEmpty ? sortedSeasons.first : 1;
    Episode? targetEpisode;

    final historyRepo = ref.read(historyRepositoryProvider);
    final episodeWatchRepo = ref.read(episodeWatchRepositoryProvider);

    final allEpisodes = episodes;
    final lastEpisodeUrl = historyRepo.getLastEpisodeUrl(contextItem.url);

    if (lastEpisodeUrl != null) {
      int lastIndex = allEpisodes.indexWhere((e) => e.url == lastEpisodeUrl);

      if (lastIndex == -1) {
        final mainHistoryItem = ref
            .read(watchHistoryProvider)
            .firstWhereOrNull((h) => h.item.url == contextItem.url);
        if (mainHistoryItem != null &&
            mainHistoryItem.season != null &&
            mainHistoryItem.episode != null) {
          lastIndex = allEpisodes.indexWhere(
            (e) =>
                e.season == mainHistoryItem.season &&
                e.episode == mainHistoryItem.episode,
          );
        }
      }

      if (lastIndex != -1) {
        final matchedEp = allEpisodes[lastIndex];
        if (episodeWatchRepo.isWatched(contextItem.url, matchedEp)) {
          if (lastIndex + 1 < allEpisodes.length) {
            targetEpisode = allEpisodes[lastIndex + 1];
          } else {
            targetEpisode = allEpisodes[lastIndex];
          }
        } else {
          targetEpisode = allEpisodes[lastIndex];
        }
      }
    }

    targetEpisode ??= allEpisodes.firstWhereOrNull(
      (episode) => !episodeWatchRepo.isWatched(contextItem.url, episode),
    );

    targetEpisode ??= allEpisodes.last;

    if (isInitial && targetEpisode.season > 0) {
      selectedSeason = targetEpisode.season;
    } else {
      selectedSeason = state.selectedSeason;
    }

    DubStatus selectedDubStatus = state.selectedDubStatus;
    if (isInitial) {
      final hasSub = episodes.any((e) => e.dubStatus == DubStatus.subbed);
      final hasDub = episodes.any((e) => e.dubStatus == DubStatus.dubbed);
      if (hasSub && hasDub) {
        selectedDubStatus = DubStatus.subbed;
      } else {
        selectedDubStatus = DubStatus.none;
      }
    }

    state = state.copyWith(
      isMovie: false,
      seasonMap: seasonMap,
      selectedSeason: selectedSeason,
      targetEpisode: targetEpisode,
      selectedDubStatus: selectedDubStatus,
    );
    return episodes;
  }

  void toggleLibrary() {
    final item = state.details.value;
    if (item == null) return;

    final libraryRepo = ref.read(libraryRepositoryProvider);
    final wasInLibrary = libraryRepo.isInLibrary(item.url);

    if (wasInLibrary) {
      ref.read(libraryProvider.notifier).removeItem(item.url);
    } else {
      ref.read(libraryProvider.notifier).addItem(item);
    }
  }

  Future<void> handlePlayPress(
    // Only handed on to the launcher, which needs it to push the player;
    // choosing the episode is the part that belongs here.
    // ignore: riverpod_lint/avoid_build_context_in_providers
    BuildContext context,
    MultimediaItem details, {
    Episode? specificEpisode,
    String? overrideUrl,
  }) async {
    final fullItem = state.details.asData?.value ?? details;
    final itemToUse =
        (fullItem.episodes != null && fullItem.episodes!.isNotEmpty)
        ? fullItem
        : details;

    if (overrideUrl != null) {
      await ref
          .read(playbackLauncherProvider)
          .play(
            context,
            overrideUrl,
            baseItem: itemToUse,
            detailedItem: state.details.asData?.value,
          );
      return;
    }

    if (specificEpisode != null) {
      await ref
          .read(playbackLauncherProvider)
          .play(
            context,
            specificEpisode.url,
            baseItem: itemToUse,
            detailedItem: state.details.asData?.value,
            episode: specificEpisode,
          );
      return;
    }

    if (state.isMovie) {
      final ep = itemToUse.episodes?.firstOrNull;
      await ref
          .read(playbackLauncherProvider)
          .play(
            context,
            ep?.url ?? itemToUse.url,
            baseItem: itemToUse,
            detailedItem: state.details.asData?.value,
            episode: ep,
          );
      return;
    }

    if (state.targetEpisode != null) {
      await ref
          .read(playbackLauncherProvider)
          .play(
            context,
            state.targetEpisode!.url,
            baseItem: itemToUse,
            detailedItem: state.details.asData?.value,
            episode: state.targetEpisode,
          );
      return;
    }

    final firstSeason = state.seasonMap.keys.toList()..sort();
    if (firstSeason.isNotEmpty) {
      final ep = state.seasonMap[firstSeason.first]?.first;
      if (ep != null) {
        await ref
            .read(playbackLauncherProvider)
            .play(
              context,
              ep.url,
              baseItem: itemToUse,
              detailedItem: state.details.asData?.value,
              episode: ep,
            );
      }
    }
  }
}
