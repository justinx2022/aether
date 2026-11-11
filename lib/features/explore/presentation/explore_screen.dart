import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/utils/layout_constants.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../../shared/widgets/cards_wrapper.dart';
import '../../../../shared/widgets/desktop_scroll_wrapper.dart';
import '../../../../shared/widgets/glass_surface.dart';
import '../../../../shared/widgets/multimedia_card.dart';
import '../../../../shared/widgets/shimmer_placeholder.dart';
import '../data/genre_catalog_provider.dart';
import 'delegates/explore_search_delegate.dart';

const List<({String id, String label, IconData icon})> kExploreGenres = [
  (id: 'All', label: 'All', icon: Icons.auto_awesome),
  (id: 'Action', label: 'Action', icon: Icons.local_fire_department_rounded),
  (id: 'Adventure', label: 'Adventure', icon: Icons.explore_rounded),
  (id: 'Animation', label: 'Animation', icon: Icons.animation_rounded),
  (id: 'Comedy', label: 'Comedy', icon: Icons.sentiment_very_satisfied_rounded),
  (id: 'Crime', label: 'Crime', icon: Icons.shield_rounded),
  (id: 'Documentary', label: 'Documentary', icon: Icons.videocam_rounded),
  (id: 'Drama', label: 'Drama', icon: Icons.theater_comedy_rounded),
  (id: 'Family', label: 'Family', icon: Icons.family_restroom_rounded),
  (id: 'Fantasy', label: 'Fantasy', icon: Icons.auto_fix_high_rounded),
  (id: 'Horror', label: 'Horror', icon: Icons.nightlight_round),
  (id: 'Mystery', label: 'Mystery', icon: Icons.help_outline_rounded),
  (id: 'Romance', label: 'Romance', icon: Icons.favorite_rounded),
  (id: 'Sci-Fi', label: 'Sci-Fi', icon: Icons.rocket_launch_rounded),
  (id: 'Thriller', label: 'Thriller', icon: Icons.flash_on_rounded),
  (id: 'Turkish Dizis', label: 'Turkish Dizis', icon: Icons.star_rounded),
  (id: 'Telenovelas', label: 'Telenovelas', icon: Icons.movie_filter_rounded),
  (id: 'Arabic Spotlight', label: 'Arabic Spotlight', icon: Icons.public_rounded),
];

class ExploreScreen extends ConsumerStatefulWidget {
  const ExploreScreen({super.key});

