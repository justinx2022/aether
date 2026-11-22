import 'dart:math';
import 'package:flutter/foundation.dart';
import '../domain/entity/canonical_media_identity.dart';

/// Base class for all typed, immutable events in the Aether ecosystem.
@immutable
abstract class AetherEvent {
  final String eventId;
  final int sequenceNumber;
  final DateTime timestamp;

  AetherEvent({
    String? eventId,
    int? sequenceNumber,
    DateTime? timestamp,
  })  : eventId = eventId ?? _generateEventId(),
        sequenceNumber = sequenceNumber ?? _generateSeq(),
        timestamp = timestamp ?? DateTime.now();

  static int _globalSeq = 0;
  static int _generateSeq() => ++_globalSeq;

  static String _generateEventId() {
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final rand = Random.secure();
    final timeHex = nowMs.toRadixString(16).padLeft(12, '0');
    final randHex = rand.nextInt(0xFFFFFF).toRadixString(16).padLeft(6, '0');
    return 'evt_${timeHex}_$randHex';
  }

  Map<String, dynamic> toMap();

  @override
  String toString() => '$runtimeType(id: $eventId, seq: $sequenceNumber)';
}

// ══════════════════════════════════════════════════════════════════════
// ── PLAYBACK DOMAIN EVENTS ──
// ══════════════════════════════════════════════════════════════════════

class PlaybackSessionStartedEvent extends AetherEvent {
  final String sessionId;
  final CanonicalMediaIdentity mediaIdentity;
  final String? episodeUrn;
  final String streamUrl;
  final int initialPositionMs;

  PlaybackSessionStartedEvent({
    required this.sessionId,
    required this.mediaIdentity,
    this.episodeUrn,
    required this.streamUrl,
    required this.initialPositionMs,
    super.eventId,
    super.sequenceNumber,
    super.timestamp,
  });

  @override
  Map<String, dynamic> toMap() => {
        'type': 'PlaybackSessionStartedEvent',
        'sessionId': sessionId,
        'aetherId': mediaIdentity.aetherId.urn,
        'episodeUrn': episodeUrn,
        'streamUrl': streamUrl,
        'initialPositionMs': initialPositionMs,
        'timestamp': timestamp.toIso8601String(),
      };
}

class PlaybackMilestoneCommittedEvent extends AetherEvent {
  final String sessionId;
  final CanonicalMediaIdentity mediaIdentity;
  final String? episodeUrn;
  final int positionMs;
  final int durationMs;

  PlaybackMilestoneCommittedEvent({
    required this.sessionId,
    required this.mediaIdentity,
    this.episodeUrn,
    required this.positionMs,
    required this.durationMs,
    super.eventId,
    super.sequenceNumber,
    super.timestamp,
  });

  double get progressFraction => durationMs > 0 ? (positionMs / durationMs).clamp(0.0, 1.0) : 0.0;

  @override
  Map<String, dynamic> toMap() => {
        'type': 'PlaybackMilestoneCommittedEvent',
        'sessionId': sessionId,
        'aetherId': mediaIdentity.aetherId.urn,
        'episodeUrn': episodeUrn,
        'positionMs': positionMs,
        'durationMs': durationMs,
        'timestamp': timestamp.toIso8601String(),
      };
}

class PlaybackCompletedEvent extends AetherEvent {
  final String sessionId;
  final CanonicalMediaIdentity mediaIdentity;
  final String? episodeUrn;

  PlaybackCompletedEvent({
    required this.sessionId,
    required this.mediaIdentity,
    this.episodeUrn,
    super.eventId,
    super.sequenceNumber,
    super.timestamp,
  });

  @override
  Map<String, dynamic> toMap() => {
        'type': 'PlaybackCompletedEvent',
        'sessionId': sessionId,
        'aetherId': mediaIdentity.aetherId.urn,
        'episodeUrn': episodeUrn,
        'timestamp': timestamp.toIso8601String(),
      };
}

class PlaybackFailoverEvent extends AetherEvent {
  final String sessionId;
  final String failedProvider;
  final String nextProvider;
  final String reason;

