import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skystream/core/domain/entity/multimedia_item.dart';
import 'package:skystream/core/recommendations/discovery_engine.dart';
import 'package:skystream/core/storage/history_repository.dart';

typedef _RouteResponder = dynamic Function(RequestOptions options);

class _FakeDiscoveryAdapter implements HttpClientAdapter {
  _FakeDiscoveryAdapter(this._responder);

  final _RouteResponder _responder;
  final List<String> requestedUrls = <String>[];

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final uri = options.uri.toString();
    requestedUrls.add(uri);
    final payload = _responder(options);
    if (payload == null) {
      return ResponseBody.fromString('{"error":"not found"}', 404, headers: const {
        Headers.contentTypeHeader: <String>['application/json'],
      });
    }
    return ResponseBody.fromString(
      payload is String ? payload : jsonEncode(payload),
      200,
      headers: const {
        Headers.contentTypeHeader: <String>['application/json'],
      },
    );
  }
}

MultimediaItem _item(
  String title, {
  String? imdbId,
  int? tmdbId,
  MultimediaContentType type = MultimediaContentType.movie,
  List<String>? tags,
  String? posterUrl,
}) {
  return MultimediaItem(
    title: title,
    url: 'test://$title',
    posterUrl: posterUrl ?? 'https://img.test/${title.replaceAll(' ', '_')}.jpg',
    contentType: type,
    imdbId: imdbId,
    tmdbId: tmdbId,
    tags: tags,
  );
}

