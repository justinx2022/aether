import 'dart:math';
import 'package:flutter/foundation.dart';
import '../entity/aether_id.dart';
import '../entity/canonical_media_identity.dart';
import '../entity/multimedia_item.dart';

@immutable
class MatchResult {
  final CanonicalMediaIdentity? identity;
  final double confidence;
  final bool isAmbiguous;
  final String? matchReason;

  const MatchResult({
    this.identity,
    required this.confidence,
    this.isAmbiguous = false,
    this.matchReason,
  });

  bool get isConfidentMatch => identity != null && confidence >= 0.85 && !isAmbiguous;
}

/// Central registry managing external IDs (TMDB, IMDb, AniList, TVDB, Provider Tokens)
/// and resolving incoming raw metadata into authoritative [CanonicalMediaIdentity] entities.
class ExternalIdRegistry {
  final Map<AetherId, CanonicalMediaIdentity> _identities = {};
  final Map<String, AetherId> _tmdbIndex = {};
  final Map<String, AetherId> _imdbIndex = {};
  final Map<int, AetherId> _anilistIndex = {};
  final Map<int, AetherId> _tvdbIndex = {};
  final Map<String, AetherId> _providerTokenIndex = {};

  ExternalIdRegistry();

  int get count => _identities.length;

  /// Looks up a canonical identity directly by its [AetherId].
  CanonicalMediaIdentity? getById(AetherId id) => _identities[id];

  /// Looks up a canonical identity by string URN.
  CanonicalMediaIdentity? getByUrn(String urn) {
    final aetherId = AetherId.tryParse(urn);
    return aetherId != null ? _identities[aetherId] : null;
  }

  /// Evaluates an incoming candidate against known entries using the 4-tier confidence matching algorithm.
  MatchResult match({
    required String title,
    CanonicalMediaType type = CanonicalMediaType.movie,
    int? year,
    int? runtimeMinutes,
    int? tmdbId,
    String? imdbId,
    int? anilistId,
    int? tvdbId,
    Map<String, String>? providerTokens,
  }) {
    // ── Tier 1: Exact Namespace Authoritative Match (Confidence 1.0) ──
    if (tmdbId != null && tmdbId > 0) {
      final key = '${type.name}:$tmdbId';
      final aetherId = _tmdbIndex[key];
      if (aetherId != null && _identities.containsKey(aetherId)) {
        return MatchResult(
          identity: _identities[aetherId],
          confidence: 1.0,
          matchReason: 'Exact TMDB ID match ($tmdbId)',
        );
      }
    }

    if (imdbId != null && imdbId.startsWith('tt')) {
      final aetherId = _imdbIndex[imdbId];
      if (aetherId != null && _identities.containsKey(aetherId)) {
        return MatchResult(
          identity: _identities[aetherId],
          confidence: 1.0,
          matchReason: 'Exact IMDb ID match ($imdbId)',
        );
      }
    }

    if (anilistId != null && anilistId > 0) {
      final aetherId = _anilistIndex[anilistId];
      if (aetherId != null && _identities.containsKey(aetherId)) {
        return MatchResult(
          identity: _identities[aetherId],
          confidence: 1.0,
          matchReason: 'Exact AniList ID match ($anilistId)',
        );
      }
    }

    if (tvdbId != null && tvdbId > 0) {
      final aetherId = _tvdbIndex[tvdbId];
      if (aetherId != null && _identities.containsKey(aetherId)) {
        return MatchResult(
          identity: _identities[aetherId],
          confidence: 1.0,
          matchReason: 'Exact TVDB ID match ($tvdbId)',
        );
      }
    }

    // Check provider tokens
    if (providerTokens != null) {
      for (final entry in providerTokens.entries) {
        final key = '${entry.key}:${entry.value}';
        final aetherId = _providerTokenIndex[key];
        if (aetherId != null && _identities.containsKey(aetherId)) {
          return MatchResult(
            identity: _identities[aetherId],
            confidence: 0.98,
            matchReason: 'Known provider token match ($key)',
          );
        }
      }
    }

    // ── Tier 2 & 3: Multi-Attribute Corroboration & Ambiguity Detection ──
    final normalizedCandidateTitle = _normalize(title);
    if (normalizedCandidateTitle.isEmpty) {
      return const MatchResult(confidence: 0.0);
    }

    CanonicalMediaIdentity? bestCandidate;
    double highestScore = 0.0;
    int closeMatchCount = 0;

    for (final identity in _identities.values) {
      if (identity.type != type) continue;

      final existingNormTitle = _normalize(identity.canonicalTitle);
      final sim = _levenshteinSimilarity(normalizedCandidateTitle, existingNormTitle);

      if (sim < 0.80) continue;

      double score = sim * 0.70;

      // Year matching
      if (year != null && identity.releaseYear != null) {
        final yearDelta = (year - identity.releaseYear!).abs();
        if (yearDelta == 0) {
          score += 0.20;
        } else if (yearDelta == 1) {
          score += 0.08;
        } else {
          score -= 0.25; // Year mismatch penalty
        }
      } else {
        score += 0.05; // Neutral
      }

      // Runtime matching (if available)
      if (runtimeMinutes != null && identity.runtimeMinutes != null) {
        final runtimeDelta = (runtimeMinutes - identity.runtimeMinutes!).abs();
        if (runtimeDelta <= 3) {
          score += 0.10;
        } else if (runtimeDelta > 15) {
          score -= 0.15;
        }
      }

      if (score > highestScore) {
        if (highestScore > 0.80 && (score - highestScore) < 0.05) {
          closeMatchCount++;
        }
        highestScore = score;
        bestCandidate = identity;
      }
    }

    if (bestCandidate != null) {
      if (closeMatchCount > 0 || highestScore < 0.85) {
        return MatchResult(
          identity: bestCandidate,
          confidence: highestScore.clamp(0.0, 1.0),
          isAmbiguous: true,
          matchReason: 'Ambiguous candidate detected with close title/year scores',
        );
      }

      return MatchResult(
        identity: bestCandidate,
        confidence: highestScore.clamp(0.0, 1.0),
        matchReason: 'High confidence multi-attribute title match',
      );
    }

    return const MatchResult(confidence: 0.0);
  }