  PlaybackFailoverEvent({
    required this.sessionId,
    required this.failedProvider,
    required this.nextProvider,
    required this.reason,
    super.eventId,
    super.sequenceNumber,
    super.timestamp,
  });

  @override
  Map<String, dynamic> toMap() => {
        'type': 'PlaybackFailoverEvent',
        'sessionId': sessionId,
        'failedProvider': failedProvider,
        'nextProvider': nextProvider,
        'reason': reason,
        'timestamp': timestamp.toIso8601String(),
      };
}

// ══════════════════════════════════════════════════════════════════════
// ── SOURCE RESOLUTION EVENTS ──
// ══════════════════════════════════════════════════════════════════════

class SourceResolvedEvent extends AetherEvent {
  final CanonicalMediaIdentity mediaIdentity;
  final String providerName;
  final int candidateCount;
  final int resolutionDurationMs;

  SourceResolvedEvent({
    required this.mediaIdentity,
    required this.providerName,
    required this.candidateCount,
    required this.resolutionDurationMs,
    super.eventId,
    super.sequenceNumber,
    super.timestamp,
  });

  @override
  Map<String, dynamic> toMap() => {
        'type': 'SourceResolvedEvent',
        'aetherId': mediaIdentity.aetherId.urn,
        'providerName': providerName,
        'candidateCount': candidateCount,
        'resolutionDurationMs': resolutionDurationMs,
        'timestamp': timestamp.toIso8601String(),
      };
}

class SourceFailedEvent extends AetherEvent {
  final CanonicalMediaIdentity mediaIdentity;
  final String providerName;
  final String errorMessage;

  SourceFailedEvent({
    required this.mediaIdentity,
    required this.providerName,
    required this.errorMessage,
    super.eventId,
    super.sequenceNumber,
    super.timestamp,
  });

  @override
  Map<String, dynamic> toMap() => {
        'type': 'SourceFailedEvent',
        'aetherId': mediaIdentity.aetherId.urn,
        'providerName': providerName,
        'errorMessage': errorMessage,
        'timestamp': timestamp.toIso8601String(),
      };
}

// ══════════════════════════════════════════════════════════════════════
// ── LIBRARY & WATCHLIST EVENTS ──
// ══════════════════════════════════════════════════════════════════════

class WatchlistToggledEvent extends AetherEvent {
  final String profileId;
  final CanonicalMediaIdentity mediaIdentity;
  final bool isAdded;

  WatchlistToggledEvent({
    required this.profileId,
    required this.mediaIdentity,
    required this.isAdded,
    super.eventId,
    super.sequenceNumber,
    super.timestamp,
  });

  @override
  Map<String, dynamic> toMap() => {
        'type': 'WatchlistToggledEvent',
        'profileId': profileId,
        'aetherId': mediaIdentity.aetherId.urn,
        'isAdded': isAdded,
        'timestamp': timestamp.toIso8601String(),
      };
}

// ══════════════════════════════════════════════════════════════════════
// ── PROFILES & PREFERENCES EVENTS ──
// ══════════════════════════════════════════════════════════════════════

class ProfileSwitchedEvent extends AetherEvent {
  final String oldProfileId;
  final String newProfileId;

  ProfileSwitchedEvent({
    required this.oldProfileId,
    required this.newProfileId,
    super.eventId,
    super.sequenceNumber,
    super.timestamp,
  });

  @override
  Map<String, dynamic> toMap() => {
        'type': 'ProfileSwitchedEvent',
        'oldProfileId': oldProfileId,
        'newProfileId': newProfileId,
        'timestamp': timestamp.toIso8601String(),
      };
}

class PreferenceChangedEvent extends AetherEvent {
  final String profileId;
  final String key;
  final dynamic value;

  PreferenceChangedEvent({
    required this.profileId,
    required this.key,
    required this.value,
    super.eventId,
    super.sequenceNumber,
    super.timestamp,
  });

  @override
  Map<String, dynamic> toMap() => {
        'type': 'PreferenceChangedEvent',
        'profileId': profileId,
        'key': key,
        'value': value,
        'timestamp': timestamp.toIso8601String(),
      };
}
