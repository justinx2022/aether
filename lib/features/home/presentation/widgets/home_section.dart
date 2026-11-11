import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollCacheExtent;
import 'package:skystream/core/utils/responsive_breakpoints.dart';
import 'package:skystream/core/router/app_router.dart';
import 'package:skystream/core/utils/image_fallbacks.dart';
import 'package:skystream/core/utils/layout_constants.dart';

import '../../../../core/domain/entity/multimedia_item.dart';
import '../../../../shared/widgets/desktop_scroll_wrapper.dart';
import '../../../../shared/widgets/multimedia_card.dart';

class HomeSection extends ConsumerStatefulWidget {
  final String title;
  final List<MultimediaItem> items;
  const HomeSection({super.key, required this.title, required this.items});

  @override
  ConsumerState<HomeSection> createState() => _HomeSectionState();
}

class _HomeSectionState extends ConsumerState<HomeSection> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.items.isEmpty) return const SizedBox.shrink();

    final isLarge = context.isTabletOrLarger;

    final double totalHeight = isLarge ? 350.0 : 230.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            widget.title,
            style: isLarge
                ? Theme.of(context).textTheme.headlineSmall
                      ?.copyWith(fontWeight: FontWeight.bold)
                : Theme.of(context).textTheme.titleLarge,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        SizedBox(
          height: totalHeight,
          child: DesktopScrollWrapper(
            controller: _scrollController,
            showButtons: isLarge, // Show nav buttons on both desktop and TV
            child: Builder(
              builder: (context) {
                final bool isRankedSection =
                    widget.title.toLowerCase().contains('trending') ||
                    widget.title.toLowerCase().contains('top 10') ||
                    widget.title.toLowerCase().contains('popular');

                final double rankOffset = isRankedSection ? (isLarge ? 36.0 : 24.0) : 0.0;
                final double cardWidth = (isLarge ? 200.0 : 130.0) + rankOffset;
                final double spacing = isLarge
                    ? LayoutConstants.spacingLg
                    : LayoutConstants.spacingSm;

                return ListView.builder(
                  controller: _scrollController,
                  scrollCacheExtent: const ScrollCacheExtent.pixels(600),
                  padding: const EdgeInsets.symmetric(
                    horizontal: LayoutConstants.spacingMd,
                    vertical: LayoutConstants.spacingXs,
                  ),
                  scrollDirection: Axis.horizontal,
                  itemCount: widget.items.length,
                  itemExtent: cardWidth + spacing,
                  itemBuilder: (context, index) {
                    final item = widget.items[index];
                    return Padding(
                      padding: EdgeInsets.only(right: spacing),
                      child: MultimediaCard(
                        key: ValueKey(item.url),
                        imageUrl:
                            AppImageFallbacks.poster(
                              item.posterUrl,
                              label: item.title,
                            ) ??
                            '',
                        title: item.title,
                        heroTag: 'home_${item.url}_$index',
                        rankIndex: isRankedSection && index < 10 ? index + 1 : null,
                        onTap: () =>
                            DetailsRoute($extra: DetailsRouteExtra(item: item))
                                .push<void>(context),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}
