import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/entity/canonical_media_identity.dart';
import '../domain/entity/multimedia_item.dart';
import '../events/aether_event.dart';
import '../events/aether_event_bus.dart';
import '../storage/history_repository.dart';
import 'playback_session.dart';

final playbackCoordinatorProvider =
    NotifierProvider<PlaybackCoordinator, PlaybackSession?>(PlaybackCoordinator.new);

/// Coordinates active playback sessions, decouples player UI widgets from direct
/// persistence calls, handles automatic failover recovery, and publishes events.
class PlaybackCoordinator extends Notifier<PlaybackSession?> {
  Timer? _milestoneTimer;
  int _lastCommittedPositionMs = 0;

  @override
  PlaybackSession? build() {
    ref.onDispose(() {
      _milestoneTimer?.cancel();
    });
    return null;
  }

  AetherEventBus get _bus => ref.read(aetherEventBusProvider);
  HistoryRepository get _history => ref.read(historyRepositoryProvider);

  /// Initializes a new first-class [PlaybackSession].
  PlaybackSession startSession({
    required CanonicalMediaIdentity mediaIdentity,
    String? episodeUrn,
    required String profileId,
    int initialPositionMs = 0,
    int durationMs = 0,
    String? streamUrl,
    String? providerName,
    List<String> fallbackUrls = const [],
  }) {
    final session = PlaybackSession.create(
      mediaIdentity: mediaIdentity,
      episodeUrn: episodeUrn,
      profileId: profileId,
      initialPositionMs: initialPositionMs,
      durationMs: durationMs,
    ).copyWith(
      activeStreamUrl: streamUrl,
      activeProviderName: providerName,
      fallbackStreamUrls: fallbackUrls,
      stage: PlaybackStage.buffering,
    );

    state = session;
    _lastCommittedPositionMs = initialPositionMs;

    _bus.publish(
      PlaybackSessionStartedEvent(
        sessionId: session.sessionId,
        mediaIdentity: mediaIdentity,
        episodeUrn: episodeUrn,
        streamUrl: streamUrl ?? '',
        initialPositionMs: initialPositionMs,
      ),
    );

    return session;
  }

  /// Sets the active stage of playback.
  void setStage(PlaybackStage stage) {
    if (state == null) return;
    state = state!.copyWith(stage: stage);

    if (stage == PlaybackStage.completed) {
      _bus.publish(
        PlaybackCompletedEvent(
          sessionId: state!.sessionId,
          mediaIdentity: state!.mediaIdentity,
          episodeUrn: state!.episodeUrn,
        ),
      );
    }
  }

  /// Updates real-time position metrics. Emits milestones when threshold
  /// (e.g. 10 seconds or completion) is crossed.
  void updateProgress({
    required int positionMs,
    required int durationMs,
    required int bufferedMs,
    MultimediaItem? legacyItem,
    int? season,
    int? episode,
    String? episodeTitle,
  }) {
    if (state == null) return;

    final updated = state!.copyWith(
      currentPositionMs: positionMs,
      durationMs: durationMs,
      bufferedPositionMs: bufferedMs,
      stage: positionMs > 0 ? PlaybackStage.activePlaying : state!.stage,
    );
    state = updated;

    final deltaSec = ((positionMs - _lastCommittedPositionMs).abs() / 1000).round();
    if (deltaSec >= 10 || (durationMs > 0 && updated.isCompleted)) {
      commitMilestone(
        legacyItem: legacyItem,
        season: season,
        episode: episode,
        episodeTitle: episodeTitle,
      );
    }
  }

  /// Forces an immediate milestone commit to durable storage and the event bus.
  Future<void> commitMilestone({
    MultimediaItem? legacyItem,
    int? season,
    int? episode,
    String? episodeTitle,
  }) async {
    if (state == null) return;

    final session = state!;
    _lastCommittedPositionMs = session.currentPositionMs;
    state = session.copyWith(lastMilestoneSavedAt: DateTime.now());

    // 1. Emit typed event
    _bus.publish(
      PlaybackMilestoneCommittedEvent(
        sessionId: session.sessionId,
        mediaIdentity: session.mediaIdentity,
        episodeUrn: session.episodeUrn,
        positionMs: session.currentPositionMs,
        durationMs: session.durationMs,
      ),
    );

    // 2. Persist to HistoryRepository (seconds)
    if (legacyItem != null) {
      try {
        await _history.saveProgress(
          legacyItem,
          (session.currentPositionMs / 1000).round(),
          (session.durationMs / 1000).round(),
          lastStreamUrl: session.activeStreamUrl,
          season: season,
          episode: episode,
          episodeTitle: episodeTitle,
          profileId: session.profileId,
        );
      } catch (e) {
        if (kDebugMode) debugPrint('[PlaybackCoordinator] Error saving history: $e');
      }
    }
  }

  /// Records a buffer or segment timeout. If consecutive errors >= 2,
  /// initiates automatic failover to the next candidate.
  String? recordBufferError(String reason) {
    if (state == null) return null;

    final session = state!;
    final errorCount = session.consecutiveBufferErrors + 1;
    state = session.copyWith(consecutiveBufferErrors: errorCount);

    if (errorCount >= 2 && session.fallbackStreamUrls.isNotEmpty) {
      final nextUrl = session.fallbackStreamUrls.first;
      final remainingFallbacks = session.fallbackStreamUrls.skip(1).toList();

      state = session.copyWith(
        stage: PlaybackStage.failoverRecovery,
        activeStreamUrl: nextUrl,
        fallbackStreamUrls: remainingFallbacks,
        consecutiveBufferErrors: 0,
      );

      _bus.publish(
        PlaybackFailoverEvent(
          sessionId: session.sessionId,
          failedProvider: session.activeProviderName ?? 'unknown',
          nextProvider: 'fallback_candidate',
          reason: reason,
        ),
      );

      return nextUrl;
    }

    return null;
  }

  /// Updates audio track selection.
  void setAudioTrack(String trackId) {
    if (state == null) return;
    state = state!.copyWith(selectedAudioTrackId: trackId);
  }

  /// Updates subtitle track selection.
  void setSubtitleTrack(String trackId) {
    if (state == null) return;
    state = state!.copyWith(selectedSubtitleTrackId: trackId);
  }

  /// Terminates the active session and cleans up resources.
  void terminateSession({MultimediaItem? legacyItem, int? season, int? episode, String? episodeTitle}) {
    if (state == null) return;
    commitMilestone(legacyItem: legacyItem, season: season, episode: episode, episodeTitle: episodeTitle);
    state = state!.copyWith(stage: PlaybackStage.terminated);
    state = null;
  }
}
