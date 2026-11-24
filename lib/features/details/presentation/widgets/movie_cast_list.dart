import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../../../shared/widgets/thumbnail_error_placeholder.dart';
import '../../../../shared/widgets/cards_wrapper.dart';
import '../../../../shared/widgets/desktop_scroll_wrapper.dart';
import '../../../../shared/widgets/multimedia_card.dart';
import '../../../../core/utils/responsive_breakpoints.dart';
import '../../../../core/models/tmdb_details.dart';
import '../../../../core/theme/design_tokens.dart';
import '../../../../core/domain/entity/multimedia_item.dart';
import '../../../../core/router/app_router.dart';
import '../../../explore/data/explore_tmdb_provider.dart';

class MovieCastList extends ConsumerStatefulWidget {
  final List<TmdbCast> cast;
  final Color? textColor;
  final Color? textSecondary;

  final bool isLoading;

  const MovieCastList({
    super.key,
    required this.cast,
    this.isLoading = false,
    this.textColor,
    this.textSecondary,
  });

  @override
  ConsumerState<MovieCastList> createState() => _MovieCastListState();
}

class _MovieCastListState extends ConsumerState<MovieCastList> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  /// Opens a premium bottom sheet listing every movie/TV title the actor
  /// appears in (TMDB combined credits). Tapping a title navigates to it.
  Future<void> _openActorCredits(BuildContext context, TmdbCast actor) async {
    final personId = actor.id;
    if (personId == null) return;

    final credits =
        await ref.read(tmdbServiceProvider).getPersonCombinedCredits(personId);

    if (!mounted || !context.mounted) return;
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (credits.isEmpty) {
      messenger?.showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text('No other titles found for ${actor.name}'),
        ),
      );
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      builder: (sheetContext) => _ActorCreditsSheet(
        actorName: actor.name,
        credits: credits,
        textColor: widget.textColor,
        onTitleTap: (item) {
          Navigator.of(sheetContext).pop();
          final tmdbId = item.tmdbId;
          if (tmdbId == null) return;
          TmdbDetailsRoute(
            movieId: tmdbId,
            mediaType: item.tmdbMediaType,
          ).push<void>(context);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isLoading && widget.cast.isEmpty) {
      return const SizedBox.shrink();
    }

    final isDesktop = context.isDesktop;
    final displayCount = widget.isLoading ? 6 : widget.cast.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (isDesktop) ...[
          Text(
            "Cast",
            style: TextStyle(
              color: widget.textColor,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 140, // Height for Cast Cards
            child: DesktopScrollWrapper(
              controller: _scrollController,
              child: ListView.builder(
                clipBehavior: Clip.none,
                controller: _scrollController,
                scrollDirection: Axis.horizontal,
                itemCount: displayCount,
                // Fixed item width (80) + spacing (16) baked in via padding.
                itemExtent: 96,
                itemBuilder: (context, index) {
                  final child = widget.isLoading
                      ? _buildShimmerItem(context, isDesktop: true)
                      : _buildDesktopItem(context, index);
                  return RepaintBoundary(
                    child: Padding(
                      padding: const EdgeInsets.only(right: 16),
                      child: child,
                    ),
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 50),
        ] else ...[
          Text(
            "Cast",
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 160,
            child: ListView.builder(
              clipBehavior: Clip.none,
              scrollDirection: Axis.horizontal,
              itemCount: displayCount,
              // Item is width:90 + margin-right:16 inside _buildMobileItem.
              itemExtent: 106,
              itemBuilder: (context, index) => RepaintBoundary(
                child: widget.isLoading
                    ? _buildShimmerItem(context, isDesktop: false)
                    : _buildMobileItem(context, index),
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ],
    );
  }

  Widget _buildDesktopItem(BuildContext context, int index) {
    final actor = widget.cast[index];
    return CardsWrapper(
      onTap: () => _openActorCredits(context, actor),
      borderRadius: BorderRadius.circular(40),
      child: Column(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(40),
            child: CachedNetworkImage(
              imageUrl: actor.profileImageUrl ?? '',
              width: 80,
              height: 80,
              // No memCacheWidth — TMDB profile source is already w185 which
              // matches 80 dp × 3 DPR. Forcing smaller blurs on hi-DPR.
              fit: BoxFit.cover,
              errorWidget: (_, _, _) =>
                  ThumbnailErrorPlaceholder(label: actor.name, iconSize: 30),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: 80,
            child: Text(
              actor.name,
              style: TextStyle(color: widget.textColor, fontSize: 12),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ),
          SizedBox(
            width: 80,
            child: Text(
              actor.character,
              style: TextStyle(color: widget.textSecondary, fontSize: 10),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileItem(BuildContext context, int index) {
    final member = widget.cast[index];
    return CardsWrapper(
      onTap: () => _openActorCredits(context, member),
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Container(
        width: 90,
        margin: const EdgeInsets.only(right: 16),
        child: Column(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(35),
              child: CachedNetworkImage(
                imageUrl: member.profileImageUrl ?? '',
                width: 70,
                height: 70,
                // No memCacheWidth — see desktop branch above.
                fit: BoxFit.cover,
                errorWidget: (_, _, _) =>
                    ThumbnailErrorPlaceholder(label: member.name, iconSize: 30),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              member.name,
              maxLines: 2,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              member.character,
              maxLines: 1,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface
                    .withValues(alpha: 0.6),
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildShimmerItem(BuildContext context, {required bool isDesktop}) {
    return Container(
      width: isDesktop ? 80 : 90,
      margin: isDesktop ? EdgeInsets.zero : const EdgeInsets.only(right: 16),
      child: Column(
        children: [
          Container(
            width: isDesktop ? 80 : 70,
            height: isDesktop ? 80 : 70,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            width: 60,
            height: 12,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(AppRadius.xs),
            ),
          ),
          const SizedBox(height: 4),
          Container(
            width: 40,
            height: 10,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(AppRadius.xs),
            ),
          ),
        ],
      ),
    );
  }
}

/// Premium bottom sheet listing every title an actor appears in.
class _ActorCreditsSheet extends StatelessWidget {
  final String actorName;
  final List<MultimediaItem> credits;
  final Color? textColor;
  final ValueChanged<MultimediaItem> onTitleTap;

  const _ActorCreditsSheet({
    required this.actorName,
    required this.credits,
    required this.onTitleTap,
    this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    final onSurface = textColor ?? Theme.of(context).colorScheme.onSurface;
    final textSecondary =
        Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6);
    // Cap the sheet height so long filmographies stay scrollable.
    final maxHeight = MediaQuery.sizeOf(context).height * 0.75;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.55,
      minChildSize: 0.35,
      maxChildSize: 0.9,
      builder: (context, scrollController) => Container(
        constraints: BoxConstraints(maxHeight: maxHeight),
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: textSecondary.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
              ),
            ),
            Text(
              actorName,
              style: TextStyle(
                color: onSurface,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              '${credits.length} title${credits.length == 1 ? '' : 's'}',
              style: TextStyle(color: textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ListView.builder(
                controller: scrollController,
                itemCount: credits.length,
                itemBuilder: (context, index) {
                  final item = credits[index];
                  final dateText = MultimediaCard.formatReleaseDate(
                    item.releaseDate,
                  );
                  final isMovie = item.tmdbMediaType == 'movie';
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Material(
                      color: Theme.of(context)
                          .colorScheme
                          .surfaceContainerHighest
                          .withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        onTap: () => onTitleTap(item),
                        child: Padding(
                          padding: const EdgeInsets.all(10),
                          child: Row(
                            children: [
                              ClipRRect(
                                borderRadius:
                                    BorderRadius.circular(AppRadius.sm),
                                child: CachedNetworkImage(
                                  imageUrl: item.posterUrl,
                                  width: 48,
                                  height: 72,
                                  memCacheWidth: 144,
                                  fit: BoxFit.cover,
                                  errorWidget: (_, _, _) => Container(
                                    width: 48,
                                    height: 72,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .surfaceContainerHighest,
                                    child: Icon(
                                      isMovie
                                          ? Icons.movie_outlined
                                          : Icons.tv_outlined,
                                      size: 20,
                                      color: textSecondary,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item.title,
                                      style: TextStyle(
                                        color: onSurface,
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    if (dateText.isNotEmpty) ...[
                                      const SizedBox(height: 2),
                                      Text(
                                        dateText,
                                        style: TextStyle(
                                          color: textSecondary,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .primaryContainer,
                                  borderRadius:
                                      BorderRadius.circular(AppRadius.pill),
                                ),
                                child: Text(
                                  isMovie ? 'Movie' : 'TV',
                                  style: TextStyle(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onPrimaryContainer,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
