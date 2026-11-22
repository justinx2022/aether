import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/tmdb_genre.dart';
import '../../../shared/widgets/cards_wrapper.dart';
import '../../../shared/widgets/no_scrollbar_behavior.dart';
import '../../../shared/widgets/multimedia_card.dart';
import '../data/explore_tmdb_provider.dart';
import '../data/explore_mode_provider.dart';
import '../data/explore_discovery_provider.dart';
import 'anilist_explore_screen.dart';
import 'widgets/explore_carousel.dart';
import 'widgets/explore_header_bar.dart';
import 'widgets/hover_border_gradient.dart';
import 'widgets/unified_filter_dialog.dart';
import '../data/explore_filter_provider.dart';
import 'delegates/explore_search_delegate.dart';
import '../../../../core/utils/layout_constants.dart';
import '../../../../core/utils/responsive_breakpoints.dart';
import '../../../../core/providers/device_info_provider.dart';
import '../../../../shared/widgets/shimmer_placeholder.dart';
import '../../../../core/domain/entity/multimedia_item.dart';
import 'widgets/explore_mode_selector_dialog.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../core/router/app_router.dart';
import '../../../core/recommendations/recommendations_service.dart';

import 'dart:async';

class ExploreScreen extends ConsumerStatefulWidget {
  const ExploreScreen({super.key});

  @override
  ConsumerState<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends ConsumerState<ExploreScreen>
    with AutomaticKeepAliveClientMixin {
  late ScrollController _scrollController;
  final ValueNotifier<bool> _isScrolledNotifier = ValueNotifier<bool>(false);
  final ValueNotifier<double> _appBarOpacityNotifier = ValueNotifier<double>(0);
  final ValueNotifier<bool> _showBottomFade = ValueNotifier(false);
  final FocusNode _firstActionFocusNode = FocusNode();

  /// Carousel controller exposed by ExploreCarousel via [onControllerReady].
  HeroCarouselController? _carouselController;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _scrollController.addListener(_onScroll);
  }

