import 'dart:math';
import 'package:flutter/foundation.dart';
import '../domain/entity/canonical_media_identity.dart';

enum CdnEdgeType {
  cloudflare,
  bunnyCdn,
  cloudFront,
  fastly,
  akamai,
  directCustom,
  unknown;

  static CdnEdgeType fromHeaders(Map<String, String> headers) {
    final lowerHeaders = headers.map((k, v) => MapEntry(k.toLowerCase(), v.toLowerCase()));

    if (lowerHeaders.containsKey('cf-ray') || (lowerHeaders['server']?.contains('cloudflare') ?? false)) {
      return CdnEdgeType.cloudflare;
    }
    if (lowerHeaders.containsKey('cdn-pullzone') || (lowerHeaders['server']?.contains('bunnycdn') ?? false)) {
      return CdnEdgeType.bunnyCdn;
    }
    if (lowerHeaders.containsKey('x-amz-cf-id') || (lowerHeaders['server']?.contains('cloudfront') ?? false)) {
      return CdnEdgeType.cloudFront;
    }
    if (lowerHeaders.containsKey('fastly-debug-digest') || (lowerHeaders['server']?.contains('varnish') ?? false)) {
      return CdnEdgeType.fastly;
    }
    if (lowerHeaders.containsKey('x-akamai-transformed') || (lowerHeaders['server']?.contains('akamai') ?? false)) {
      return CdnEdgeType.akamai;
    }

    return CdnEdgeType.directCustom;
  }
}

@immutable
class StreamCandidate {
  final String url;
  final String providerName;
  final String quality; // '1080p', '720p', etc.
  final CdnEdgeType cdn;
  final int latencyMs;
  final double reliabilityScore;
  final Map<String, String> headers;

  const StreamCandidate({
    required this.url,
    required this.providerName,
    required this.quality,
    required this.cdn,
    required this.latencyMs,
    required this.reliabilityScore,
    this.headers = const {},
  });

  StreamCandidate copyWith({
    double? reliabilityScore,
    int? latencyMs,
    CdnEdgeType? cdn,
  }) {
    return StreamCandidate(
      url: url,
      providerName: providerName,
      quality: quality,
      cdn: cdn ?? this.cdn,
      latencyMs: latencyMs ?? this.latencyMs,
      reliabilityScore: reliabilityScore ?? this.reliabilityScore,
      headers: headers,
    );
  }
}

/// Core Provider Intelligence Engine: performs CDN identification, candidate deduplication,
/// reliability scoring, and automatic stream recovery.
class ProviderIntelligenceDomain {
  static const double _w1Reliability = 0.40;
  static const double _w2Latency = 0.25;
  static const double _w3Resolution = 0.25;
  static const double _w4Penalties = 0.10;
  static const int _kMaxTtfbMs = 3000;

  final Map<String, double> _providerHealthEma = {};

  ProviderIntelligenceDomain();

  /// Records a successful playback start or segment probe for a provider.
  void recordSuccess(String providerName, int latencyMs) {
    final current = _providerHealthEma[providerName] ?? 0.85;
    // Exponential Moving Average (alpha = 0.2)
    _providerHealthEma[providerName] = (0.2 * 1.0) + (0.8 * current);
  }

  /// Records a provider failure (403, 404, or timeout).
  void recordFailure(String providerName, String reason) {
    final current = _providerHealthEma[providerName] ?? 0.85;
    _providerHealthEma[providerName] = (0.2 * 0.0) + (0.8 * current);
  }

  /// Calculates composite score for a stream candidate using the Aether Core formula.
  double computeCompositeScore({
    required String providerName,
    required int latencyMs,
    required String quality,
    required CdnEdgeType cdn,
    bool requiresProxy = false,
  }) {
    final sReliability = _providerHealthEma[providerName] ?? 0.85;
    final sLatency = (1.0 - (latencyMs / _kMaxTtfbMs)).clamp(0.0, 1.0);

    double sResolution = 0.5;
    if (quality.contains('1080') || quality.contains('4k') || quality.contains('uhd')) {
      sResolution = 1.0;
    } else if (quality.contains('720')) {
      sResolution = 0.75;
    } else if (quality.contains('480') || quality.contains('360')) {
      sResolution = 0.40;
    }

    double penalties = 0.0;
    if (requiresProxy) penalties += 0.05;
    if (cdn == CdnEdgeType.unknown) penalties += 0.05;

    final score = (_w1Reliability * sReliability) +
        (_w2Latency * sLatency) +
        (_w3Resolution * sResolution) -
        (_w4Penalties * penalties);

    return score.clamp(0.0, 1.0);
  }

  /// Prunes duplicate candidates that resolve to the same underlying CDN host
  /// and identical quality renditions.
  List<StreamCandidate> deduplicateCandidates(List<StreamCandidate> candidates) {
    final seen = <String, StreamCandidate>{};

    for (final candidate in candidates) {
      final host = _extractHost(candidate.url);
      final key = '${candidate.cdn.name}:$host:${candidate.quality}';

      if (!seen.containsKey(key)) {
        seen[key] = candidate;
      } else {
        // Keep the one with higher composite score or lower latency
        final existing = seen[key]!;
        if (candidate.reliabilityScore > existing.reliabilityScore ||
            (candidate.reliabilityScore == existing.reliabilityScore && candidate.latencyMs < existing.latencyMs)) {
          seen[key] = candidate;
        }
      }
    }

    final result = seen.values.toList();
    // Sort best first
    result.sort((a, b) => b.reliabilityScore.compareTo(a.reliabilityScore));
    return result;
  }

  static String _extractHost(String url) {
    try {
      final uri = Uri.parse(url);
      return uri.host.toLowerCase();
    } catch (_) {
      return url;
    }
  }
}
