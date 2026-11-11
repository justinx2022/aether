import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:skystream/core/utils/layout_constants.dart';
import 'package:skystream/core/theme/app_world.dart';
import 'package:skystream/l10n/generated/app_localizations.dart';
import 'package:skystream/shared/widgets/cards_wrapper.dart';
import 'package:skystream/shared/widgets/glass_surface.dart';
import 'package:skystream/features/home/presentation/delegates/home_search_delegate.dart';
import 'package:skystream/features/home/presentation/home_provider.dart';
import 'package:skystream/shared/widgets/profile_app_bar_button.dart';

import 'dart:async';

/// A custom header bar for the widescreen dashboard layout.
///
/// Contains: carousel prev/next arrows, capsule search, provider chip.
class DashboardHeaderBar extends ConsumerWidget {
  final FocusNode searchFocusNode;
  final VoidCallback onShowProviderSelector;

  /// Called when the user taps the left arrow (carousel previous).
  final VoidCallback? onPrevious;

  /// Called when the user taps the right arrow (carousel next).
  final VoidCallback? onNext;

  const DashboardHeaderBar({
    super.key,
    required this.searchFocusNode,
    required this.onShowProviderSelector,
    this.onPrevious,
    this.onNext,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;

    final colors = AppWorldTokens.colorsOf(context);
    final hasCarousel = onPrevious != null && onNext != null;

    return Container(
      height: LayoutConstants.dashboardHeaderHeight,
      padding: const EdgeInsets.symmetric(
        horizontal: LayoutConstants.dashboardContentPadding,
      ),
      child: Row(
        children: [
          // Aether Logo Emblem & Title
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF6366F1).withValues(alpha: 0.35),
                      blurRadius: 12,
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
                      Icons.auto_awesome,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                'AETHER',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                  letterSpacing: 2.5,
                ),
              ),
            ],
          ),
          const SizedBox(width: 20),

          // Carousel prev / next arrows
          CardsWrapper(
            scaleFactor: 1.01,
            onTap: () => onPrevious?.call(),
            borderRadius: BorderRadius.circular(8),
            child: GlassSurface(
              borderRadius: BorderRadius.circular(8),
              padding: EdgeInsets.zero,
              blurSigma: 12,
              shadow: false,
              fill: colors.elevated.withValues(alpha: colors.isDark ? 0.42 : 0.62),
              child: SizedBox(
                width: 32,
                height: 32,
                child: Icon(
                  Icons.arrow_back_ios_new,
                  size: 14,
                  color: hasCarousel
                      ? colors.textPrimary
                      : colors.textSecondary.withValues(alpha: 0.3),
                ),
              ),
            ),
          ),
          const SizedBox(width: 4),
          CardsWrapper(
            scaleFactor: 1.01,
            onTap: () => onNext?.call(),
            borderRadius: BorderRadius.circular(8),
            child: GlassSurface(
              borderRadius: BorderRadius.circular(8),
              padding: EdgeInsets.zero,
              blurSigma: 12,
              shadow: false,
              fill: colors.elevated.withValues(alpha: colors.isDark ? 0.42 : 0.62),
              child: SizedBox(
                width: 32,
                height: 32,
                child: Icon(
                  Icons.arrow_forward_ios,
                  size: 14,
                  color: hasCarousel
                      ? colors.textPrimary
                      : colors.textSecondary.withValues(alpha: 0.3),
                ),
              ),
            ),
          ),

          const SizedBox(width: 16),

          // Capsule search bar
          Expanded(
            child: CardsWrapper(
              scaleFactor: 1.01,
              focusNode: searchFocusNode,
              onTap: () {
                unawaited(
                  showSearch<void>(
                    context: context,
                    delegate: HomeSearchDelegate(),
                    useRootNavigator: false,
                    maintainState: true,
                  ),
                );
              },
              borderRadius: BorderRadius.circular(LayoutConstants.radiusPill),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 500),
                child: GlassSurface(
                  borderRadius: BorderRadius.circular(
                    LayoutConstants.radiusPill,
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  blurSigma: 14,
                  shadow: false,
                  fill: colors.elevated.withValues(
                    alpha: colors.isDark ? 0.38 : 0.62,
                  ),
                  child: SizedBox(
                    height: 38,
                    child: Row(
                      children: [
                        Icon(
                          Icons.search_rounded,
                          size: 18,
                          color: colors.textSecondary,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            '${l10n.search}...',
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w500,
                              color: colors.textSecondary,
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

          const SizedBox(width: 16),

          // Refresh button
          CardsWrapper(
            scaleFactor: 1.01,
            onTap: () => ref.read(homeDataProvider.notifier).fetch(),
            borderRadius: BorderRadius.circular(50),
            child: GlassSurface(
              borderRadius: BorderRadius.circular(18),
              padding: EdgeInsets.zero,
              blurSigma: 14,
              shadow: false,
              fill: colors.elevated.withValues(alpha: colors.isDark ? 0.42 : 0.62),
              child: SizedBox(
                width: 36,
                height: 36,
                child: Icon(
                  Icons.refresh_rounded,
                  color: colors.textSecondary,
                  size: 18,
                ),
              ),
            ),
          ),

          const SizedBox(width: 12),

          const ProfileAppBarButton(),
        ],
      ),
    );
  }
}