  bool _isWidescreenForScroll() {
    final profile = ref.read(deviceProfileProvider).asData?.value;
    return profile?.isLargeScreen == true || context.isTabletOrLarger;
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;

    // Track gradient edge hint visibility — fades away near the bottom.
    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.offset;
    final showFade = maxScroll > 0 && currentScroll < maxScroll - 10;
    if (showFade != _showBottomFade.value) {
      _showBottomFade.value = showFade;
    }

    // Infinite discovery pagination trigger: load more seamlessly when approaching bottom
    if (maxScroll > 0 && currentScroll >= maxScroll - 1200) {
      ref.read(exploreDiscoveryNotifierProvider.notifier).loadMore();
    }

    // On widescreen there is no mobile AppBar, skip calculations
    if (_isWidescreenForScroll()) return;

    final offset = _scrollController.offset * 0.8;
    final opacity = (offset / 300).clamp(0.0, 1.0);
    if (opacity != _appBarOpacityNotifier.value) {
      _appBarOpacityNotifier.value = opacity;
    }
    final isScrolled = _scrollController.offset > 200;
    if (isScrolled != _isScrolledNotifier.value) {
      _isScrolledNotifier.value = isScrolled;
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _isScrolledNotifier.dispose();
    _appBarOpacityNotifier.dispose();
    _showBottomFade.dispose();
    _firstActionFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin

    final profile = ref.watch(deviceProfileProvider).asData?.value;
    // Use profile?.isLargeScreen so this matches AppScaffold's sidebar
    // decision even when the ExploreScreen's context width is narrowed
    // by the sidebar (e.g. iPad portrait). A television needs no clause of
    // its own: isLargeScreen already ORs in DeviceProfile.isTv, and 960 dp
    // clears the tablet breakpoint regardless.
    final isWidescreen =
        profile?.isLargeScreen == true || context.isTabletOrLarger;

    if (isWidescreen) {
      return Scaffold(
        extendBodyBehindAppBar: false,
        backgroundColor: Colors.transparent,
        body: _buildWidescreenBody(context),
      );
    }

    // Mobile layout: existing AppBar
    return ValueListenableBuilder<bool>(
      valueListenable: _isScrolledNotifier,
      builder: (context, isScrolled, child) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final overlayStyle = isDark
            ? SystemUiOverlayStyle.light
            : SystemUiOverlayStyle.dark;

        return Scaffold(
          backgroundColor: Colors.transparent,
          extendBodyBehindAppBar: true,
          appBar: AppBar(
            systemOverlayStyle: overlayStyle,
            forceMaterialTransparency: true,
            backgroundColor: Colors.transparent,
            elevation: 0,
            flexibleSpace: ValueListenableBuilder<double>(
              valueListenable: _appBarOpacityNotifier,
              // See home_screen.dart for why we fade via color alpha rather
              // than Opacity — same saveLayer-per-frame issue.
              builder: (context, opacity, child) {
                return Container(
                  color: Theme.of(context).scaffoldBackgroundColor
                      .withValues(alpha: opacity),
                );
              },
            ),
            title: Text(
              AppLocalizations.of(context)!.explore,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            centerTitle: false,
            actions: [
              // Explore Mode Selector (Movies / Anime / Stremio Add-ons)
              Padding(
                padding: const EdgeInsets.only(
                  right: LayoutConstants.spacingMd,
                ),
                child: CardsWrapper(
                  onTap: () => showExploreModeSelectorDialog(context, ref),
                  borderRadius: BorderRadius.circular(50),
                  child: Consumer(
                    builder: (context, ref, _) {
                      final mode = ref.watch(exploreModeProvider);
                      final l10n = AppLocalizations.of(context)!;
                      final onSurfaceColor = Theme.of(context)
                          .colorScheme
                          .onSurface;

                      Widget iconWidget;
                      String tooltipMsg;

                      switch (mode) {
                        case ExploreModeType.movies:
                          iconWidget = Icon(
                            Icons.movie_outlined,
                            color: onSurfaceColor,
                            size: 18,
                          );
                          tooltipMsg = l10n.exploreMovies;
                          break;
                        case ExploreModeType.anime:
                          iconWidget = SizedBox(
                            width: 16,
                            height: 16,
                            child: CustomPaint(
                              painter: AnimeLogoPainter(color: onSurfaceColor),
                            ),
                          );
                          tooltipMsg = l10n.exploreAnime;
                          break;
                      }

                      return Tooltip(
                        message: tooltipMsg,
                        child: CircleAvatar(
                          backgroundColor: onSurfaceColor.withValues(
                            alpha: 0.1,
                          ),
                          radius: 18,
                          child: iconWidget,
                        ),
                      );
                    },
                  ),
                ),
              ),

              Padding(
                padding: const EdgeInsets.only(
                  right: LayoutConstants.spacingMd,
                ),
                child: Consumer(
                  builder: (context, ref, _) {
                    final filters = ref.watch(exploreFilterProvider);
                    final hasActiveFilter =
                        filters.selectedGenre != null ||
                        filters.selectedYear != null ||
                        filters.minRating != null;

                    return CardsWrapper(
                      onTap: () {
                        unawaited(
                          showDialog<void>(
                            context: context,
                            builder: (context) => const UnifiedFilterDialog(),
                          ),
                        );
                      },
                      borderRadius: BorderRadius.circular(50),
                      child: Tooltip(
                        message: 'Filter',
                        child: CircleAvatar(
                          backgroundColor: hasActiveFilter
                              ? Theme.of(context).colorScheme.primary
                              : Theme.of(context).colorScheme.onSurface
                                    .withValues(alpha: 0.1),
                          radius: 18,
                          child: Icon(
                            Icons.tune,
                            color: Theme.of(context).colorScheme.onSurface,
                            size: 18,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),

              Padding(
                padding: const EdgeInsets.only(
                  right: LayoutConstants.spacingMd,
                ),
                child: CardsWrapper(
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
                  child: CircleAvatar(
                    backgroundColor: Theme.of(context).colorScheme.onSurface
                        .withValues(alpha: 0.1),
                    radius: 18,
                    child: Icon(
                      Icons.search,
                      color: Theme.of(context).colorScheme.onSurface,
                      size: 18,
                    ),
                  ),
                ),
              ),
            ],
          ),
          body: _withGradientEdgeHint(_buildActiveExploreBody(context)),
        );
      },
    );
  }

  Widget _buildActiveExploreBody(BuildContext context) {
    final mode = ref.watch(exploreModeProvider);
    switch (mode) {
      case ExploreModeType.movies:
        return _buildScrollView(context);
      case ExploreModeType.anime:
        return AnilistExploreScreen(
          scrollController: _scrollController,
          firstActionFocusNode: _firstActionFocusNode,
          onControllerReady: (c) => setState(() => _carouselController = c),
        );
    }
  }

  Widget _buildWidescreenBody(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: ExploreHeaderBar(
            searchFocusNode: _firstActionFocusNode,
            onPrevious: _carouselController != null
                ? () => _carouselController!.previousPage()
                : null,
            onNext: _carouselController != null
                ? () => _carouselController!.nextPage()
                : null,
          ),
        ),
        Expanded(
          child: _withGradientEdgeHint(_buildActiveExploreBody(context)),
        ),
      ],
    );
  }

  Widget _withGradientEdgeHint(Widget scrollView) {
    return Stack(
      children: [
        ScrollConfiguration(
          behavior: const NoScrollbarBehavior(),
          child: scrollView,
        ),
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          height: 48, // Taller height for smoother blend
          child: ValueListenableBuilder<bool>(
            valueListenable: _showBottomFade,
            builder: (context, show, _) {
              if (!show) return const SizedBox.shrink();
              final surfaceColor = Theme.of(context).colorScheme.surface;
              return IgnorePointer(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        surfaceColor.withValues(alpha: 0.0),
                        surfaceColor.withValues(alpha: 0.15),
                        surfaceColor.withValues(alpha: 0.45),
                        surfaceColor.withValues(alpha: 0.8),
                        surfaceColor,
                      ],
                      stops: const [0.0, 0.5, 0.75, 0.9, 1.0],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  void _refreshAll() {
    ref.read(exploreDiscoveryNotifierProvider.notifier).loadInitial();
    ref.invalidate(exploreDiscoveryProvider);
    ref.invalidate(genresProvider);
  }

  static const List<(TmdbGenre?, String)> _kGenrePills = [
    (null, 'All Genres'),
    (TmdbGenre(id: 28, name: 'Action'), 'Action'),
    (TmdbGenre(id: 12, name: 'Adventure'), 'Adventure'),
    (TmdbGenre(id: 16, name: 'Animation'), 'Animation'),
    (TmdbGenre(id: 35, name: 'Comedy'), 'Comedy'),
    (TmdbGenre(id: 80, name: 'Crime'), 'Crime'),
    (TmdbGenre(id: 99, name: 'Documentary'), 'Documentary'),
    (TmdbGenre(id: 18, name: 'Drama'), 'Drama'),
    (TmdbGenre(id: 10751, name: 'Family'), 'Family'),
    (TmdbGenre(id: 14, name: 'Fantasy'), 'Fantasy'),
    (TmdbGenre(id: 27, name: 'Horror'), 'Horror'),
    (TmdbGenre(id: 9648, name: 'Mystery'), 'Mystery'),
    (TmdbGenre(id: 10749, name: 'Romance'), 'Romance'),
    (TmdbGenre(id: 878, name: 'Sci-Fi'), 'Sci-Fi'),
    (TmdbGenre(id: 53, name: 'Thriller'), 'Thriller'),
  ];

  static const List<(String?, String)> _kCountryOptions = [
    (null, 'All Countries'),
    ('US', 'United States 🇺🇸'),
    ('GB', 'United Kingdom 🇬🇧'),
    ('KR', 'South Korea 🇰🇷'),
    ('JP', 'Japan 🇯🇵'),
    ('FR', 'France 🇫🇷'),
    ('DE', 'Germany 🇩🇪'),
    ('IN', 'India 🇮🇳'),
    ('ES', 'Spain 🇪🇸'),
    ('CA', 'Canada 🇨🇦'),
    ('IT', 'Italy 🇮🇹'),
    ('AU', 'Australia 🇦🇺'),
  ];

  static const List<(String, String, IconData)> _kSortOptions = [
    ('popularity', 'Popularity', Icons.trending_up_rounded),
    ('rating', 'Highest Rated', Icons.star_rounded),
    ('newest', 'Newest First', Icons.schedule_rounded),
    ('title', 'Title (A-Z)', Icons.sort_by_alpha_rounded),
  ];

  Widget _buildScrollView(BuildContext context) {
    final discoveryAsync = ref.watch(exploreDiscoveryProvider);
    final filters = ref.watch(exploreFilterProvider);
    final isDesktop = context.isTabletOrLarger;
    final topPadding = MediaQuery.paddingOf(context).top +
        (isDesktop ? 12.0 : kToolbarHeight + 8.0);

    return RefreshIndicator(
      onRefresh: () async => _refreshAll(),
      child: CustomScrollView(
        controller: _scrollController,
        slivers: [
          SliverToBoxAdapter(
            child: SizedBox(height: topPadding),
          ),
          SliverToBoxAdapter(
            child: _buildDiscoveryControlDeck(context, filters),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 16)),
          ..._buildDiscoveryGridSlivers(context, discoveryAsync, filters),
          SliverPadding(
            padding: EdgeInsets.only(
              bottom: LayoutConstants.shellBottomContentPadding(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDiscoveryControlDeck(
    BuildContext context,
    FilterState filters,
  ) {
    final theme = Theme.of(context);
    final isDesktop = context.isTabletOrLarger;
    final horizontalPadding = isDesktop
        ? LayoutConstants.dashboardContentPadding
        : LayoutConstants.spacingMd;

    final hasActiveFilter = filters.selectedGenre != null ||
        filters.selectedYear != null ||
        filters.selectedCountry != null ||
        filters.mediaType != 'all' ||
        filters.sortBy != 'popularity';

    final countryLabel = _kCountryOptions
        .firstWhere(
          (c) => c.$1 == filters.selectedCountry,
          orElse: () => (null, 'All Countries'),
        )
        .$2;

    final sortLabel = _kSortOptions
        .firstWhere(
          (s) => s.$1 == filters.sortBy,
          orElse: () => ('popularity', 'Popularity', Icons.trending_up_rounded),
        )
        .$2;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Media Type Selector Pills
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildTypePill(context, 'all', 'All Content', Icons.grid_view_rounded, filters.mediaType == 'all'),
              _buildTypePill(context, 'movie', 'Movies', Icons.movie_outlined, filters.mediaType == 'movie'),
              _buildTypePill(context, 'series', 'TV Series', Icons.tv_rounded, filters.mediaType == 'series'),
              _buildTypePill(context, 'anime', 'Anime', Icons.play_circle_outline_rounded, filters.mediaType == 'anime'),
            ],
          ),
          const SizedBox(height: 14),

          // 2. Horizontally scrollable Genre Chips
          SizedBox(
            height: 38,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              clipBehavior: Clip.none,
              itemCount: _kGenrePills.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final pill = _kGenrePills[index];
                final isSelected = (pill.$1 == null && filters.selectedGenre == null) ||
                    (pill.$1 != null && filters.selectedGenre?.id == pill.$1!.id);

                return FilterChip(
                  label: Text(pill.$2),
                  selected: isSelected,
                  showCheckmark: false,
                  labelStyle: TextStyle(
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                    color: isSelected
                        ? theme.colorScheme.onPrimary
                        : theme.colorScheme.onSurface,
                  ),
                  backgroundColor: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
                  selectedColor: theme.colorScheme.primary,
                  side: BorderSide(
                    color: isSelected
                        ? theme.colorScheme.primary
                        : theme.colorScheme.outlineVariant.withValues(alpha: 0.25),
                    width: 1,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
                  onSelected: (_) {
                    ref.read(exploreFilterProvider.notifier).setGenre(pill.$1);
                  },
                );
              },
            ),
          ),
          const SizedBox(height: 14),

          // 3. Quick Filter Attribute Row (Country, Era, Sort, Reset)
          Wrap(
            spacing: 10,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              // Country Picker Action Pill
              ActionChip(
                avatar: Icon(Icons.public_rounded, size: 16, color: theme.colorScheme.primary),
                label: Text(countryLabel),
                backgroundColor: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                onPressed: () => _showCountrySelector(context),
              ),

              // Year / Era Picker Action Pill
              ActionChip(
                avatar: Icon(Icons.calendar_today_rounded, size: 16, color: theme.colorScheme.primary),
                label: Text(filters.selectedYear != null ? '${filters.selectedYear}' : 'All Years'),
                backgroundColor: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                onPressed: () => _showYearSelector(context),
              ),

              // Sort Action Pill
              ActionChip(
                avatar: Icon(Icons.sort_rounded, size: 16, color: theme.colorScheme.primary),
                label: Text(sortLabel),
                backgroundColor: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                onPressed: () => _showSortSelector(context),
              ),

              if (hasActiveFilter)
                ActionChip(
                  avatar: const Icon(Icons.close_rounded, size: 16, color: Colors.redAccent),
                  label: const Text('Reset', style: TextStyle(color: Colors.redAccent)),
                  backgroundColor: Colors.redAccent.withValues(alpha: 0.1),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  onPressed: () => ref.read(exploreFilterProvider.notifier).clearAll(),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTypePill(
    BuildContext context,
    String type,
    String label,
    IconData icon,
    bool isSelected,
  ) {
    final theme = Theme.of(context);
    return ChoiceChip(
      avatar: Icon(
        icon,
        size: 16,
        color: isSelected ? theme.colorScheme.onPrimary : theme.colorScheme.onSurfaceVariant,
      ),
      label: Text(label),
      selected: isSelected,
      showCheckmark: false,
      labelStyle: TextStyle(
        fontSize: 13,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
        color: isSelected ? theme.colorScheme.onPrimary : theme.colorScheme.onSurface,
      ),
      backgroundColor: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.25),
      selectedColor: theme.colorScheme.primary,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(LayoutConstants.radiusPill),
      ),
      onSelected: (_) {
        ref.read(exploreFilterProvider.notifier).setMediaType(type);
      },
    );
  }

  void _showCountrySelector(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        final current = ref.read(exploreFilterProvider).selectedCountry;
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Text(
                  'Select Country / Region',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: _kCountryOptions.length,
                  itemBuilder: (ctx, idx) {
                    final option = _kCountryOptions[idx];
                    final isSel = option.$1 == current;
                    return ListTile(
                      title: Text(option.$2),
                      trailing: isSel
                          ? Icon(Icons.check_rounded, color: Theme.of(context).colorScheme.primary)
                          : null,
                      onTap: () {
                        ref.read(exploreFilterProvider.notifier).setCountry(option.$1);
                        Navigator.of(ctx).pop();
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showYearSelector(BuildContext context) {
    final currentYear = ref.read(exploreFilterProvider).selectedYear;
    final years = <int?>[
      null,
      2026,
      2025,
      2024,
      2023,
      2022,
      2021,
      2020,
      2018,
      2015,
      2010,
      2000,
    ];

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Text(
                  'Select Release Era / Year',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: years.length,
                  itemBuilder: (ctx, idx) {
                    final yr = years[idx];
                    final isSel = yr == currentYear;
                    return ListTile(
                      title: Text(yr != null ? '$yr' : 'All Years'),
                      trailing: isSel
                          ? Icon(Icons.check_rounded, color: Theme.of(context).colorScheme.primary)
                          : null,
                      onTap: () {
                        ref.read(exploreFilterProvider.notifier).setYear(yr);
                        Navigator.of(ctx).pop();
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showSortSelector(BuildContext context) {
    final currentSort = ref.read(exploreFilterProvider).sortBy;

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Text(
                  'Sort Discovery By',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              ..._kSortOptions.map((opt) {
                final isSel = opt.$1 == currentSort;
                return ListTile(
                  leading: Icon(opt.$3, color: isSel ? Theme.of(context).colorScheme.primary : null),
                  title: Text(opt.$2),
                  trailing: isSel
                      ? Icon(Icons.check_rounded, color: Theme.of(context).colorScheme.primary)
                      : null,
                  onTap: () {
                    ref.read(exploreFilterProvider.notifier).setSortBy(opt.$1);
                    Navigator.of(ctx).pop();
                  },
                );
              }),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }

  List<Widget> _buildDiscoveryGridSlivers(
    BuildContext context,
    AsyncValue<List<MultimediaItem>> discoveryAsync,
    FilterState filters,
  ) {
    final isDesktop = context.isTabletOrLarger;
    final padding = EdgeInsets.symmetric(
      horizontal: isDesktop
          ? LayoutConstants.dashboardContentPadding
          : LayoutConstants.spacingMd,
    );

    return switch (discoveryAsync) {
      AsyncLoading() => [
          SliverPadding(
            padding: padding,
            sliver: SliverGrid(
              gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: isDesktop ? 220 : 160,
                childAspectRatio: 2 / 3.4,
                crossAxisSpacing: 14,
                mainAxisSpacing: 14,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, index) => ShimmerPlaceholder.rectangular(
                  width: double.infinity,
                  height: double.infinity,
                  borderRadius: 14,
                ),
                childCount: 12,
              ),
            ),
          ),
        ],
      AsyncError(:final error) => [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.wifi_off_rounded, size: 54, color: Theme.of(context).colorScheme.error),
                    const SizedBox(height: 16),
                    const Text(
                      'Could not reach discovery index',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      error.toString(),
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: _refreshAll,
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      AsyncData(:final value) => value.isEmpty
          ? [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 24),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(
                          Icons.search_off_rounded,
                          size: 64,
                          color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'No titles match your discovery filters',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Try choosing a different genre, country, or clearing your active filters.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                        ),
                        const SizedBox(height: 20),
                        FilledButton.tonalIcon(
                          onPressed: () => ref.read(exploreFilterProvider.notifier).clearAll(),
                          icon: const Icon(Icons.restart_alt_rounded),
                          label: const Text('Reset All Filters'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ]
          : [
              SliverPadding(
                padding: padding,
                sliver: SliverGrid(
                  gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: isDesktop ? 220 : 160,
                    childAspectRatio: 2 / 3.4,
                    crossAxisSpacing: 14,
                    mainAxisSpacing: 14,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final item = value[index];
                      final uniqueTag = 'explore_grid_${item.id}_${item.title.hashCode}_$index';

                      return MultimediaCard(
                        imageUrl: item.posterImageUrl,
                        title: item.title,
                        heroTag: uniqueTag,
                        onTap: () {
                          final itemToOpen = item.url.isNotEmpty && !item.url.startsWith('aether:')
                              ? item
                              : item.copyWith(
                                  url: RecommendationsService.catalogueToken(
                                    imdbId: item.imdbId ?? (item.tmdbId != null ? 'tmdb:${item.tmdbId}' : ''),
                                    type: item.contentType == MultimediaContentType.series ? 'series' : 'movie',
                                    title: item.title,
                                    year: item.year?.toString(),
                                  ),
                                  provider: RecommendationsService.catalogueProvider,
                                );
                          DetailsRoute($extra: DetailsRouteExtra(item: itemToOpen))
                              .push<void>(context);
                        },
                      );
                    },
                    childCount: value.length,
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Consumer(
                  builder: (context, ref, _) {
                    final discoveryState = ref.watch<ExploreDiscoveryState>(exploreDiscoveryNotifierProvider);
                    if (!discoveryState.isLoadingMore) return const SizedBox.shrink();
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Center(
                        child: CircularProgressIndicator.adaptive(),
                      ),
                    );
                  },
                ),
              ),
            ],
    };
  }
}
