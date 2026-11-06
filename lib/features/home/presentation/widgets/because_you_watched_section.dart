import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/domain/entity/multimedia_item.dart';
import '../../../../core/recommendations/recommendations_service.dart';
import '../../../../core/router/app_router.dart';
import '../../../explore/presentation/view_all_screen.dart';
import '../../../explore/presentation/widgets/media_horizontal_list.dart';

/// Netflix-style personalized recommendation shelf: "Because you watched [Title]..."
class BecauseYouWatchedSection extends ConsumerWidget {
  final MultimediaItem item;

  const BecauseYouWatchedSection({super.key, required this.item});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final similarAsync = ref.watch(similarItemsProvider(item));

    return similarAsync.when(
      data: (items) {
        if (items.isEmpty) return const SizedBox.shrink();

        return Padding(
          padding: const EdgeInsets.only(bottom: 16.0),
          child: MediaHorizontalList(
            title: 'Because you watched ${item.title}',
            mediaList: items,
            category: ViewAllCategory.providerContent,
            showViewAll: false,
            heroTagPrefix: 'because_watched',
            onTap: (selected) {
              if (selected.provider == 'tmdb' && selected.tmdbId != null) {
                TmdbDetailsRoute(
                  movieId: selected.tmdbId!,
                  mediaType: selected.tmdbMediaType,
                ).push<void>(context);
              } else {
                DetailsRoute($extra: DetailsRouteExtra(item: selected))
                    .push<void>(context);
              }
            },
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (err, stack) => const SizedBox.shrink(),
    );
  }
}
