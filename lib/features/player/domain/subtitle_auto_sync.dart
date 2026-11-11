import 'dart:math' as math;

import '../../skip/data/skip_service.dart';
import 'subtitle_cues.dart';

/// Result of analyzing speech onsets / playback markers against timed subtitles.
class SubtitleSyncEstimate {
  const SubtitleSyncEstimate({
    required this.offsetSeconds,
    required this.confidence,
    required this.matchedPairs,
    this.reason = '',
  });

  /// Recommended total `sub-delay` value in seconds (`speechTime - cueStart`).
  final double offsetSeconds;

  /// Match confidence between `0.0` (weak) and `1.0` (locked in).
  final double confidence;

  /// Number of observed speech onsets aligning with dialogue cues.
  final int matchedPairs;

  /// Short diagnostic tag (e.g. `'acoustic'`, `'snap'`, `'intro'`).
  final String reason;
}

/// Automatic and semi-automatic subtitle synchronization engine.
///
/// Combines three strategies cleanly in pure Dart:
/// 1. **Acoustic Speech-Onset Correlation**: Parses FFmpeg/libmpv `silencedetect`
///    `silence_end` timestamps (exact pts where dialogue resumes after pause)
///    and finds the global offset in `[-30s, +30s]` maximizing alignment with
///    post-pause spoken [SubtitleCue] onsets via Gaussian KDE + RANSAC median.
/// 2. **1-Tap Snap to Voice Now**: Matches the current playback moment when
///    speech starts to the closest dialogue cue in the active window.
/// 3. **Intro Skip & Frame-Rate Presets**: Estimates shift from intro cut
///    differences or 23.976 ↔ 25.0 fps drift at the current timestamp.
class SubtitleAutoSyncEngine {
  const SubtitleAutoSyncEngine._();

  static final RegExp _silenceEndRe = RegExp(
    r'silence_end:\s*([-+]?\d+(?:\.\d+)?)',
  );

  static final RegExp _sdhBracketOnlyRe = RegExp(
    r'^\s*(?:\[[^\]]*\]|\([^)]*\)|[♪♫#\s\-\.!?,:;]+)\s*$',
  );

  /// Extracts a media timestamp in seconds from an mpv `silencedetect` log line,
  /// returning `null` if [logLine] does not contain a `silence_end:` event.
  static double? parseSilenceEndSeconds(String logLine) {
    final m = _silenceEndRe.firstMatch(logLine);
    if (m == null) return null;
    final parsed = double.tryParse(m.group(1)!);
    if (parsed == null || !parsed.isFinite || parsed < 0) return null;
    return parsed;
  }

  /// Filters cues to likely spoken lines (omitting pure sound-effect / music tags
  /// like `[music playing]` or `♪`) and annotates whether each cue follows a
  /// natural pause gap >= [minPauseSeconds].
  static List<({double startSec, double endSec, bool afterPause})>
      extractSpokenOnsets(
    List<SubtitleCue> cues, {
    double minPauseSeconds = 0.28,
  }) {
    final sorted = List<SubtitleCue>.from(cues)
      ..sort((a, b) => a.start.compareTo(b.start));
    final out = <({double startSec, double endSec, bool afterPause})>[];
    double prevEnd = -999.0;
    for (final cue in sorted) {
      final startSec = cue.start.inMicroseconds / 1000000.0;
      final endSec = cue.end.inMicroseconds / 1000000.0;
      final text = cue.text.trim();
      if (text.isEmpty || _sdhBracketOnlyRe.hasMatch(text)) {
        prevEnd = math.max(prevEnd, endSec);
        continue;
      }
      final gap = startSec - prevEnd;
      out.add((
        startSec: startSec,
        endSec: endSec,
        afterPause: gap >= minPauseSeconds,
      ));
      prevEnd = math.max(prevEnd, endSec);
    }
    return out;
  }

