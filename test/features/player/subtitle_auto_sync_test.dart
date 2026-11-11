import 'package:flutter_test/flutter_test.dart';
import 'package:skystream/features/player/domain/subtitle_auto_sync.dart';
import 'package:skystream/features/player/domain/subtitle_cues.dart';
import 'package:skystream/features/skip/data/skip_service.dart';

SubtitleCue _cue(double startSec, double endSec, String text) {
  return SubtitleCue(
    start: Duration(milliseconds: (startSec * 1000).round()),
    end: Duration(milliseconds: (endSec * 1000).round()),
    spans: <SubtitleSpan>[SubtitleSpan(text)],
  );
}

void main() {
  group('SubtitleAutoSyncEngine', () {
    test('parses valid ffmpeg silencedetect timestamps cleanly', () {
      expect(
        SubtitleAutoSyncEngine.parseSilenceEndSeconds(
          '[silencedetect @ 0x7f1a] silence_end: 134.850 | silence_duration: 1.120',
        ),
        closeTo(134.85, 0.0001),
      );
      expect(
        SubtitleAutoSyncEngine.parseSilenceEndSeconds(
          '[silencedetect @ 0x7f1a] silence_start: 133.73',
        ),
        isNull,
      );
      expect(
        SubtitleAutoSyncEngine.parseSilenceEndSeconds('unrelated log line'),
        isNull,
      );
    });

    test('filters SDH tags and marks post-pause spoken cues', () {
      final cues = <SubtitleCue>[
        _cue(1.0, 3.0, '[Dramatic music]'),
        _cue(4.0, 6.0, 'First spoken line'),
        _cue(6.1, 8.0, 'Quick reply'),
        _cue(9.5, 11.5, 'After pause line'),
      ];
      final spoken = SubtitleAutoSyncEngine.extractSpokenOnsets(cues);
      expect(spoken.length, 3);
      expect(spoken[0].startSec, closeTo(4.0, 0.001));
      expect(spoken[1].afterPause, isFalse);
      expect(spoken[2].afterPause, isTrue);
    });

    test('recovers true subtitle offset across multiple speech onsets despite outlier noise', () {
      // Real speech starts +3.40s later than subtitle timestamps.
      final cues = <SubtitleCue>[
        _cue(10.0, 12.0, 'Hey, are you ready?'),
        _cue(12.2, 13.8, 'Almost there.'),
        _cue(16.0, 18.2, 'Grab the keys before we go.'),
        _cue(21.5, 23.0, 'Wait outside!'),
        _cue(27.0, 29.0, 'See you in five.'),
      ];
      final onsets = <double>[
        13.40, // matches cue @10.0 (+3.40)
        19.42, // matches cue @16.0 (+3.42)
        24.88, // matches cue @21.5 (+3.38)
        30.40, // matches cue @27.0 (+3.40)
        22.10, // outlier cough / door slam
      ];

      final estimate = SubtitleAutoSyncEngine.estimateAcousticOffset(
        speechOnsetsSec: onsets,
        cues: cues,
      );
      expect(estimate, isNotNull);
      expect(estimate!.offsetSeconds, closeTo(3.40, 0.15));
      expect(estimate.matchedPairs, greaterThanOrEqualTo(4));
      expect(estimate.confidence, greaterThan(0.6));
      expect(estimate.reason, 'acoustic');
    });

    test('handles negative offsets (subtitles lagging behind audio)', () {
      // Subtitles at 45.0, 52.0, 60.0 while audio actually spoke 2.6s earlier.
      final cues = <SubtitleCue>[
        _cue(45.0, 47.0, 'Turn off the generator.'),
        _cue(52.0, 54.5, 'It is right behind the door.'),
        _cue(60.0, 62.0, 'Run now!'),
      ];
      final estimate = SubtitleAutoSyncEngine.estimateAcousticOffset(
        speechOnsetsSec: const <double>[42.4, 49.4, 57.4],
        cues: cues,
      );
      expect(estimate, isNotNull);
      expect(estimate!.offsetSeconds, closeTo(-2.6, 0.1));
    });

    test('snapToVoiceNow aligns nearest dialogue cue to current playback position', () {
      final cues = <SubtitleCue>[
        _cue(28.0, 30.0, 'Earlier line'),
        _cue(34.5, 36.5, 'Look at that ship!'),
        _cue(44.0, 46.0, 'Farther line'),
      ];
      final snap = SubtitleAutoSyncEngine.snapToVoiceNow(
        playbackPosition: const Duration(milliseconds: 36800),
        currentDelaySec: 0.0,
        cues: cues,
      );
      expect(snap, isNotNull);
      expect(snap!.offsetSeconds, closeTo(2.3, 0.05));
      expect(snap.reason, 'snap');
    });

    test('suggestIntroAlignment detects subtitles that started before skipped intro', () {
      final cues = <SubtitleCue>[
        _cue(2.0, 4.0, 'Previously on...'),
        _cue(10.0, 12.0, 'Recap one'),
        _cue(18.0, 20.0, 'Recap two'),
        _cue(25.0, 27.0, 'Recap three'),
        _cue(32.0, 34.0, 'Recap four'),
      ];
      final segments = <SkipSegment>[
        SkipSegment(
          startTime: 0,
          endTime: 42,
          type: SkipType.intro,
        ),
      ];
      final introEstimate = SubtitleAutoSyncEngine.suggestIntroAlignment(
        segments: segments,
        cues: cues,
      );
      expect(introEstimate, isNotNull);
      expect(introEstimate!.offsetSeconds, closeTo(42.0, 0.5));
      expect(introEstimate.reason, 'intro');
    });

    test('driftDeltaForFps computes accurate NTSC/PAL drift offset at timestamp', () {
      // At 30 minutes (1800s), 23.976 sub on 25fps video needs negative shift:
      final delta = SubtitleAutoSyncEngine.driftDeltaForFps(
        position: const Duration(minutes: 30),
        cueFps: 23.976,
        videoFps: 25.0,
      );
      expect(delta, closeTo(-73.7, 0.5));
    });
  });
}
