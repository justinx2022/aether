import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'aether_id.dart';

enum CanonicalMediaType {
  movie,
  series,
  anime,
  documentary;

  static CanonicalMediaType fromString(String val) {
    return CanonicalMediaType.values.firstWhere(
      (e) => e.name.toLowerCase() == val.toLowerCase(),
      orElse: () => CanonicalMediaType.movie,
    );
  }
}

/// External Identifiers associated with a canonical media entity.
@immutable
class ExternalIds {
  final int? tmdbId;
  final String? imdbId;
  final int? anilistId;
  final int? tvdbId;
  final Map<String, String> providerTokens;

  const ExternalIds({
    this.tmdbId,
    this.imdbId,
    this.anilistId,
    this.tvdbId,
    this.providerTokens = const {},
  });

  bool get hasAuthoritativeId =>
      (tmdbId != null && tmdbId! > 0) ||
      (imdbId != null && imdbId!.isNotEmpty) ||
      (anilistId != null && anilistId! > 0) ||
      (tvdbId != null && tvdbId! > 0);

  ExternalIds copyWith({
    int? tmdbId,
    String? imdbId,
    int? anilistId,
    int? tvdbId,
    Map<String, String>? providerTokens,
  }) {
    return ExternalIds(
      tmdbId: tmdbId ?? this.tmdbId,
      imdbId: imdbId ?? this.imdbId,
      anilistId: anilistId ?? this.anilistId,
      tvdbId: tvdbId ?? this.tvdbId,
      providerTokens: providerTokens ?? this.providerTokens,
    );
  }

  ExternalIds mergeWith(ExternalIds other) {
    final mergedTokens = Map<String, String>.from(providerTokens)..addAll(other.providerTokens);
    return ExternalIds(
      tmdbId: other.tmdbId ?? tmdbId,
      imdbId: other.imdbId ?? imdbId,
      anilistId: other.anilistId ?? anilistId,
      tvdbId: other.tvdbId ?? tvdbId,
      providerTokens: mergedTokens,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (tmdbId != null) 'tmdbId': tmdbId,
      if (imdbId != null) 'imdbId': imdbId,
      if (anilistId != null) 'anilistId': anilistId,
      if (tvdbId != null) 'tvdbId': tvdbId,
      if (providerTokens.isNotEmpty) 'providerTokens': providerTokens,
    };
  }

  factory ExternalIds.fromMap(Map<String, dynamic> map) {
    final rawTokens = map['providerTokens'];
    final Map<String, String> tokens = rawTokens is Map
        ? rawTokens.map((k, v) => MapEntry(k.toString(), v.toString()))
        : const {};

    return ExternalIds(
      tmdbId: map['tmdbId'] as int?,
      imdbId: map['imdbId'] as String?,
      anilistId: map['anilistId'] as int?,
      tvdbId: map['tvdbId'] as int?,
      providerTokens: tokens,
    );
  }
}

/// Authoritative Canonical Media Identity representing a single creative work
/// across all providers, players, and storage domains.
@immutable
class CanonicalMediaIdentity {
  final AetherId aetherId;
  final CanonicalMediaType type;
  final String canonicalTitle;
  final int? releaseYear;
  final int? runtimeMinutes;
  final ExternalIds externalIds;
  final double matchConfidence; // 0.0 to 1.0
  final bool isAmbiguous;
  final DateTime createdAt;
  final DateTime updatedAt;

  const CanonicalMediaIdentity({
    required this.aetherId,
    required this.type,
    required this.canonicalTitle,
    this.releaseYear,
    this.runtimeMinutes,
    required this.externalIds,
    this.matchConfidence = 1.0,
    this.isAmbiguous = false,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Deterministic episode identifier string linked to this canonical parent.
  /// Example: urn:aether:media:018f...:s1e3
  String episodeUrn(int season, int episode) => '${aetherId.urn}:s${season}e$episode';

  CanonicalMediaIdentity copyWith({
    AetherId? aetherId,
    CanonicalMediaType? type,
    String? canonicalTitle,
    int? releaseYear,
    int? runtimeMinutes,
    ExternalIds? externalIds,
    double? matchConfidence,
    bool? isAmbiguous,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return CanonicalMediaIdentity(
      aetherId: aetherId ?? this.aetherId,
      type: type ?? this.type,
      canonicalTitle: canonicalTitle ?? this.canonicalTitle,
      releaseYear: releaseYear ?? this.releaseYear,
      runtimeMinutes: runtimeMinutes ?? this.runtimeMinutes,
      externalIds: externalIds ?? this.externalIds,
      matchConfidence: matchConfidence ?? this.matchConfidence,
      isAmbiguous: isAmbiguous ?? this.isAmbiguous,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'aetherId': aetherId.urn,
      'type': type.name,
      'canonicalTitle': canonicalTitle,
      if (releaseYear != null) 'releaseYear': releaseYear,
      if (runtimeMinutes != null) 'runtimeMinutes': runtimeMinutes,
      'externalIds': externalIds.toMap(),
      'matchConfidence': matchConfidence,
      'isAmbiguous': isAmbiguous,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory CanonicalMediaIdentity.fromMap(Map<String, dynamic> map) {
    return CanonicalMediaIdentity(
      aetherId: AetherId(map['aetherId'] as String),
      type: CanonicalMediaType.fromString(map['type'] as String? ?? 'movie'),
      canonicalTitle: map['canonicalTitle'] as String? ?? 'Untitled',
      releaseYear: map['releaseYear'] as int?,
      runtimeMinutes: map['runtimeMinutes'] as int?,
      externalIds: map['externalIds'] is Map<String, dynamic>
          ? ExternalIds.fromMap(map['externalIds'] as Map<String, dynamic>)
          : const ExternalIds(),
      matchConfidence: (map['matchConfidence'] as num?)?.toDouble() ?? 1.0,
      isAmbiguous: map['isAmbiguous'] as bool? ?? false,
      createdAt: map['createdAt'] != null
          ? DateTime.tryParse(map['createdAt'] as String) ?? DateTime.now()
          : DateTime.now(),
      updatedAt: map['updatedAt'] != null
          ? DateTime.tryParse(map['updatedAt'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  String toJson() => json.encode(toMap());

  factory CanonicalMediaIdentity.fromJson(String source) =>
      CanonicalMediaIdentity.fromMap(json.decode(source) as Map<String, dynamic>);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CanonicalMediaIdentity &&
          runtimeType == other.runtimeType &&
          aetherId == other.aetherId;

  @override
  int get hashCode => aetherId.hashCode;

  @override
  String toString() => 'CanonicalMediaIdentity($canonicalTitle ($releaseYear), id: $aetherId)';
}
