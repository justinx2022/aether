import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/tmdb_config.dart';
import '../../../core/models/tmdb_details.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/design_tokens.dart';
import '../../../shared/widgets/multimedia_card.dart';
import '../../../shared/widgets/thumbnail_error_placeholder.dart';
import '../../explore/data/explore_tmdb_provider.dart';

/// A focused, native filmography rather than sending viewers out to the web.
class ActorFilmographyScreen extends ConsumerStatefulWidget {
  const ActorFilmographyScreen({super.key, required this.actor});
  final TmdbCast actor;

  @override
  ConsumerState<ActorFilmographyScreen> createState() =>
      _ActorFilmographyScreenState();
}

class _ActorFilmographyScreenState extends ConsumerState<ActorFilmographyScreen> {
  late final Future<Map<String, dynamic>?> _person;

  @override
  void initState() {
    super.initState();
    _person = widget.actor.id == null
        ? Future.value(null)
        : ref.read(tmdbServiceProvider).getPersonDetails(widget.actor.id!);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(widget.actor.name)),
    body: FutureBuilder<Map<String, dynamic>?>(
      future: _person,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        final person = snapshot.data;
        final credits = (person?['combined_credits']?['cast'] as List? ?? [])
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .where((e) => e['media_type'] == 'movie' || e['media_type'] == 'tv')
            .toList()
          ..sort((a, b) => ((b['popularity'] as num?) ?? 0).compareTo((a['popularity'] as num?) ?? 0));
        return CustomScrollView(slivers: [
          SliverToBoxAdapter(child: _ActorHeader(actor: widget.actor, person: person)),
          if (credits.isEmpty)
            const SliverFillRemaining(child: Center(child: Text('Filmography is unavailable right now.')))
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 36),
              sliver: SliverGrid(
                delegate: SliverChildBuilderDelegate((context, index) {
                  final credit = credits[index];
                  final id = credit['id'] as int?;
                  final isTv = credit['media_type'] == 'tv';
                  final title = (credit[isTv ? 'name' : 'title'] as String?) ?? 'Untitled';
                  final date = (credit[isTv ? 'first_air_date' : 'release_date'] as String?) ?? '';
                  final year = date.length >= 4 ? date.substring(0, 4) : null;
                  final poster = credit['poster_path'] as String?;
                  return MultimediaCard(
                    imageUrl: poster == null ? null : '${TmdbConfig.imageBaseUrl}$poster',
                    title: year == null ? title : '$title · $year',
                    heroTag: 'person-${widget.actor.id}-$id',
                    onTap: id == null ? () {} : () => TmdbDetailsRoute(
                      movieId: id,
                      mediaType: isTv ? 'tv' : 'movie',
                      placeholderPoster: poster == null ? null : '${TmdbConfig.imageBaseUrl}$poster',
                      source: 'TMDB',
                    ).push(context),
                  );
                }, childCount: credits.length),
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 190,
                  mainAxisExtent: 300,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 22,
                ),
              ),
            ),
        ]);
      },
    ),
  );
}

class _ActorHeader extends StatelessWidget {
  const _ActorHeader({required this.actor, required this.person});
  final TmdbCast actor;
  final Map<String, dynamic>? person;
  @override
  Widget build(BuildContext context) {
    final image = person?['profile_path'] as String? ?? actor.profilePath;
    final bio = person?['biography'] as String?;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          child: CachedNetworkImage(
            imageUrl: image == null ? '' : '${TmdbConfig.imageBaseUrl}$image', width: 96, height: 120, fit: BoxFit.cover,
            errorWidget: (_, _, _) => SizedBox(width: 96, height: 120, child: ThumbnailErrorPlaceholder(label: actor.name)),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(actor.name, style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 6),
          Text('Filmography', style: Theme.of(context).textTheme.labelLarge),
          if (bio != null && bio.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(bio, maxLines: 4, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.bodyMedium),
          ],
        ])),
      ]),
    );
  }
}