  /// Estimates the best global subtitle delay (`speechTime - cueStart`) from a
  /// list of observed acoustic speech onset timestamps (`silence_end` values in
  /// seconds) and the subtitle track's [cues].
  ///
  /// Returns `null` if fewer than [minOnsetsRequired] spoken pairs match cleanly.
  static SubtitleSyncEstimate? estimateAcousticOffset({
    required List<double> speechOnsetsSec,
    required List<SubtitleCue> cues,
    double maxAbsOffsetSec = 30.0,
    double toleranceSec = 0.55,
    int minOnsetsRequired = 2,
  }) {
    if (speechOnsetsSec.isEmpty || cues.isEmpty) return null;

    final spoken = extractSpokenOnsets(cues);
    if (spoken.isEmpty) return null;

    final minSpeech = speechOnsetsSec.reduce(math.min);
    final maxSpeech = speechOnsetsSec.reduce(math.max);

    // Restrict search window to cues reachable within maxAbsOffsetSec + margin.
    final windowCues = spoken
        .where(
          (c) =>
              c.startSec >= minSpeech - maxAbsOffsetSec - 2.0 &&
              c.startSec <= maxSpeech + maxAbsOffsetSec + 2.0,
        )
        .toList(growable: false);
    if (windowCues.isEmpty) return null;

    final candidates = <double>[];
    for (final s in speechOnsetsSec) {
      for (final c in windowCues) {
        final delta = s - c.startSec;
        if (delta.abs() <= maxAbsOffsetSec) {
          candidates.add(delta);
        }
      }
    }
    if (candidates.isEmpty) return null;

    // Score each distinct candidate cluster via soft Gaussian kernel weighting
    // across observed speech onsets (each speech onset can cast at most 1 full
    // match contribution for its best cue so dense subtitle bursts don't bias).
    double bestScore = -1.0;
    double runnerUpScore = 0.0;
    double bestAnchor = 0.0;

    // Deduplicate nearby candidate anchors every 0.05s.
    final testedBuckets = <int>{};
    for (final rawDelta in candidates) {
      final bucket = (rawDelta * 20).round();
      if (!testedBuckets.add(bucket)) continue;
      final score = _scoreOffset(
        delta: rawDelta,
        speechOnsetsSec: speechOnsetsSec,
        cues: windowCues,
        toleranceSec: toleranceSec,
      );
      if (score > bestScore) {
        if ((rawDelta - bestAnchor).abs() > toleranceSec * 1.6) {
          runnerUpScore = math.max(runnerUpScore, bestScore);
        }
        bestScore = score;
        bestAnchor = rawDelta;
      } else if ((rawDelta - bestAnchor).abs() > toleranceSec * 1.6 &&
          score > runnerUpScore) {
        runnerUpScore = score;
      }
    }

    if (bestScore <= 0) return null;

    // Collect inlier residuals around bestAnchor & take weighted median.
    final inlierDeltas = <double>[];
    for (final s in speechOnsetsSec) {
      double? bestLocalDelta;
      double bestErr = toleranceSec;
      for (final c in windowCues) {
        final err = ((s - c.startSec) - bestAnchor).abs();
        if (err <= bestErr) {
          bestErr = err;
          bestLocalDelta = s - c.startSec;
        }
      }
      if (bestLocalDelta != null) {
        inlierDeltas.add(bestLocalDelta);
      }
    }

    if (inlierDeltas.length < minOnsetsRequired) return null;

    inlierDeltas.sort();
    final medianOffset = inlierDeltas[inlierDeltas.length ~/ 2];
    final snappedOffset = (medianOffset * 20).roundToDouble() / 20.0;

    final coverage =
        (inlierDeltas.length / speechOnsetsSec.length).clamp(0.0, 1.0);
    final separation = bestScore > 0
        ? ((bestScore - runnerUpScore) / bestScore).clamp(0.0, 1.0)
        : 0.0;
    final countBonus = math.min(1.0, inlierDeltas.length / 5.0);
    final confidence =
        (0.45 * coverage + 0.30 * separation + 0.25 * countBonus).clamp(0.0, 1.0);

    return SubtitleSyncEstimate(
      offsetSeconds: snappedOffset,
      confidence: confidence,
      matchedPairs: inlierDeltas.length,
      reason: 'acoustic',
    );
  }

  static double _scoreOffset({
    required double delta,
    required List<double> speechOnsetsSec,
    required List<({double startSec, double endSec, bool afterPause})> cues,
    required double toleranceSec,
  }) {
    final sigma = toleranceSec * 0.45;
    final twoSigmaSq = 2.0 * sigma * sigma;
    var total = 0.0;
    for (final s in speechOnsetsSec) {
      var bestPair = 0.0;
      for (final c in cues) {
        final err = (s - (c.startSec + delta)).abs();
        if (err > toleranceSec * 1.4) continue;
        final kernel = math.exp(-(err * err) / twoSigmaSq);
        final pauseBoost = c.afterPause ? 1.25 : 0.85;
        final weighted = kernel * pauseBoost;
        if (weighted > bestPair) bestPair = weighted;
      }
      total += bestPair;
    }
    return total;
  }

