import 'package:flutter_test/flutter_test.dart';

import 'package:aether/core/profile/user_profile.dart';
import 'package:aether/core/services/tmdb_service.dart';
import 'package:aether/shared/widgets/maturity_rating.dart';

/// Security and content-rating gates: PIN hashing/verification, profile
/// serialization, the maturity ladder, and TMDB genre-id translation.
///
/// The profile/PIN area is the app's security boundary (profiles gate
/// playback via the maturity ceiling), so its crypto and its persistence
/// round-trip are pinned here.
void main() {
  group('UserProfile PIN hashing', () {
    test('PBKDF2 hash verifies the correct PIN', () {
      final salt = UserProfile.generateSalt();
      final hash = UserProfile.hashPinPbkdf2('1234', salt);

      final profile = UserProfile(
        id: 'p1',
        name: 'A',
        avatarId: 'avatar_void',
        pinHash: hash,
        pinSalt: salt,
        createdAt: DateTime(2026),
      );

      expect(profile.hasPin, isTrue);
      expect(profile.verifyPin('1234'), isTrue);
      expect(profile.verifyPin('0000'), isFalse);
      expect(profile.verifyPin(''), isFalse);
    });

    test('PBKDF2 hashes are salted — same PIN, different salts', () {
      final h1 = UserProfile.hashPinPbkdf2('1234', UserProfile.generateSalt());
      final h2 = UserProfile.hashPinPbkdf2('1234', UserProfile.generateSalt());
      expect(h1, isNot(h2));
    });

    test('legacy salted SHA-256 fallback verifies', () {
      final salt = UserProfile.generateSalt();
      final hash = UserProfile.hashPinWithSalt('9999', salt);

      final profile = UserProfile(
        id: 'p2',
        name: 'B',
        avatarId: 'avatar_void',
        pinHash: hash,
        pinSalt: salt,
        createdAt: DateTime(2026),
      );

      expect(profile.verifyPin('9999'), isTrue);
      expect(profile.verifyPin('1234'), isFalse);
    });

    test('profile without PIN always verifies', () {
      final profile = UserProfile(
        id: 'p3',
        name: 'C',
        avatarId: 'avatar_void',
        createdAt: DateTime(2026),
      );
      expect(profile.hasPin, isFalse);
      expect(profile.verifyPin('anything'), isTrue);
    });

    test('legacy plaintext pin still verifies (pre-migration profiles)', () {
      final profile = UserProfile(
        id: 'p4',
        name: 'D',
        avatarId: 'avatar_void',
        pin: '4321',
        createdAt: DateTime(2026),
      );
      expect(profile.hasPin, isTrue);
      expect(profile.verifyPin('4321'), isTrue);
      expect(profile.verifyPin('1234'), isFalse);
    });
  });

  group('Profile serialization', () {
    test('map round trip preserves hash, salt and maturity', () {
      final salt = UserProfile.generateSalt();
      final hash = UserProfile.hashPinPbkdf2('7777', salt);
      final profile = UserProfile(
        id: 'p5',
        name: 'E',
        avatarId: 'avatar_aurora',
        pinHash: hash,
        pinSalt: salt,
        isKids: true,
        isPrimary: true,
        preferredGenres: const ['Action', 'Sci-Fi'],
        feedMode: 'movies',
        maturityRating: '13+',
        createdAt: DateTime(2026, 1, 2),
      );

      final restored = UserProfile.fromMap(profile.toMap());
      expect(restored.id, 'p5');
      expect(restored.pinHash, hash);
      expect(restored.pinSalt, salt);
      expect(restored.verifyPin('7777'), isTrue);
      expect(restored.maturityRating, '13+');
      expect(restored.isKids, isTrue);
      expect(restored.preferredGenres, ['Action', 'Sci-Fi']);
    });

    test('fromMap defaults maturityRating to 18+ on legacy data', () {
      final restored = UserProfile.fromMap({
        'id': 'legacy',
        'name': 'Old',
        'avatarId': 'avatar_void',
        'createdAt': '2020-01-01T00:00:00.000',
      });
      expect(restored.maturityRating, '18+');
    });
  });

  group('Maturity ladder', () {
    test('MPAA film ratings collapse onto the right tiers', () {
      expect(maturityTier('G'), 'All');
      expect(maturityTier('PG'), '7+');
      expect(maturityTier('PG-13'), '13+');
      expect(maturityTier('R'), '16+');
      expect(maturityTier('NC-17'), '18+');
    });

    test('US TV ratings collapse onto the right tiers', () {
      expect(maturityTier('TV-Y'), 'All');
      expect(maturityTier('TV-Y7'), '7+');
      expect(maturityTier('TV-PG'), '7+');
      expect(maturityTier('TV-14'), '13+');
      expect(maturityTier('TV-MA'), '16+');
    });

    test('unknown or empty certifications land mid-ladder, not at the top', () {
      expect(maturityTier(null), '13+');
      expect(maturityTier(''), '13+');
      expect(maturityTier('weird-scale-9'), '13+');
    });

    test('gate blocks only when the title sits above the profile ceiling', () {
      expect(exceedsMaturityRating('NC-17', '18+'), isFalse);
      expect(exceedsMaturityRating('PG-13', '13+'), isFalse);
      expect(exceedsMaturityRating('R', '13+'), isTrue);
      expect(exceedsMaturityRating('TV-MA', '13+'), isTrue);
      expect(exceedsMaturityRating('G', '13+'), isFalse);
      expect(exceedsMaturityRating('PG-13', '7+'), isTrue);
      expect(exceedsMaturityRating('TV-Y7', '7+'), isFalse);
    });

    test('ladder is ordered from least to most restrictive', () {
      expect(kMaturityTiers, ['All', '7+', '13+', '16+', '18+']);
      for (var i = 0; i < kMaturityTiers.length - 1; i++) {
        expect(maturityRank(kMaturityTiers[i]),
            lessThan(maturityRank(kMaturityTiers[i + 1])));
      }
    });
  });

  group('TMDB genre-id translation', () {
    test('movie-only ids translate into the TV vocabulary', () {
      expect(TmdbService.translateGenreId(28, isMovie: false), 10759);
      expect(TmdbService.translateGenreId(878, isMovie: false), 10765);
      expect(TmdbService.translateGenreId(14, isMovie: false), 10765);
    });

    test('tv-only ids translate into the movie vocabulary', () {
      expect(TmdbService.translateGenreId(10759, isMovie: true), 28);
      expect(TmdbService.translateGenreId(10765, isMovie: true), 878);
      expect(TmdbService.translateGenreId(10762, isMovie: true), 10751);
    });

    test('shared ids pass through unchanged in both directions', () {
      expect(TmdbService.translateGenreId(35, isMovie: true), 35);
      expect(TmdbService.translateGenreId(35, isMovie: false), 35);
      expect(TmdbService.translateGenreId(18, isMovie: false), 18);
      expect(TmdbService.translateGenreId(99, isMovie: true), 99);
    });
  });
}
