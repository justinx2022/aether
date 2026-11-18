import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:aether/core/domain/entity/multimedia_item.dart';
import 'package:aether/core/extensions/extension_manager.dart';
import 'package:aether/core/router/app_router.dart';
import 'package:aether/core/services/notification_service.dart';
import 'package:aether/core/theme/app_world.dart';
import 'package:aether/core/utils/image_fallbacks.dart';
import 'package:aether/core/utils/image_utils.dart';
import 'package:aether/core/utils/layout_constants.dart';
import 'package:aether/features/details/presentation/details_controller.dart';
import 'package:aether/features/details/presentation/playback_launcher.dart';
import 'package:aether/features/library/presentation/history_provider.dart';
import 'package:aether/features/settings/presentation/player_settings_provider.dart';
import 'package:aether/l10n/generated/app_localizations.dart';
import 'package:aether/shared/focus/app_focus.dart';
import 'package:aether/shared/widgets/cards_wrapper.dart';
import 'package:aether/shared/widgets/cinema_badge.dart';
import 'package:aether/shared/widgets/loading_dialog.dart';

/// Apple TV-inspired Continue Watching card.
///
/// Features:
/// - 16:9 cinematic aspect ratio with squircle curvature.
/// - Multi-stop cinematic dark vignette.
/// - Floating frosted-glass central Play action pill with smooth scale/glow on hover/focus.
/// - Elegant metadata hierarchy (series tag, episode title, remaining duration pill).
/// - Apple-style glowing progress gauge with rounded endcaps.
/// - Seamless zero-lag click-to-play with details fallback.
class ContinueWatchingCard extends ConsumerStatefulWidget {
  final HistoryItem historyItem;
  final double width;
  final bool isLarge;

  const ContinueWatchingCard({
    super.key,
    required this.historyItem,
    this.width = 280,
    this.isLarge = false,
  });

  @override
  ConsumerState<ContinueWatchingCard> createState() =>
      _ContinueWatchingCardState();
}

class _ContinueWatchingCardState extends ConsumerState<ContinueWatchingCard> {
  bool _isHovered = false;
  bool _isFocused = false;

  bool get _isAttended => _isHovered || showFocusIndicator(context, _isFocused);

  static String _normalizeMatchKey(String value) {
    return value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
  }

  static MultimediaItem? _pickBestLiveMatch(
    Iterable<MultimediaItem> candidates,
    MultimediaItem target,
  ) {
    final normalizedTarget = _normalizeMatchKey(target.title);
    if (normalizedTarget.isEmpty) return null;

    final exactTitleMatches = candidates.where(
      (candidate) =>
          candidate.contentType == MultimediaContentType.livestream &&
          _normalizeMatchKey(candidate.title) == normalizedTarget,
    );

    if (target.posterUrl.isNotEmpty) {
      final posterMatch = exactTitleMatches.firstWhereOrNull(
        (candidate) => candidate.posterUrl == target.posterUrl,
      );
      if (posterMatch != null) return posterMatch;
    }

    return exactTitleMatches.firstOrNull;
  }

  Future<MultimediaItem?> _resolveFreshLiveItem(
    WidgetRef ref,
    MultimediaItem item,
  ) async {
    final providerId = item.provider;
    if (providerId == null || providerId.isEmpty) return null;

    final manager = ref.read(extensionManagerProvider.notifier);
    final provider = manager.getAllProviders().firstWhereOrNull(
      (p) => p.packageName == providerId || p.name == providerId,
    );
    if (provider == null) return null;

    try {
      final results = await provider.search(item.title);
      final match = _pickBestLiveMatch(results, item);
      if (match != null) {
        return match.copyWith(provider: provider.packageName);
      }
    } catch (_) {}

    try {
      final homeSections = await provider.getHome();
      final flattened = homeSections.values.expand((items) => items);
      final match = _pickBestLiveMatch(flattened, item);
      if (match != null) {
        return match.copyWith(provider: provider.packageName);
      }
    } catch (_) {}

    return null;
  }

