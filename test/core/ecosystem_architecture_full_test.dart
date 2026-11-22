import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aether/core/domain/entity/aether_id.dart';
import 'package:aether/core/domain/entity/canonical_media_identity.dart';
import 'package:aether/core/player/playback_session.dart';
import 'package:aether/core/player/playback_coordinator.dart';
import 'package:aether/core/providers/provider_intelligence_domain.dart';
import 'package:aether/core/orchestrator/background_orchestrator.dart';

void main() {
  group('PlaybackSession Tests', () {
    test('session creation initializes correctly with progress and completion checks', () {
      final identity = CanonicalMediaIdentity(
        aetherId: AetherId.generate(),
        type: CanonicalMediaType.movie,
        canonicalTitle: 'Oppenheimer',
        releaseYear: 2023,
        externalIds: const ExternalIds(tmdbId: 872585),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final session = PlaybackSession.create(
        mediaIdentity: identity,
        profileId: 'profile-1',
        initialPositionMs: 0,
        durationMs: 10800000, // 3 hours
      );

      expect(session.sessionId.startsWith('sess_'), isTrue);
      expect(session.stage, equals(PlaybackStage.initializing));
      expect(session.progressFraction, equals(0.0));
      expect(session.isCompleted, isFalse);

      final progressed = session.copyWith(
        currentPositionMs: 10000000, // > 92%
        stage: PlaybackStage.activePlaying,
      );

      expect(progressed.progressFraction, greaterThanOrEqualTo(0.92));
      expect(progressed.isCompleted, isTrue);
    });
  });

  group('ProviderIntelligenceDomain Tests', () {
    late ProviderIntelligenceDomain domain;

    setUp(() {
      domain = ProviderIntelligenceDomain();
    });

    test('CDN fingerprint identification detects Cloudflare and BunnyCDN from headers', () {
      final cfHeaders = {'Server': 'cloudflare', 'CF-RAY': '8d2a1b9f8e70-LHR'};
      final bunnyHeaders = {'Server': 'BunnyCDN-DE1', 'CDN-PullZone': '775336'};
      final directHeaders = {'Server': 'nginx/1.24'};

      expect(CdnEdgeType.fromHeaders(cfHeaders), equals(CdnEdgeType.cloudflare));
      expect(CdnEdgeType.fromHeaders(bunnyHeaders), equals(CdnEdgeType.bunnyCdn));
      expect(CdnEdgeType.fromHeaders(directHeaders), equals(CdnEdgeType.directCustom));
    });

    test('deduplicateCandidates prunes duplicate CDN hosts keeping higher score', () {
      const c1 = StreamCandidate(
        url: 'https://mirror1.cdn-example.com/hls/master.m3u8',
        providerName: 'ProviderA',
        quality: '1080p',
        cdn: CdnEdgeType.cloudflare,
        latencyMs: 120,
        reliabilityScore: 0.90,
      );

      const c2 = StreamCandidate(
        url: 'https://mirror1.cdn-example.com/stream/manifest.m3u8',
        providerName: 'ProviderB',
        quality: '1080p',
        cdn: CdnEdgeType.cloudflare,
        latencyMs: 280,
        reliabilityScore: 0.75,
      );

      const c3 = StreamCandidate(
        url: 'https://backup-stream.bunny.net/video.m3u8',
        providerName: 'ProviderC',
        quality: '1080p',
        cdn: CdnEdgeType.bunnyCdn,
        latencyMs: 150,
        reliabilityScore: 0.88,
      );

      final deduped = domain.deduplicateCandidates([c1, c2, c3]);

      // c1 and c2 share mirror1.cdn-example.com at 1080p, so only c1 should survive alongside c3
      expect(deduped.length, equals(2));
      expect(deduped.first.providerName, equals('ProviderA'));
      expect(deduped.any((c) => c.providerName == 'ProviderB'), isFalse);
      expect(deduped.any((c) => c.providerName == 'ProviderC'), isTrue);
    });

    test('composite score favors low latency and 1080p resolution', () {
      final highResScore = domain.computeCompositeScore(
        providerName: 'FastProvider',
        latencyMs: 150,
        quality: '1080p',
        cdn: CdnEdgeType.cloudflare,
      );

      final lowResScore = domain.computeCompositeScore(
        providerName: 'FastProvider',
        latencyMs: 150,
        quality: '480p',
        cdn: CdnEdgeType.cloudflare,
      );

      expect(highResScore, greaterThan(lowResScore));
    });
  });

  group('BackgroundOrchestrator Tests', () {
    test('priority queue schedules P0 tasks ahead of lower priority tasks', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final orchestrator = container.read(backgroundOrchestratorProvider);
      final executedOrder = <String>[];

      // Submit P2 task first, then P0 task
      final f2 = orchestrator.submit(
        id: 'task-p2',
        priority: TaskPriority.p2Opportunistic,
        action: () async {
          executedOrder.add('P2');
        },
      );

      final f0 = orchestrator.submit(
        id: 'task-p0',
        priority: TaskPriority.p0Critical,
        action: () async {
          executedOrder.add('P0');
        },
      );

      await Future.wait([f0, f2]);

      expect(executedOrder, containsAllInOrder(['P0', 'P2']));
    });

    test('cancel removes pending task without executing it', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final orchestrator = container.read(backgroundOrchestratorProvider);
      bool executed = false;

      orchestrator.submit(
        id: 'cancellable-task',
        priority: TaskPriority.p3Maintenance,
        action: () async {
          executed = true;
        },
      );

      orchestrator.cancel('cancellable-task');
      await Future<void>.delayed(const Duration(milliseconds: 30));

      expect(executed, isFalse);
    });
  });
}