  /// Instant 1-tap voice alignment when the user taps *Sync to Voice Now* right
  /// as speech begins at [playbackPosition].
  ///
  /// Looks around the currently delayed position (`playbackPosition - currentDelaySec`)
  /// for the nearest dialogue cue within `[-maxShiftSec, +maxShiftSec]`,
  /// favoring cues immediately following a pause or closest to current time.
  static SubtitleSyncEstimate? snapToVoiceNow({
    required Duration playbackPosition,
    required double currentDelaySec,
    required List<SubtitleCue> cues,
    double maxShiftSec = 25.0,
  }) {
    final spoken = extractSpokenOnsets(cues);
    if (spoken.isEmpty) return null;

    final nowSec = playbackPosition.inMicroseconds / 1000000.0;
    final currentCuePos = nowSec - currentDelaySec;

    ({double startSec, double endSec, bool afterPause})? bestCue;
    var bestCost = double.infinity;

    for (final c in spoken) {
      final impliedDelay = nowSec - c.startSec;
      final shiftFromCurrent = (impliedDelay - currentDelaySec).abs();
      if (shiftFromCurrent > maxShiftSec) continue;

      // Prefer cues whose distance to the unshifted position is small and that
      // start after a pause, nudging away from cues that already ended long ago.
      final dist = (c.startSec - currentCuePos).abs();
      final pauseDiscount = c.afterPause ? 0.78 : 1.0;
      final cost = dist * pauseDiscount;
      if (cost < bestCost) {
        bestCost = cost;
        bestCue = c;
      }
    }

    if (bestCue == null) return null;

    final newDelay = ((nowSec - bestCue.startSec) * 20).roundToDouble() / 20.0;
    return SubtitleSyncEstimate(
      offsetSeconds: newDelay,
      confidence: 0.9,
      matchedPairs: 1,
      reason: 'snap',
    );
  }

  /// Suggests a quick subtitle offset adjustment from [SkipSegment] intro data
  /// when cues look displaced relative to an intro recap/cold open.
  static SubtitleSyncEstimate? suggestIntroAlignment({
    required List<SkipSegment> segments,
    required List<SubtitleCue> cues,
  }) {
    if (segments.isEmpty || cues.isEmpty) return null;
    SkipSegment? intro;
    for (final seg in segments) {
      if (seg.type == SkipType.intro) {
        intro = seg;
        break;
      }
    }
    if (intro == null) return null;

    final spoken = extractSpokenOnsets(cues);
    if (spoken.isEmpty) return null;

    final introLen = intro.endTime - intro.startTime;
    if (introLen < 12.0 || introLen > 180.0) return null;

    final firstCueSec = spoken.first.startSec;
    final introStartSec = intro.startTime;
    final introEndSec = intro.endTime;

    // If intro starts around t=0..30s and the first subtitle cue only starts
    // right near introEnd while an intro exists, subtitles already exclude it;
    // conversely if a cluster of dialogue lines sits squarely inside an instrumental
    // intro window right after a big gap, shifting by introLen is a helpful preset.
    final cuesDuringIntro = spoken
        .where((c) => c.startSec > introStartSec + 4 && c.startSec < introEndSec - 4)
        .length;
    if (firstCueSec < 5.0 && cuesDuringIntro >= 4) {
      return SubtitleSyncEstimate(
        offsetSeconds: (introLen * 2).roundToDouble() / 2.0,
        confidence: 0.65,
        matchedPairs: cuesDuringIntro,
        reason: 'intro',
      );
    }
    return null;
  }

  /// Computes a frame-rate drift correction delta (in seconds) at [position]
  /// when switching between 23.976 fps (NTSC Film) and 25.0 fps (PAL).
  static double driftDeltaForFps({
    required Duration position,
    required double cueFps,
    required double videoFps,
  }) {
    if (cueFps <= 0 || videoFps <= 0) return 0.0;
    final sec = position.inMicroseconds / 1000000.0;
    // Positive result = add to current delay.
    final delta = sec * (cueFps / videoFps - 1.0);
    return (delta * 10).roundToDouble() / 10.0;
  }
}
