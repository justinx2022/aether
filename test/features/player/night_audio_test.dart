import 'package:flutter_test/flutter_test.dart';
import 'package:skystream/features/player/domain/night_audio.dart';

void main() {
  group('NightAudioComposer', () {
    test('returns pass-through reset when both modes are disabled', () {
      expect(
        NightAudioComposer.buildFilterCandidates(
          nightAudioEnabled: false,
          silenceDetectEnabled: false,
        ),
        const <String>[''],
      );
    });

    test('builds silencedetect-only graph when only auto-sync listens', () {
      final candidates = NightAudioComposer.buildFilterCandidates(
        nightAudioEnabled: false,
        silenceDetectEnabled: true,
      );
      expect(candidates, const <String>[
        'lavfi=[silencedetect=noise=-34dB:d=0.32]',
      ]);
    });

    test('primary night mode graph includes highpass, compressor, vocal EQ, normalizer, and limiter', () {
      final candidates = NightAudioComposer.buildFilterCandidates(
        nightAudioEnabled: true,
        silenceDetectEnabled: false,
      );
      expect(candidates.length, greaterThanOrEqualTo(4));
      final primary = candidates.first;
      expect(primary, startsWith('lavfi=['));
      expect(primary, contains('highpass=f=105'));
      expect(primary, contains('acompressor='));
      expect(primary, contains('makeup=5dB'));
      expect(primary, contains('equalizer=f=2400'));
      expect(primary, contains('dynaudnorm='));
      expect(primary, contains('alimiter='));
      expect(primary, isNot(contains('silencedetect')));

      // Progressive fallbacks omit heavier filters cleanly.
      expect(candidates[1], isNot(contains('equalizer=')));
      expect(candidates[2], isNot(contains('highpass=')));
      expect(candidates.last, isNot(startsWith('lavfi=')));
    });

    test('coexists with silencedetect across every night mode tier', () {
      final candidates = NightAudioComposer.buildFilterCandidates(
        nightAudioEnabled: true,
        silenceDetectEnabled: true,
      );
      expect(candidates, isNotEmpty);
      for (final c in candidates) {
        expect(c, contains('silencedetect=noise=-34dB:d=0.32'));
        expect(c, startsWith('lavfi=['));
      }
    });

    test('candidateForTier clamps out-of-range tier indices safely', () {
      final full = NightAudioComposer.candidateForTier(
        nightAudioEnabled: true,
        preferredTierIndex: 0,
      );
      final clampedHigh = NightAudioComposer.candidateForTier(
        nightAudioEnabled: true,
        preferredTierIndex: 99,
      );
      final clampedLow = NightAudioComposer.candidateForTier(
        nightAudioEnabled: true,
        preferredTierIndex: -3,
      );
      expect(clampedLow, full);
      expect(clampedHigh, isNotEmpty);
      expect(clampedHigh, isNot(full));
    });
  });
}
