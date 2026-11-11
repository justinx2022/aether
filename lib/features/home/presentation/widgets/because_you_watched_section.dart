import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/domain/entity/multimedia_item.dart';
import '../../../../core/recommendations/discovery_engine.dart';
import '../../../../core/router/app_router.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../explore/presentation/view_all_screen.dart';
import '../../../explore/presentation/widgets/media_horizontal_list.dart';

/// Personalized recommendation shelf: "Because you watched [Title]..."
class BecauseYouWatchedSection extends ConsumerWidget {
  final MultimediaItem item;

  const BecauseYouWatchedSection({
    super.key,
    required this.item,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final similarAsync = ref.watch(deepSimilarItemsProvider(item));

    return similarAsync.when(
      data: (items) {
        if (items.isEmpty) return const SizedBox.shrink();

        return Padding(
          padding: const EdgeInsets.only(bottom: 16.0),
          child: MediaHorizontalList(
            title: l10n.discoverBecauseYouWatched(item.title),
            mediaList: items,
            category: ViewAllCategory.providerContent,
            showViewAll: false,
            heroTagPrefix: 'because_watched_${item.title.hashCode}',
            onTap: (selected) {
              DetailsRoute($extra: DetailsRouteExtra(item: selected))
                  .push<void>(context);
            },
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (err, stack) => const SizedBox.shrink(),
    );
  }
}