  String _formatDuration(int milliseconds) {
    if (milliseconds <= 0) return '00:00';
    final d = Duration(milliseconds: milliseconds);
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    if (h > 0) {
      if (m > 0) return '${h}h ${m}m';
      return '${h}h';
    }
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  String _formatRemaining(int posMs, int durMs) {
    final diff = durMs - posMs;
    if (diff <= 0) return '';
    final d = Duration(milliseconds: diff);
    if (d.inHours > 0) {
      final m = d.inMinutes.remainder(60);
      return m > 0 ? '${d.inHours}h ${m}m left' : '${d.inHours}h left';
    }
    final mins = d.inMinutes;
    return mins > 0 ? '${mins}m left' : '${d.inSeconds}s left';
  }

  void _showContextMenu(BuildContext context, MultimediaItem item) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        margin: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF161618),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.6),
              blurRadius: 30,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Text(
                item.title,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const Divider(color: Colors.white12, height: 20),
            ListTile(
              leading: const Icon(Icons.info_outline_rounded, color: Colors.white70),
              title: Text(l10n.viewDetails, style: const TextStyle(color: Colors.white)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              onTap: () {
                Navigator.pop(context);
                unawaited(
                  DetailsRoute($extra: DetailsRouteExtra(item: item))
                      .push<void>(context),
                );
              },
            ),
            ListTile(
              leading: Icon(Icons.delete_outline_rounded, color: theme.colorScheme.error),
              title: Text(
                l10n.removeFromHistory,
                style: TextStyle(color: theme.colorScheme.error),
              ),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              onTap: () {
                ref
                    .read(watchHistoryProvider.notifier)
                    .removeFromHistory(item.url);
                Navigator.pop(context);
                ref
                    .read(notificationServiceProvider)
                    .showSuccess(
                      l10n.removedFromHistory(item.title),
                      title: 'Watch History',
                      icon: Icons.history_rounded,
                    );
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final item = widget.historyItem.item;
    final double progress = (widget.historyItem.duration > 0)
        ? (widget.historyItem.position / widget.historyItem.duration).clamp(
            0.0,
            1.0,
          )
        : 0.0;

    final isLivestream = item.contentType == MultimediaContentType.livestream;
    final isSeries = item.contentType == MultimediaContentType.series;
    final isAnime = item.contentType == MultimediaContentType.anime;
    final hasEpisodes = isSeries || isAnime;

    final imageUrl = hasEpisodes
        ? (widget.historyItem.episodePosterUrl ?? item.backdropImageUrl)
        : item.backdropImageUrl;
    final bannerUrl = AppImageFallbacks.poster(imageUrl, label: item.title);

    final episodeLabel =
        hasEpisodes &&
            widget.historyItem.season != null &&
            widget.historyItem.episode != null &&
            (widget.historyItem.season! > 0 || widget.historyItem.episode! > 0)
        ? 'S${widget.historyItem.season} · E${widget.historyItem.episode}'
        : null;

    final episodeTitle = widget.historyItem.episodeTitle?.trim();
    final hasCustomTitle = episodeTitle != null &&
        episodeTitle.isNotEmpty &&
        !episodeTitle.toLowerCase().startsWith('episode');

    final remainingText = !isLivestream && widget.historyItem.duration > 0
        ? _formatRemaining(widget.historyItem.position, widget.historyItem.duration)
        : null;

    return CardsWrapper(
      onTap: () async {
        if (isLivestream) {
          bool dialogDismissed = false;
          bool canceled = false;
          unawaited(
            LoadingDialog.show(
              context,
              message: AppLocalizations.of(context)!.refreshingLiveStream,
              onCancel: () {
                canceled = true;
                dialogDismissed = true;
              },
            ),
          );
          final refreshedItem = await _resolveFreshLiveItem(ref, item);
          if (!context.mounted || canceled) return;

          if (!dialogDismissed) {
            Navigator.of(context, rootNavigator: true).pop();
            dialogDismissed = true;
          }

          final liveItem = refreshedItem ?? item;
          if (!context.mounted || canceled) return;

          unawaited(
            ref
                .read(playbackLauncherProvider)
                .playResolved(context, item: liveItem, videoUrl: liveItem.url),
          );
          unawaited(
            ref.read(watchHistoryProvider.notifier).removeFromHistory(item.url),
          );
          return;
        }

        final playerSettings = ref.read(playerSettingsProvider).asData?.value;
        final seamless = playerSettings?.seamlessPlayback ?? true;

        if (seamless) {
          final historyItem = widget.historyItem;
          var itemToLaunch = item;
          if ((itemToLaunch.episodes == null || itemToLaunch.episodes!.isEmpty) &&
              item.url.isNotEmpty) {
            final cached = ref
                .read(detailsControllerProvider(item.url))
                .details
                .asData
                ?.value;
            if (cached != null &&
                cached.episodes != null &&
                cached.episodes!.isNotEmpty) {
              itemToLaunch = itemToLaunch.copyWith(episodes: cached.episodes);
            }
          }

          final episode = (historyItem.lastEpisodeUrl != null)
              ? Episode(
                  name: historyItem.episodeTitle ??
                      (historyItem.episode != null
                          ? 'Episode ${historyItem.episode}'
                          : item.title),
                  url: historyItem.lastEpisodeUrl!,
                  season: historyItem.season ?? 0,
                  episode: historyItem.episode ?? 0,
                  posterUrl: historyItem.episodePosterUrl,
                )
              : null;

          final videoUrl = historyItem.lastEpisodeUrl ?? item.url;
          final cachedStream = historyItem.lastStreamUrl;
          final preloaded = (cachedStream != null && cachedStream.isNotEmpty)
              ? [
                  StreamResult(
                    url: cachedStream,
                    source: item.provider ?? 'Auto',
                    providerName: item.provider ?? 'Auto',
                    headers: const {},
                  ),
                ]
              : null;

          unawaited(
            ref
                .read(playbackLauncherProvider)
                .playResolved(
                  context,
                  item: itemToLaunch,
                  videoUrl: videoUrl,
                  episode: episode,
                  streams: preloaded ?? const <StreamResult>[],
                ),
          );
          return;
        }

        unawaited(
          DetailsRoute($extra: DetailsRouteExtra(item: item, autoPlay: true))
              .push<void>(context),
        );
      },
      onLongPress: () => _showContextMenu(context, item),
      borderRadius: BorderRadius.circular(LayoutConstants.radiusLg),
      onFocusChange: (hasFocus) {
        if (_isFocused == hasFocus) return;
        setState(() => _isFocused = hasFocus);
      },
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: SizedBox(
          width: widget.width,
          child: AnimatedScale(
            scale: _isAttended ? 1.03 : 1.0,
            duration: const Duration(milliseconds: 240),
            curve: Curves.easeOutCubic,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 240),
              curve: Curves.easeOutCubic,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(LayoutConstants.radiusLg),
                border: Border.all(
                  color: _isAttended
                      ? Colors.white.withOpacity(0.35)
                      : Colors.white.withOpacity(0.08),
                  width: _isAttended ? 1.5 : 1.0,
                ),
                boxShadow: _isAttended
                    ? [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.55),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                        BoxShadow(
                          color: theme.colorScheme.primary.withOpacity(0.25),
                          blurRadius: 16,
                          spreadRadius: 1,
                        ),
                      ]
                    : [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.35),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(LayoutConstants.radiusLg),
                child: Stack(
                  children: [
                    // Backdrop Artwork
                    Positioned.fill(
                      child: Container(
                        color: const Color(0xFF141416),
                        child: bannerUrl != null
                            ? CachedNetworkImage(
                                imageUrl: bannerUrl,
                                fit: BoxFit.cover,
                                memCacheWidth: ImageUtils.coverDecodeWidth(
                                  context,
                                  width: widget.width,
                                  sourceAspectRatio: 16 / 9,
                                ),
                                placeholder: (_, _) => const SizedBox.shrink(),
                                errorWidget: (_, _, _) =>
                                    const SizedBox.shrink(),
                              )
                            : null,
                      ),
                    ),

                    // Multi-stop Cinematic Gradient Scrim
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            stops: const [0.0, 0.45, 0.75, 1.0],
                            colors: [
                              Colors.black.withOpacity(0.35),
                              Colors.transparent,
                              Colors.black.withOpacity(0.65),
                              Colors.black.withOpacity(0.92),
                            ],
                          ),
                        ),
                      ),
                    ),

                    // Top Indicators (Live / Cinema Badge & Remaining Time)
                    Positioned(
                      top: 10,
                      left: 10,
                      right: 10,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          if (isLivestream)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.red.withOpacity(0.85),
                                borderRadius: BorderRadius.circular(100),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.red.withOpacity(0.5),
                                    blurRadius: 8,
                                  ),
                                ],
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  CircleAvatar(
                                    radius: 3,
                                    backgroundColor: Colors.white,
                                  ),
                                  SizedBox(width: 4),
                                  Text(
                                    'LIVE',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0.6,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          else if (isSeries || isAnime)
                            CinemaBadge(label: isAnime ? 'ANIME' : 'SERIES')
                          else
                            const SizedBox.shrink(),

                          if (remainingText != null)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.55),
                                borderRadius: BorderRadius.circular(100),
                                border: Border.all(color: Colors.white12),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.access_time_rounded,
                                    size: 11,
                                    color: Colors.white70,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    remainingText,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),

                    // Centered Apple TV Floating Frosted Play Button
                    Positioned.fill(
                      child: Center(
                        child: AnimatedScale(
                          scale: _isAttended ? 1.05 : 0.88,
                          duration: const Duration(milliseconds: 220),
                          curve: Curves.easeOutCubic,
                          child: AnimatedOpacity(
                            opacity: _isAttended ? 1.0 : 0.0,
                            duration: const Duration(milliseconds: 200),
                            child: Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white.withOpacity(0.28),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.55),
                                  width: 1.5,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.4),
                                    blurRadius: 16,
                                    spreadRadius: 2,
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.play_arrow_rounded,
                                color: Colors.white,
                                size: 30,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),

                    // Bottom Metadata & Progress
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Show Header / Category Tag
                            if (hasEpisodes) ...[
                              Text(
                                item.title.toUpperCase(),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.7),
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.9,
                                ),
                              ),
                              const SizedBox(height: 2),
                            ],

                            // Episode Title / Main Title
                            Text(
                              hasEpisodes
                                  ? (episodeLabel != null
                                      ? '$episodeLabel${hasCustomTitle ? ' · "$episodeTitle"' : ''}'
                                      : (episodeTitle ?? item.title))
                                  : item.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13.5,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.2,
                              ),
                            ),
                            const SizedBox(height: 8),

                            // Apple TV Glowing Progress Gauge
                            if (!isLivestream)
                              ClipRRect(
                                borderRadius: BorderRadius.circular(100),
                                child: Container(
                                  height: 3.5,
                                  width: double.infinity,
                                  color: Colors.white.withOpacity(0.20),
                                  child: FractionallySizedBox(
                                    alignment: Alignment.centerLeft,
                                    widthFactor: progress,
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: theme.colorScheme.primary,
                                        borderRadius:
                                            BorderRadius.circular(100),
                                        boxShadow: [
                                          BoxShadow(
                                            color: theme.colorScheme.primary
                                                .withOpacity(0.8),
                                            blurRadius: 6,
                                            spreadRadius: 1,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
