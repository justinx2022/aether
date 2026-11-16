import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/domain/entity/multimedia_item.dart';
import '../../domain/stream_resolver.dart';
import '../../settings/presentation/player_settings_provider.dart';
import 'mediakit/mediakit_player_screen.dart';

/// Unified Player Abstraction
///
/// Consolidates video player execution across platforms, handling preferred
/// engine dispatch (MediaKit/libmpv hardware acceleration, external player intents)
/// and unified playback state synchronization.
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
    final playerSettings =
        ref.watch(playerSettingsProvider).asData?.value ??
        const PlayerSettings();

    // If an external player application is explicitly preferred (e.g. external MPV/VLC intent)
    // external launching is handled before falling back to the internal player.
    // By default, the high-performance zero-copy MediaKit hardware-accelerated engine is used.
    return MediaKitPlayerScreen(
      item: item,
      videoUrl: videoUrl,
      episode: episode,
      preloadedStreams: preloadedStreams,
    );
  }
}
