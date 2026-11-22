import 'package:flutter_test/flutter_test.dart';
import 'package:aether/core/domain/entity/aether_id.dart';
import 'package:aether/core/domain/entity/canonical_media_identity.dart';
import 'package:aether/core/domain/identity/external_id_registry.dart';
import 'package:aether/core/events/aether_event.dart';
import 'package:aether/core/events/aether_event_bus.dart';

void main() {
  group('AetherId Tests', () {
    test('generate creates valid UUIDv7 format starting with urn:aether:media:', () {
      final id1 = AetherId.generate();
      final id2 = AetherId.generate();

      expect(id1.urn.startsWith('urn:aether:media:'), isTrue);
      expect(id2.urn.startsWith('urn:aether:media:'), isTrue);
      expect(id1, isNot(equals(id2)));
      expect(id1.hashCode, isNot(equals(id2.hashCode)));
    });

    test('parse and tryParse validate correct URN prefix', () {
      final valid = AetherId.parse('urn:aether:media:018f2d5a-8b3c-7c3a-9e12-4d2a1b9f8e70');
      expect(valid.urn, 'urn:aether:media:018f2d5a-8b3c-7c3a-9e12-4d2a1b9f8e70');

      expect(() => AetherId.parse('invalid:urn'), throwsFormatException);
      expect(AetherId.tryParse('invalid:urn'), isNull);
      expect(AetherId.tryParse(null), isNull);
    });

    test('equality and hashCode are based on URN string', () {
      const urn = 'urn:aether:media:test-123';
      final idA = AetherId(urn);
      final idB = AetherId(urn);

      expect(idA, equals(idB));
      expect(idA.hashCode, equals(idB.hashCode));
    });
  });

  group('CanonicalMediaIdentity Tests', () {
    test('serializes and deserializes cleanly to Map and JSON', () {
      final original = CanonicalMediaIdentity(
        aetherId: AetherId.generate(),
        type: CanonicalMediaType.movie,
        canonicalTitle: 'Inception',
        releaseYear: 2010,
        runtimeMinutes: 148,
        externalIds: const ExternalIds(
          tmdbId: 27205,
          imdbId: 'tt1375666',
          providerTokens: {'vixsrc': 'movie/inception'},
        ),
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      );

      final jsonStr = original.toJson();
      final restored = CanonicalMediaIdentity.fromJson(jsonStr);

      expect(restored.aetherId, equals(original.aetherId));
      expect(restored.canonicalTitle, equals('Inception'));
      expect(restored.releaseYear, equals(2010));
      expect(restored.runtimeMinutes, equals(148));
      expect(restored.externalIds.tmdbId, equals(27205));
      expect(restored.externalIds.imdbId, equals('tt1375666'));
      expect(restored.externalIds.providerTokens['vixsrc'], equals('movie/inception'));
      expect(restored, equals(original));
    });

    test('episodeUrn formats deterministically with season and episode', () {
      final identity = CanonicalMediaIdentity(
        aetherId: const AetherId('urn:aether:media:breaking-bad-id'),
        type: CanonicalMediaType.series,
        canonicalTitle: 'Breaking Bad',
        releaseYear: 2008,
        externalIds: const ExternalIds(tmdbId: 1396),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      expect(identity.episodeUrn(1, 1), 'urn:aether:media:breaking-bad-id:s1e1');
      expect(identity.episodeUrn(5, 14), 'urn:aether:media:breaking-bad-id:s5e14');
    });
  });

  group('ExternalIdRegistry Tests', () {
    late ExternalIdRegistry registry;

    setUp(() {
      registry = ExternalIdRegistry();
    });

    test('Tier 1: Authoritative match on TMDB ID returns Confidence 1.0', () {
      // 1. First registration
      final registered = registry.resolveOrRegister(
        title: 'Dune: Part Two',
        year: 2024,
        tmdbId: 693134,
        imdbId: 'tt15239678',
      );

      // 2. Lookup via TMDB ID under different title variation
      final match = registry.match(
        title: 'Dune 2 (IMAX)',
        year: 2024,
        tmdbId: 693134,
      );

      expect(match.isConfidentMatch, isTrue);
      expect(match.confidence, equals(1.0));
      expect(match.identity?.aetherId, equals(registered.aetherId));
    });

    test('Tier 1: Authoritative match on IMDb ID returns Confidence 1.0', () {
      final registered = registry.resolveOrRegister(
        title: 'Oppenheimer',
        year: 2023,
        imdbId: 'tt15398776',
      );

      final match = registry.match(
        title: 'Oppenheimer Feature Film',
        imdbId: 'tt15398776',
      );

      expect(match.isConfidentMatch, isTrue);
      expect(match.confidence, equals(1.0));
      expect(match.identity?.aetherId, equals(registered.aetherId));
    });

    test('Tier 2: High confidence title + exact year match without IDs', () {
      final registered = registry.resolveOrRegister(
        title: 'Blade Runner 2049',
        year: 2017,
        runtimeMinutes: 164,
        tmdbId: 335984,
      );

      final match = registry.match(
        title: 'Blade Runner 2049',
        year: 2017,
        runtimeMinutes: 164,
      );

      expect(match.isConfidentMatch, isTrue);
      expect(match.confidence, greaterThanOrEqualTo(0.85));
      expect(match.identity?.aetherId, equals(registered.aetherId));
    });

    test('Tier 3: Flagged as ambiguous when year mismatch occurs on similar title', () {
      registry.resolveOrRegister(
        title: 'Spider-Man',
        year: 2002,
        tmdbId: 557,
      );

      final match = registry.match(
        title: 'Spider-Man',
        year: 2021, // No Way Home year
      );

      // Confidence is penalized for year mismatch
      expect(match.isConfidentMatch, isFalse);
    });

    test('Consecutive discoveries merge external IDs seamlessly', () {
      // Discover from Search with TMDB only
      final first = registry.resolveOrRegister(
        title: 'Succession',
        type: CanonicalMediaType.series,
        year: 2018,
        tmdbId: 76331,
      );
      expect(first.externalIds.imdbId, isNull);

      // Subsequent discovery from scraper provides IMDb and provider token
      final merged = registry.resolveOrRegister(
        title: 'Succession',
        type: CanonicalMediaType.series,
        tmdbId: 76331,
        imdbId: 'tt7660850',
        providerTokens: {'vidzee': 'series/76331'},
      );

      expect(merged.aetherId, equals(first.aetherId));
      expect(merged.externalIds.imdbId, equals('tt7660850'));
      expect(merged.externalIds.providerTokens['vidzee'], equals('series/76331'));
      expect(registry.count, equals(1));
    });
  });

  group('AetherEventBus Tests', () {
    late AetherEventBus bus;

    setUp(() {
      bus = AetherEventBus.instance;
    });

    test('publishes and receives typed events', () async {
      final identity = CanonicalMediaIdentity(
        aetherId: const AetherId('urn:aether:media:test-evt-media'),
        type: CanonicalMediaType.movie,
        canonicalTitle: 'Interstellar',
        releaseYear: 2014,
        externalIds: const ExternalIds(tmdbId: 157336),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final eventsReceived = <PlaybackMilestoneCommittedEvent>[];
      final sub = bus.on<PlaybackMilestoneCommittedEvent>().listen(eventsReceived.add);

      bus.publish(
        PlaybackMilestoneCommittedEvent(
          sessionId: 'session-123',
          mediaIdentity: identity,
          positionMs: 60000,
          durationMs: 7200000,
        ),
      );

      await Future<void>.delayed(const Duration(milliseconds: 20));
      await sub.cancel();

      expect(eventsReceived.length, equals(1));
      expect(eventsReceived.first.sessionId, equals('session-123'));
      expect(eventsReceived.first.positionMs, equals(60000));
      expect(eventsReceived.first.progressFraction, closeTo(60000 / 7200000, 0.001));
    });

    test('subscriber isolation: throwing subscriber does not break other subscribers', () async {
      final identity = CanonicalMediaIdentity(
        aetherId: const AetherId('urn:aether:media:test-iso'),
        type: CanonicalMediaType.movie,
        canonicalTitle: 'Isolation Test',
        externalIds: const ExternalIds(),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      bool healthySubscriberReceived = false;
      bool errorCaptured = false;

      // Faulty subscriber
      final sub1 = bus.subscribe<PlaybackCompletedEvent>(
        (evt) {
          throw StateError('Simulated faulty subscriber explosion!');
        },
        onError: (err, stack) {
          errorCaptured = true;
        },
      );

      // Healthy subscriber
      final sub2 = bus.subscribe<PlaybackCompletedEvent>(
        (evt) {
          healthySubscriberReceived = true;
        },
      );

      bus.publish(
        PlaybackCompletedEvent(
          sessionId: 'session-err-test',
          mediaIdentity: identity,
        ),
      );

      await Future<void>.delayed(const Duration(milliseconds: 30));
      await sub1.cancel();
      await sub2.cancel();

      expect(errorCaptured, isTrue);
      expect(healthySubscriberReceived, isTrue);
    });
  });
}
