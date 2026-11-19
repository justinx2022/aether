import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/domain/entity/multimedia_item.dart';
import '../../settings/presentation/player_settings_provider.dart';
import 'mediakit/mediakit_player_screen.dart';
import 'vlc/vlc_player_screen.dart';

/// Unified Player Abstraction
///
/// Consolidates video player execution across platforms, handling preferred
/// engine dispatch (MediaKit/libmpv hardware acceleration, VLC engine fallback,
/// external player intents) and unified playback state synchronization.
class UnifiedPlayerScreen extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
    final playerSettings = ref.watch(playerSettingsProvider).asData?.value;
    final useMediaKit = playerSettings?.useMediaKitOnWindows ?? true;

    // Dispatch to VLC engine if the user toggled off MediaKit on supported platforms
    if (!useMediaKit && (Platform.isWindows || Platform.isAndroid)) {
      return VlcPlayerScreen(
        item: item,
        videoUrl: videoUrl,
        episode: episode,
        preloadedStreams: preloadedStreams,
      );
    }

    // MediaKit hardware-accelerated engine with zero-copy Direct3D/VAAPI rendering
    return MediaKitPlayerScreen(
      item: item,
      videoUrl: videoUrl,
      episode: episode,
      preloadedStreams: preloadedStreams,
    );
  }
}
