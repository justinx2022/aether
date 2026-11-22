import 'dart:math';
import 'package:flutter/foundation.dart';
import '../domain/entity/canonical_media_identity.dart';

enum PlaybackStage {
  initializing,
  resolvingSources,
  probingCandidates,
  buffering,
  activePlaying,
  paused,
  failoverRecovery,
  completed,
  terminated,
}

/// A first-class, immutable representation of an active or past media playback session.
@immutable
class PlaybackSession {
  final String sessionId;
  final CanonicalMediaIdentity mediaIdentity;
  final String? episodeUrn;
  final String profileId;
  final PlaybackStage stage;
  final int currentPositionMs;
  final int durationMs;
  final int bufferedPositionMs;
  final String? activeStreamUrl;
  final String? activeProviderName;
  final List<String> fallbackStreamUrls;
  final String selectedAudioTrackId;
  final String selectedSubtitleTrackId;
  final int consecutiveBufferErrors;
  final DateTime startedAt;
  final DateTime lastMilestoneSavedAt;

  const PlaybackSession({
    required this.sessionId,
    required this.mediaIdentity,
    this.episodeUrn,
    required this.profileId,
    required this.stage,
    required this.currentPositionMs,
    required this.durationMs,
    required this.bufferedPositionMs,
    this.activeStreamUrl,
    this.activeProviderName,
    this.fallbackStreamUrls = const [],
    this.selectedAudioTrackId = 'auto',
    this.selectedSubtitleTrackId = 'off',
    this.consecutiveBufferErrors = 0,
    required this.startedAt,
    required this.lastMilestoneSavedAt,
  });

  factory PlaybackSession.create({
    required CanonicalMediaIdentity mediaIdentity,
    String? episodeUrn,
    required String profileId,
    int initialPositionMs = 0,
    int durationMs = 0,
  }) {
    final now = DateTime.now();
    final randHex = Random.secure().nextInt(0xFFFFFF).toRadixString(16).padLeft(6, '0');
    final sessionId = 'sess_${now.millisecondsSinceEpoch}_$randHex';

    return PlaybackSession(
      sessionId: sessionId,
      mediaIdentity: mediaIdentity,
      episodeUrn: episodeUrn,
      profileId: profileId,
      stage: PlaybackStage.initializing,
      currentPositionMs: initialPositionMs,
      durationMs: durationMs,
      bufferedPositionMs: 0,
      startedAt: now,
      lastMilestoneSavedAt: now,
    );
  }

  double get progressFraction =>
      durationMs > 0 ? (currentPositionMs / durationMs).clamp(0.0, 1.0) : 0.0;

  bool get isCompleted => progressFraction >= 0.92;

  PlaybackSession copyWith({
    PlaybackStage? stage,
    int? currentPositionMs,
    int? durationMs,
    int? bufferedPositionMs,
    String? activeStreamUrl,
    String? activeProviderName,
    List<String>? fallbackStreamUrls,
    String? selectedAudioTrackId,
    String? selectedSubtitleTrackId,
    int? consecutiveBufferErrors,
    DateTime? lastMilestoneSavedAt,
  }) {
    return PlaybackSession(
      sessionId: sessionId,
      mediaIdentity: mediaIdentity,
      episodeUrn: episodeUrn,
      profileId: profileId,
      stage: stage ?? this.stage,
      currentPositionMs: currentPositionMs ?? this.currentPositionMs,
      durationMs: durationMs ?? this.durationMs,
      bufferedPositionMs: bufferedPositionMs ?? this.bufferedPositionMs,
      activeStreamUrl: activeStreamUrl ?? this.activeStreamUrl,
      activeProviderName: activeProviderName ?? this.activeProviderName,
      fallbackStreamUrls: fallbackStreamUrls ?? this.fallbackStreamUrls,
      selectedAudioTrackId: selectedAudioTrackId ?? this.selectedAudioTrackId,
      selectedSubtitleTrackId: selectedSubtitleTrackId ?? this.selectedSubtitleTrackId,
      consecutiveBufferErrors: consecutiveBufferErrors ?? this.consecutiveBufferErrors,
      startedAt: startedAt,
      lastMilestoneSavedAt: lastMilestoneSavedAt ?? this.lastMilestoneSavedAt,
    );
  }

  Map<String, dynamic> toMap() => {
        'sessionId': sessionId,
        'aetherId': mediaIdentity.aetherId.urn,
        if (episodeUrn != null) 'episodeUrn': episodeUrn,
        'profileId': profileId,
        'stage': stage.name,
        'currentPositionMs': currentPositionMs,
        'durationMs': durationMs,
        'bufferedPositionMs': bufferedPositionMs,
        if (activeStreamUrl != null) 'activeStreamUrl': activeStreamUrl,
        if (activeProviderName != null) 'activeProviderName': activeProviderName,
        'fallbackStreamUrls': fallbackStreamUrls,
        'selectedAudioTrackId': selectedAudioTrackId,
        'selectedSubtitleTrackId': selectedSubtitleTrackId,
        'consecutiveBufferErrors': consecutiveBufferErrors,
        'startedAt': startedAt.toIso8601String(),
        'lastMilestoneSavedAt': lastMilestoneSavedAt.toIso8601String(),
      };
}