  /// Resolves an incoming item against the registry. If a confident match exists,
  /// merges external IDs. Otherwise registers a new [CanonicalMediaIdentity].
  CanonicalMediaIdentity resolveOrRegister({
    required String title,
    CanonicalMediaType type = CanonicalMediaType.movie,
    int? year,
    int? runtimeMinutes,
    int? tmdbId,
    String? imdbId,
    int? anilistId,
    int? tvdbId,
    Map<String, String>? providerTokens,
  }) {
    final matchResult = match(
      title: title,
      type: type,
      year: year,
      runtimeMinutes: runtimeMinutes,
      tmdbId: tmdbId,
      imdbId: imdbId,
      anilistId: anilistId,
      tvdbId: tvdbId,
      providerTokens: providerTokens,
    );

    if (matchResult.isConfidentMatch && matchResult.identity != null) {
      final existing = matchResult.identity!;
      final mergedExt = existing.externalIds.mergeWith(
        ExternalIds(
          tmdbId: tmdbId,
          imdbId: imdbId,
          anilistId: anilistId,
          tvdbId: tvdbId,
          providerTokens: providerTokens ?? const {},
        ),
      );

      final updated = existing.copyWith(
        externalIds: mergedExt,
        releaseYear: existing.releaseYear ?? year,
        runtimeMinutes: existing.runtimeMinutes ?? runtimeMinutes,
        updatedAt: DateTime.now(),
      );

      _register(updated);
      return updated;
    }

    // Register a new canonical identity
    final newIdentity = CanonicalMediaIdentity(
      aetherId: AetherId.generate(),
      type: type,
      canonicalTitle: title.trim(),
      releaseYear: year,
      runtimeMinutes: runtimeMinutes,
      externalIds: ExternalIds(
        tmdbId: tmdbId,
        imdbId: imdbId,
        anilistId: anilistId,
        tvdbId: tvdbId,
        providerTokens: providerTokens ?? const {},
      ),
      matchConfidence: matchResult.isAmbiguous ? matchResult.confidence : 1.0,
      isAmbiguous: matchResult.isAmbiguous,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    _register(newIdentity);
    return newIdentity;
  }

  void _register(CanonicalMediaIdentity identity) {
    _identities[identity.aetherId] = identity;

    if (identity.externalIds.tmdbId != null) {
      final key = '${identity.type.name}:${identity.externalIds.tmdbId}';
      _tmdbIndex[key] = identity.aetherId;
    }
    if (identity.externalIds.imdbId != null && identity.externalIds.imdbId!.isNotEmpty) {
      _imdbIndex[identity.externalIds.imdbId!] = identity.aetherId;
    }
    if (identity.externalIds.anilistId != null) {
      _anilistIndex[identity.externalIds.anilistId!] = identity.aetherId;
    }
    if (identity.externalIds.tvdbId != null) {
      _tvdbIndex[identity.externalIds.tvdbId!] = identity.aetherId;
    }
    for (final entry in identity.externalIds.providerTokens.entries) {
      _providerTokenIndex['${entry.key}:${entry.value}'] = identity.aetherId;
    }
  }

  static String _normalize(String input) {
    return input
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\s]'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  static double _levenshteinSimilarity(String s1, String s2) {
    if (s1 == s2) return 1.0;
    if (s1.isEmpty || s2.isEmpty) return 0.0;

    final d = List.generate(
      s1.length + 1,
      (i) => List.generate(s2.length + 1, (j) => 0),
    );

    for (int i = 0; i <= s1.length; i++) {
      d[i][0] = i;
    }
    for (int j = 0; j <= s2.length; j++) {
      d[0][j] = j;
    }

    for (int i = 1; i <= s1.length; i++) {
      for (int j = 1; j <= s2.length; j++) {
        final cost = s1[i - 1] == s2[j - 1] ? 0 : 1;
        d[i][j] = min(
          min(d[i - 1][j] + 1, d[i][j - 1] + 1),
          d[i - 1][j - 1] + cost,
        );
      }
    }

    final distance = d[s1.length][s2.length];
    final maxLen = max(s1.length, s2.length);
    return (1.0 - (distance / maxLen)).clamp(0.0, 1.0);
  }
}

/// Extension on legacy [MultimediaItem] for seamless bidirectional interoperability.
extension MultimediaItemCanonicalBridge on MultimediaItem {
  CanonicalMediaIdentity toCanonicalIdentity(ExternalIdRegistry registry) {
    final mediaType = switch (contentType) {
      MultimediaContentType.series => CanonicalMediaType.series,
      MultimediaContentType.anime => CanonicalMediaType.anime,
      _ => CanonicalMediaType.movie,
    };

    return registry.resolveOrRegister(
      title: title,
      type: mediaType,
      year: year,
      imdbId: (imdbId != null && imdbId!.isNotEmpty) ? imdbId : null,
      tmdbId: tmdbId,
      providerTokens: provider != null && url.isNotEmpty ? {provider!: url} : null,
    );
  }
}