  @override
  ConsumerState<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends ConsumerState<ExploreScreen>
    with AutomaticKeepAliveClientMixin {
  late ScrollController _scrollController;
  final FocusNode _searchFocusNode = FocusNode();

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  int _calculateColumnCount(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width >= 1400) return 7;
    if (width >= 1100) return 6;
    if (width >= 850) return 5;
    if (width >= 600) return 4;
    if (width >= 400) return 3;
    return 2;
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    final selectedGenre = ref.watch(selectedGenreProvider);
    final selectedType = ref.watch(selectedTypeProvider);
    final contentAsync = ref.watch(genreContentProvider);

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isWindows = theme.platform == TargetPlatform.windows;
    final overlayStyle = isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark;

    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        systemOverlayStyle: overlayStyle,
        forceMaterialTransparency: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: RepaintBoundary(
          child: GlassSurface(
            borderRadius: BorderRadius.zero,
            padding: EdgeInsets.zero,
            blurSigma: isWindows ? 0 : 12,
            shadow: false,
            useVibrancy: false,
            rimStrength: 0.4,
            fill: isWindows
                ? theme.colorScheme.surface.withValues(alpha: isDark ? 0.86 : 0.90)
                : null,
            child: const SizedBox.expand(),
          ),
        ),
        title: Row(
          children: [
            Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF6366F1).withValues(alpha: 0.35),
                    blurRadius: 10,
                  ),
                ],
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.2),
                  width: 1,
                ),
              ),
              child: ClipOval(
                child: Image.asset(
                  'assets/images/aether_logo.jpg',
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => const Icon(
                    Icons.explore_rounded,
                    color: Colors.white,
                    size: 14,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              AppLocalizations.of(context)!.explore.toUpperCase(),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 18,
                letterSpacing: 2.0,
              ),
            ),
          ],
        ),
        actions: [
          // Content Type Filter Selector: All | Movies | Series
          _buildTypeSelector(context, selectedType),
          const SizedBox(width: 8),
          // Search Button
          Padding(
            padding: const EdgeInsets.only(right: LayoutConstants.spacingMd),
            child: CardsWrapper(
              focusNode: _searchFocusNode,
              onTap: () {
                unawaited(
                  showSearch<void>(
                    context: context,
                    delegate: ExploreSearchDelegate(),
                    useRootNavigator: false,
                    maintainState: true,
                  ),
                );
              },
              borderRadius: BorderRadius.circular(50),
              child: GlassSurface(
                borderRadius: BorderRadius.circular(18),
                padding: EdgeInsets.zero,
                blurSigma: 14,
                shadow: false,
                child: SizedBox(
                  width: 36,
                  height: 36,
                  child: Center(
                    child: Icon(
                      Icons.search_rounded,
                      color: Theme.of(context).colorScheme.onSurface,
                      size: 18,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: DesktopScrollWrapper(
        controller: _scrollController,
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(genreContentProvider);
          },
          child: CustomScrollView(
            controller: _scrollController,
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            slivers: [
              SliverPadding(
                padding: EdgeInsets.only(
                  top: MediaQuery.paddingOf(context).top + kToolbarHeight + 8,
                ),
              ),
              // 1. Strict Genre Selection Rail
              SliverToBoxAdapter(
                child: _buildGenreRail(context, selectedGenre),
              ),

              const SliverToBoxAdapter(
                child: SizedBox(height: 16),
              ),

              // 2. Relevant Movie / Show Grid
              contentAsync.when(
                data: (items) {
                  if (items.isEmpty) {
                    return SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.movie_filter_outlined,
                              size: 56,
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'No titles found for "$selectedGenre"',
                              style: TextStyle(
                                fontSize: 16,
                                color: Theme.of(context).colorScheme.onSurface,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Try selecting another genre or content type.',
                              style: TextStyle(
                                fontSize: 13,
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  final columns = _calculateColumnCount(context);

                  return SliverPadding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: LayoutConstants.spacingMd,
                    ),
                    sliver: SliverGrid(
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: columns,
                        childAspectRatio: 0.67,
                        crossAxisSpacing: LayoutConstants.spacingSm,
                        mainAxisSpacing: LayoutConstants.spacingMd,
                      ),
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final item = items[index];
                          return MultimediaCard(
                            imageUrl: item.posterUrl,
                            title: item.title,
                            heroTag: 'explore_${selectedGenre}_${item.imdbId ?? index}_${item.title.hashCode}',
                            isPortrait: true,
                            onTap: () {
                              DetailsRoute(
                                $extra: DetailsRouteExtra(item: item),
                              ).push<void>(context);
                            },
                          );
                        },
                        childCount: items.length,
                      ),
                    ),
                  );
                },
                loading: () => _buildShimmerGrid(context),
                error: (err, _) => SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.cloud_off_rounded, size: 56, color: Colors.redAccent),
                        const SizedBox(height: 12),
                        const Text(
                          'Failed to load catalog',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          err.toString(),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 16),
                        FilledButton.icon(
                          onPressed: () => ref.invalidate(genreContentProvider),
                          icon: const Icon(Icons.refresh),
                          label: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              SliverPadding(
                padding: EdgeInsets.only(
                  bottom: LayoutConstants.shellBottomContentPadding(context) + 32,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTypeSelector(BuildContext context, String selectedType) {
    const types = [
      ('all', 'All'),
      ('movie', 'Movies'),
      ('series', 'Series'),
    ];
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final activePillColor = isDark
        ? Colors.white.withValues(alpha: 0.18)
        : Colors.white.withValues(alpha: 0.80);
    final activeTextColor = isDark ? Colors.white : Colors.black;
    final inactiveTextColor = isDark
        ? Colors.white.withValues(alpha: 0.68)
        : Colors.black.withValues(alpha: 0.60);

    return GlassSurface(
      borderRadius: BorderRadius.circular(20),
      padding: const EdgeInsets.all(3),
      blurSigma: 14,
      shadow: false,
      child: SizedBox(
        height: 28,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: types.map((t) {
            final isSelected = selectedType == t.$1;
            return CardsWrapper(
              onTap: () {
                ref.read(selectedTypeProvider.notifier).state = t.$1;
              },
              borderRadius: BorderRadius.circular(16),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOutCubic,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isSelected ? activePillColor : Colors.transparent,
                  borderRadius: BorderRadius.circular(16),
                  border: isSelected
                      ? Border.all(
                          color: Colors.white.withValues(alpha: isDark ? 0.22 : 0.85),
                          width: 0.75,
                        )
                      : null,
                ),
                child: Text(
                  t.$2,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected ? activeTextColor : inactiveTextColor,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildGenreRail(BuildContext context, String selectedGenre) {
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: LayoutConstants.spacingMd),
        itemCount: kExploreGenres.length,
        separatorBuilder: (_, index) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final genre = kExploreGenres[index];
          final isSelected = selectedGenre == genre.id;

          return CardsWrapper(
            onTap: () {
              ref.read(selectedGenreProvider.notifier).state = genre.id;
            },
            borderRadius: BorderRadius.circular(22),
            child: LightweightGlassSurface(
              borderRadius: BorderRadius.circular(22),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              shadow: isSelected,
              rimStrength: isSelected ? 1.2 : 0.75,
              fill: isSelected
                  ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.85)
                  : Theme.of(context).brightness == Brightness.dark
                      ? Colors.white.withValues(alpha: 0.08)
                      : Colors.white.withValues(alpha: 0.62),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    genre.icon,
                    size: 15,
                    color: isSelected
                        ? Colors.white
                        : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.85),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    genre.label,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                      color: isSelected
                          ? Colors.white
                          : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.9),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildShimmerGrid(BuildContext context) {
    final columns = _calculateColumnCount(context);
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: LayoutConstants.spacingMd),
      sliver: SliverGrid(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: columns,
          childAspectRatio: 0.67,
          crossAxisSpacing: LayoutConstants.spacingSm,
          mainAxisSpacing: LayoutConstants.spacingMd,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, index) => ShimmerPlaceholder(borderRadius: 12),
          childCount: columns * 3,
        ),
      ),
    );
  }
}
