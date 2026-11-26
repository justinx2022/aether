import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/domain/entity/multimedia_item.dart';
import '../../settings/presentation/player_settings_provider.dart';
import '../domain/engine_failover.dart';
import 'mediakit/mediakit_player_screen.dart';
import 'vlc/vlc_player_screen.dart';

/// Unified Player Abstraction
///
/// Consolidates video player execution across platforms, handling preferred
/// engine dispatch (MediaKit/libmpv hardware acceleration, VLC engine fallback,
/// external player intents) and unified playback state synchronization.
///
/// Also the one place that can swap engines mid-playback: when an engine
/// exhausts every source, it posts a request on [engineSwitchNotifier] and
/// this screen rebuilds on the other engine, resuming at the position the
/// failing one had reached.
class UnifiedPlayerScreen extends ConsumerStatefulWidget {
  final MultimediaItem item;
  final String videoUrl;
  final Episode? episode;
  final List<StreamResult>? preloadedStreams;

  const UnifiedPlayerScreen({
    super.key,
    required this.item,
    required this.videoUrl,
    this.episode,
    this.preloadedStreams,
  });

  @override
  ConsumerState<UnifiedPlayerScreen> createState() =>
      _UnifiedPlayerScreenState();
}

class _UnifiedPlayerScreenState extends ConsumerState<UnifiedPlayerScreen> {
  /// The hand-off in flight, if an engine has asked to be relieved.
  EngineSwitchRequest? _handoff;

  @override
  void initState() {
    super.initState();
    // A request left over from a previous playback must not fire into this one.
    clearEngineSwitchRequest();
    engineSwitchNotifier.addListener(_onEngineSwitchRequest);
  }

  void _onEngineSwitchRequest() {
    final request = engineSwitchNotifier.value;
    if (request == null || !mounted) return;
    clearEngineSwitchRequest();
    setState(() => _handoff = request);
  }

  @override
  void dispose() {
    engineSwitchNotifier.removeListener(_onEngineSwitchRequest);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final playerSettings = ref.watch(playerSettingsProvider).asData?.value;
    final useMediaKit = playerSettings?.useMediaKitOnWindows ?? true;
    final handoff = _handoff;
    final targetEngine =
        handoff?.target ?? (useMediaKit ? PlaybackEngine.mediaKit : PlaybackEngine.vlc);
    final vlcOnThisPlatform = Platform.isWindows || Platform.isAndroid;

    // Dispatch to VLC engine if the user toggled off MediaKit on supported
    // platforms, or a hand-off asked for it.
    if (targetEngine == PlaybackEngine.vlc && vlcOnThisPlatform) {
      return VlcPlayerScreen(
        item: widget.item,
        videoUrl: widget.videoUrl,
        episode: widget.episode,
        preloadedStreams: widget.preloadedStreams,
        resumeAt: handoff?.resumeAt,
        isEngineHandoff: handoff != null,
      );
    }

    // MediaKit hardware-accelerated engine with zero-copy Direct3D/VAAPI rendering
    return MediaKitPlayerScreen(
      item: widget.item,
      videoUrl: widget.videoUrl,
      episode: widget.episode,
      preloadedStreams: widget.preloadedStreams,
      resumeAt: handoff?.resumeAt,
      isEngineHandoff: handoff != null,
    );
  }
}
