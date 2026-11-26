/// Cross-engine failover: handing a playback one engine cannot play to the
/// other one.
///
/// The app ships two playback engines - media_kit (libmpv) and libVLC - and a
/// stream that defeats one is routinely playable by the other: different
/// demuxers, different HLS implementations, different TLS and codec stacks.
/// Until now a source list exhausted on one engine was a dead end even though
/// the other had never been asked.
///
/// The hand-off travels on a [ValueNotifier] rather than as a route argument,
/// because the engine screens are pushed by callers all over the app; the one
/// place that knows how to swap them is the unified player, which listens
/// here and rebuilds on the other engine with the viewer's position carried
/// over.
library;

import 'package:flutter/foundation.dart';

/// The playback engines the app can open a stream with.
enum PlaybackEngine {
  /// media_kit (libmpv): hardware decoding, zero-copy rendering on desktop.
  mediaKit,

  /// libVLC: the widest codec and demuxer coverage, the conservative pick.
  vlc,
}

extension PlaybackEngineLabel on PlaybackEngine {
  /// What the UI calls it.
  String get label => switch (this) {
        PlaybackEngine.mediaKit => 'MediaKit (libmpv)',
        PlaybackEngine.vlc => 'VLC',
      };

  /// The engine to hand a hopeless stream to.
  PlaybackEngine get other => this == PlaybackEngine.mediaKit
      ? PlaybackEngine.vlc
      : PlaybackEngine.mediaKit;
}

/// A request to move the current playback to another engine.
@immutable
class EngineSwitchRequest {
  const EngineSwitchRequest({
    required this.target,
    required this.resumeAt,
    this.fromFailover = false,
  });

  /// The engine the playback should continue on.
  final PlaybackEngine target;

  /// Where the new engine should start: the position the old one had reached.
  /// Losing the viewer's place is the one thing a hand-off must never do.
  final Duration resumeAt;

  /// Whether the request came from an engine that had exhausted every source.
  /// A hand-off engine never hands back on its own - the two engines would
  /// take turns failing forever - so this is what stops the loop.
  final bool fromFailover;
}

/// The one hand-off in flight, watched by the unified player.
final ValueNotifier<EngineSwitchRequest?> engineSwitchNotifier =
    ValueNotifier<EngineSwitchRequest?>(null);

/// Asks for the playback to move to [target], resuming at [resumeAt].
void requestEngineSwitch(
  PlaybackEngine target, {
  required Duration resumeAt,
  bool fromFailover = false,
}) {
  engineSwitchNotifier.value = EngineSwitchRequest(
    target: target,
    resumeAt: resumeAt,
    fromFailover: fromFailover,
  );
}

/// Drops any hand-off request, so a later playback starts clean.
void clearEngineSwitchRequest() {
  engineSwitchNotifier.value = null;
}

/// Whether the platform has both engines at all.
///
/// The unified player dispatches to libVLC on Windows and Android only;
/// elsewhere there is nothing to fail over to.
bool engineFailoverPlatformSupported(TargetPlatform platform) =>
    platform == TargetPlatform.windows || platform == TargetPlatform.android;

/// Whether an engine that has run out of sources should hand the playback to
/// the other engine rather than raise the failed frame.
///
/// [alreadyHandedOff] - this screen was itself opened by a hand-off, so the
/// other engine has already had its turn. One automatic hop per playback;
/// beyond that the viewer chooses, from the failed frame's own button.
bool shouldHandOffToOtherEngine({
  required bool settingEnabled,
  required bool alreadyHandedOff,
  required bool platformSupported,
}) =>
    settingEnabled && !alreadyHandedOff && platformSupported;
