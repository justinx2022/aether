import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:aether/core/domain/entity/multimedia_item.dart';
import 'package:aether/core/extensions/aether_native_provider.dart';

void main() {
  group('AetherNativeProvider Tests', () {
    test('Default configuration matches pure Aether first-party specifications', () {
      final provider = AetherNativeProvider();
      expect(provider.packageName, 'org.aether.native');
      expect(provider.name, 'Aether Native');
      expect(provider.version, '1.0.0');
      expect(provider.hasSearch, isTrue);
      expect(provider.isDebug, isFalse);
    });

    test('getDetails correctly parses URL and title', () async {
      final provider = AetherNativeProvider();
      final movie = await provider.getDetails('https://aether.stream/watch/oppenheimer-2023');
      expect(movie.title, 'oppenheimer 2023');
      expect(movie.contentType, MultimediaContentType.movie);

      final series = await provider.getDetails('https://aether.stream/watch/series/breaking-bad');
      expect(series.title, 'breaking bad');
      expect(series.contentType, MultimediaContentType.series);
    });

    test('loadStreams resolves high-speed streams from title or token', () async {
      final provider = AetherNativeProvider();

      // Test with plain URL
      final streams = await provider.loadStreams('https://aether.stream/watch/inception-2010');
      expect(streams, isNotEmpty);
      expect(streams.any((s) => s.source == '1080p' || s.source == 'Auto'), isTrue);

      // Test with structured JSON token
      final token = jsonEncode({
        'title': 'Dune Part Two',
        'type': 'movie',
        'year': 2024,
        'imdbId': 'tt15239678',
        'tmdbId': 693134,
      });
      final jsonStreams = await provider.loadStreams(token);
      expect(jsonStreams, isNotEmpty);
      expect(jsonStreams.any((s) => s.url.contains('Dune+Part+Two') || s.url.contains('Dune')), isTrue);
    });
  });
}