void main() {
  group('TasteProfile', () {
    test('builds ranked genre profile and excludes completed/recent seeds', () {
      final sciFiMovie = _item(
        'Interstellar',
        imdbId: 'tt0816692',
        tags: <String>['Sci-Fi', 'Drama', 'Adventure'],
      );
      final watchedHistory = <HistoryItem>[
        HistoryItem(
          item: sciFiMovie,
          position: 9500,
          duration: 10000, // >= 0.85 completed
          timestamp: 100,
        ),
        HistoryItem(
          item: _item(
            'Dark',
            imdbId: 'tt5753856',
            type: MultimediaContentType.series,
            tags: <String>['Sci-Fi', 'Mystery', 'Thriller'],
          ),
          position: 3000,
          duration: 10000,
          timestamp: 90,
        ),
      ];
      final library = <MultimediaItem>[
        _item(
          'Severance',
          imdbId: 'tt11280740',
          type: MultimediaContentType.series,
          tags: <String>['Mystery', 'Sci-Fi'],
        ),
      ];

      final profile = TasteProfile.build(
        history: watchedHistory,
        library: library,
        now: DateTime(2026, 11, 11),
      );

      expect(profile.topCinemetaGenres.first, 'Sci-Fi');
      expect(profile.topTmdbGenreIds, contains(878)); // Sci-Fi
      expect(profile.excludeKeys, contains('imdb:tt0816692'));
      expect(profile.excludeKeys, contains('imdb:tt11280740'));
      expect(profile.seriesAffinity, greaterThan(0.5));
    });

    test('rotates cold-start genres deterministically across dates', () {
      final day1 = TasteProfile.build(
        history: const <HistoryItem>[],
        library: const <MultimediaItem>[],
        now: DateTime(2026, 1, 1),
      );
      final day2 = TasteProfile.build(
        history: const <HistoryItem>[],
        library: const <MultimediaItem>[],
        now: DateTime(2026, 1, 2),
      );
      expect(day1.topCinemetaGenres.length, 3);
      expect(day1.topCinemetaGenres, isNot(equals(day2.topCinemetaGenres)));
    });
  });

  group('DiscoveryEngine deduplication', () {
    test('deduplicates across shelves and respects Top 10 caps', () {
      final shared = _item('Dune: Part Two', imdbId: 'tt15239678', tmdbId: 693134);
      final uniqueKe = _item('Nairobi Half Life', imdbId: 'tt2234261');
      final watched = _item('Already Seen', imdbId: 'tt9999999');
      final extraPicked = _item('Blade Runner 2049', imdbId: 'tt1856101');

      final shelves = DiscoveryEngine.dedupeAndBalanceShelves(
        <DiscoveryShelf>[
          DiscoveryShelf(
            kind: DiscoveryShelfKind.top10World,
            id: 'top10_world',
            ranked: true,
            items: <MultimediaItem>[
              shared,
              ...List<MultimediaItem>.generate(
                12,
                (i) => _item('World #$i', imdbId: 'tt10000$i'),
              ),
            ],
          ),
          DiscoveryShelf(
            kind: DiscoveryShelfKind.top10Kenya,
            id: 'top10_kenya',
            countryName: 'Kenya',
            ranked: true,
            items: <MultimediaItem>[shared, uniqueKe],
          ),
          DiscoveryShelf(
            kind: DiscoveryShelfKind.pickedForYou,
            id: 'picked',
            items: <MultimediaItem>[shared, watched, extraPicked],
          ),
        ],
        excludeKeys: const <String>{'imdb:tt9999999'},
      );

      final worldShelf = shelves.firstWhere(
        (s) => s.kind == DiscoveryShelfKind.top10World,
      );
      final kenyaShelf = shelves.firstWhere(
        (s) => s.kind == DiscoveryShelfKind.top10Kenya,
      );
      final pickedShelf = shelves.firstWhere(
        (s) => s.kind == DiscoveryShelfKind.pickedForYou,
      );

      expect(worldShelf.items.length, 10);
      expect(kenyaShelf.items.length, 2);
      // Downstream discovery shelves do not echo Top 10 items or watched titles.
      expect(pickedShelf.items.map((e) => e.title), <String>['Blade Runner 2049']);
    });
  });

  group('DiscoveryEngine zero-setup multi-source fusion', () {
    test('works keyless with iTunes regional charts and Cinemeta catalogs', () async {
      final adapter = _FakeDiscoveryAdapter((options) {
        final uri = options.uri.toString();
        if (uri.contains('ipwho.is')) {
          return <String, dynamic>{
            'success': true,
            'country': 'United Kingdom',
            'country_code': 'GB',
          };
        }
        if (uri.contains('itunes.apple.com/ke/rss')) {
          return <String, dynamic>{
            'feed': <String, dynamic>{
              'entry': <Map<String, dynamic>>[
                <String, dynamic>{
                  'im:name': <String, dynamic>{'label': 'Supa Modo (2018)'},
                  'im:image': <Map<String, dynamic>>[
                    <String, dynamic>{
                      'label': 'https://mzstatic.test/170x170bb.jpg',
                    },
                  ],
                  'summary': <String, dynamic>{'label': 'Kenyan drama'},
                  'im:releaseDate': <String, dynamic>{
                    'label': '2018-02-01T00:00:00Z',
                  },
                },
              ],
            },
          };
        }
        if (uri.contains('itunes.apple.com/us/rss')) {
          return <String, dynamic>{
            'feed': <String, dynamic>{
              'entry': <Map<String, dynamic>>[
                <String, dynamic>{
                  'im:name': <String, dynamic>{'label': 'Oppenheimer'},
                  'im:image': <Map<String, dynamic>>[
                    <String, dynamic>{
                      'label': 'https://mzstatic.test/op_170x170bb.jpg',
                    },
                  ],
                },
              ],
            },
          };
        }
        if (uri.contains('itunes.apple.com/gb/rss')) {
          return <String, dynamic>{
            'feed': <String, dynamic>{
              'entry': <Map<String, dynamic>>[
                <String, dynamic>{
                  'im:name': <String, dynamic>{'label': 'Paddington in Peru'},
                  'im:image': <Map<String, dynamic>>[
                    <String, dynamic>{
                      'label': 'https://mzstatic.test/pad_170x170bb.jpg',
                    },
                  ],
                },
              ],
            },
          };
        }
        if (uri.contains('search=Supa')) {
          return <String, dynamic>{
            'metas': <Map<String, dynamic>>[
              <String, dynamic>{
                'id': 'tt7897102',
                'name': 'Supa Modo',
                'type': 'movie',
                'poster': 'https://images.metahub.space/poster/medium/tt7897102/img',
              },
            ],
          };
        }
        if (uri.contains('v3-cinemeta.strem.io/catalog/series/top.json')) {
          return <String, dynamic>{
            'metas': <Map<String, dynamic>>[
              <String, dynamic>{
                'id': 'tt0903747',
                'name': 'Breaking Bad',
                'type': 'series',
                'poster': 'https://img.test/bb.jpg',
              },
            ],
          };
        }
        if (uri.contains('v3-cinemeta.strem.io/catalog/movie/top.json')) {
          return <String, dynamic>{
            'metas': <Map<String, dynamic>>[
              <String, dynamic>{
                'id': 'tt0468569',
                'name': 'The Dark Knight',
                'type': 'movie',
                'poster': 'https://img.test/tdk.jpg',
              },
            ],
          };
        }
        if (uri.contains('v3-cinemeta.strem.io/catalog/movie/imdbRating')) {
          return <String, dynamic>{
            'metas': <Map<String, dynamic>>[
              <String, dynamic>{
                'id': 'tt0133093',
                'name': 'The Matrix',
                'type': 'movie',
                'poster': 'https://img.test/matrix.jpg',
              },
            ],
          };
        }
        return <String, dynamic>{'metas': <dynamic>[]};
      });

      final dio = Dio()..httpClientAdapter = adapter;
      final engine = DiscoveryEngine(
        dio: dio,
        tmdbApiKey: '',
        traktClientId: '',
        now: () => DateTime(2026, 11, 11),
      );

      final shelves = await engine.buildHomeDiscoveryShelves(
        history: const <HistoryItem>[],
        library: const <MultimediaItem>[],
      );

      expect(
        shelves.any((s) => s.kind == DiscoveryShelfKind.top10World),
        isTrue,
      );
      final kenyaShelf = shelves.firstWhere(
        (s) => s.kind == DiscoveryShelfKind.top10Kenya,
      );
      expect(kenyaShelf.ranked, isTrue);
      expect(kenyaShelf.items.first.title, 'Supa Modo');
      expect(kenyaShelf.items.first.imdbId, 'tt7897102');

      final localShelf = shelves.firstWhere(
        (s) => s.kind == DiscoveryShelfKind.top10Local,
      );
      expect(localShelf.countryName, 'United Kingdom');
      expect(localShelf.items.first.title, 'Paddington in Peru');
    });

    test('fuses TMDB and Trakt endpoints seamlessly when build keys exist', () async {
      final adapter = _FakeDiscoveryAdapter((options) {
        final uri = options.uri.toString();
        if (uri.contains('ipwho.is')) {
          return <String, dynamic>{
            'success': true,
            'country': 'Kenya',
            'country_code': 'KE',
          };
        }
        if (uri.contains('api.trakt.tv/movies/trending')) {
          return <Map<String, dynamic>>[
            <String, dynamic>{
              'watchers': 4200,
              'movie': <String, dynamic>{
                'title': 'Sinners',
                'year': 2025,
                'ids': <String, dynamic>{'imdb': 'tt31193180', 'tmdb': 1233413},
              },
            },
          ];
        }
        if (uri.contains('api.trakt.tv/movies/12345') ||
            uri.contains('/related')) {
          return <Map<String, dynamic>>[
            <String, dynamic>{
              'title': 'Arrival',
              'year': 2016,
              'ids': <String, dynamic>{'imdb': 'tt2543164', 'tmdb': 329865},
            },
          ];
        }
        if (uri.contains('watch_region=KE')) {
          return <String, dynamic>{
            'results': <Map<String, dynamic>>[
              <String, dynamic>{
                'id': 55001,
                'title': 'Rafiki',
                'poster_path': '/rafiki.jpg',
                'vote_average': 7.4,
              },
            ],
          };
        }
        if (uri.contains('with_origin_country=KE')) {
          return <String, dynamic>{
            'results': <Map<String, dynamic>>[
              <String, dynamic>{
                'id': 55002,
                'title': 'Disconnect',
                'poster_path': '/disconnect.jpg',
                'vote_average': 7.1,
              },
            ],
          };
        }
        if (uri.contains('/trending/all/day')) {
          return <String, dynamic>{
            'results': <Map<String, dynamic>>[
              <String, dynamic>{
                'id': 693134,
                'title': 'Dune: Part Two',
                'media_type': 'movie',
                'poster_path': '/dune2.jpg',
                'vote_average': 8.3,
              },
            ],
          };
        }
        if (uri.contains('themoviedb.org/3/movie/101/recommendations')) {
          return <String, dynamic>{
            'results': <Map<String, dynamic>>[
              <String, dynamic>{
                'id': 202,
                'title': 'Ex Machina',
                'poster_path': '/exmachina.jpg',
              },
            ],
          };
        }
        return <String, dynamic>{'results': <dynamic>[], 'metas': <dynamic>[]};
      });

      final dio = Dio()..httpClientAdapter = adapter;
      final engine = DiscoveryEngine(
        dio: dio,
        tmdbApiKey: 'test_tmdb_key',
        traktClientId: 'test_trakt_id',
        now: () => DateTime(2026, 11, 11),
      );

      final shelves = await engine.buildHomeDiscoveryShelves(
        history: <HistoryItem>[
          HistoryItem(
            item: _item('Inception', imdbId: 'tt1375666', tmdbId: 27205),
            position: 5000,
            duration: 10000,
            timestamp: 1,
          ),
        ],
        library: const <MultimediaItem>[],
      );

      // Should NOT add redundant top10Local when country IS already Kenya.
      expect(
        shelves.any((s) => s.kind == DiscoveryShelfKind.top10Local),
        isFalse,
      );
      expect(
        shelves.any((s) => s.kind == DiscoveryShelfKind.top10Kenya),
        isTrue,
      );
      expect(
        shelves.any((s) => s.kind == DiscoveryShelfKind.africanSpotlight),
        isTrue,
      );

      final africanShelf = shelves.firstWhere(
        (s) => s.kind == DiscoveryShelfKind.africanSpotlight,
      );
      expect(africanShelf.items.map((e) => e.title), contains('Disconnect'));

      final similar = await engine.getSimilarItems(
        _item('Blade Runner 2049', imdbId: 'tt1856101', tmdbId: 101),
      );
      expect(
        similar.map((e) => e.title),
        containsAll(<String>['Ex Machina', 'Arrival']),
      );
    });
  });
}
