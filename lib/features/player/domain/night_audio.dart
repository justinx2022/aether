/// Multi-stage Night Audio filter composer for libmpv / FFmpeg lavfi.
///
/// Builds progressively simpler fallback chains so quiet dialogue is lifted and
/// loud explosions/SFX are tamed across both full desktop FFmpeg builds and
/// stripped Android libmpv builds, while cleanly coexisting with acoustic
/// `silencedetect` when automatic subtitle sync is listening.
class NightAudioComposer {
  const NightAudioComposer._();

  /// Full 5-stage vocal clarity & dynamic range compression graph:
  /// 1. `highpass=f=105` trims low rumble / explosion sub-bass below voice.
  /// 2. `acompressor` brings quiet speech forward (+5dB makeup) while clamping SFX.
  /// 3. `equalizer` lifts core speech intelligibility around 2.4kHz (+3.5dB).
  /// 4. `dynaudnorm` smooths macro scene-to-scene loudness.
  /// 5. `alimiter` prevents digital clipping on peaks.
  static const List<String> _fullNightStages = <String>[
    'highpass=f=105',
    'acompressor=threshold=-24dB:ratio=4.5:attack=12:release=180:makeup=5dB',
    'equalizer=f=2400:t=q:w=1.2:g=3.5',
    'dynaudnorm=f=150:g=15:p=0.88:m=12',
    'alimiter=limit=0.89:attack=4:release=40',
  ];

  /// 4-stage fallback omitting `equalizer`.
  static const List<String> _standardNightStages = <String>[
    'highpass=f=105',
    'acompressor=threshold=-24dB:ratio=4.5:attack=12:release=180:makeup=5dB',
    'dynaudnorm=f=150:g=15:p=0.88:m=12',
    'alimiter=limit=0.89:attack=4:release=40',
  ];

  /// 2-stage fallback using only compressor + dynamic normalizer.
  static const List<String> _minimalNightStages = <String>[
    'acompressor=threshold=-22dB:ratio=4:attack=15:release=200:makeup=4dB',
    'dynaudnorm=f=150:g=15:p=0.88:m=12',
  ];

  /// Minimal native-or-lavfi leveler if compressor filter is unavailable.
  static const List<String> _dynaudnormOnlyStages = <String>[
    'dynaudnorm=f=150:g=15:p=0.90:m=12',
  ];

  /// Speech-pause acoustic detector appended non-destructively when
  /// Auto-Sync Subtitles is actively listening to audio output.
  static const String silenceDetectStage =
      'silencedetect=noise=-34dB:d=0.32';

  /// Returns ordered libmpv `af` property strings from richest to safest.
  ///
  /// When both [nightAudioEnabled] and [silenceDetectEnabled] are `false`,
  /// returns `['']` so the caller resets `af` back to pass-through.
  static List<String> buildFilterCandidates({
    required bool nightAudioEnabled,
    bool silenceDetectEnabled = false,
  }) {
    if (!nightAudioEnabled && !silenceDetectEnabled) {
      return const <String>[''];
    }
    if (!nightAudioEnabled && silenceDetectEnabled) {
      return const <String>[
        'lavfi=[$silenceDetectStage]',
      ];
    }

    final tiers = <List<String>>[
      _fullNightStages,
      _standardNightStages,
      _minimalNightStages,
      _dynaudnormOnlyStages,
    ];

    final out = <String>[];
    for (final tier in tiers) {
      final combined = silenceDetectEnabled
          ? <String>[...tier, silenceDetectStage]
          : tier;
      out.add('lavfi=[${combined.join(',')}]');
    }
    if (!silenceDetectEnabled) {
      out.add('dynaudnorm=f=150:g=15:p=0.90:m=12');
    }
    return out;
  }

  /// Convenience helper picking candidate tier at [preferredTierIndex]
  /// (falling back cleanly to tier 0 / last tier if out of bounds).
  static String candidateForTier({
    required bool nightAudioEnabled,
    bool silenceDetectEnabled = false,
    int preferredTierIndex = 0,
  }) {
    final candidates = buildFilterCandidates(
      nightAudioEnabled: nightAudioEnabled,
      silenceDetectEnabled: silenceDetectEnabled,
    );
    if (candidates.isEmpty) return '';
    final idx = preferredTierIndex.clamp(0, candidates.length - 1);
    return candidates[idx];
  }
}
