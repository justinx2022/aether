// A compile-only smoke test.
//
// `flutter analyze` runs out of memory on this project in CI-sized sandboxes,
// and `flutter test` only compiles what the tests import — so a UI file with a
// missing import (a type that lives in a sibling file, say) compiled fine
// locally and only failed 15 minutes later in the Android build. Importing the
// screens here makes the test runner compile them, turning that class of
// mistake into an instant local failure.
import 'package:flutter_test/flutter_test.dart';

// Entry point: pulls in routing, shell, settings and everything they touch.
import 'package:aether/main.dart' as app;

// Core screens and widgets
import 'package:aether/features/details/presentation/details_screen.dart';
import 'package:aether/features/details/presentation/tmdb_movie_details_screen.dart';
import 'package:aether/features/details/presentation/widgets/movie_seasons_list.dart';
import 'package:aether/features/extensions/screens/extensions_screen.dart';
import 'package:aether/features/player/presentation/vlc/vlc_player_screen.dart';
import 'package:aether/features/player/presentation/mediakit/mediakit_player_screen.dart';
import 'package:aether/features/home/presentation/widgets/continue_watching_card.dart';
import 'package:aether/features/home/presentation/widgets/continue_watching_section.dart';
import 'package:aether/features/explore/presentation/widgets/hover_border_gradient.dart';

void main() {
  test('every active screen and unified widget still compiles', () {
    expect(app.main, isNotNull);
    expect(DetailsScreen, isNotNull);
    expect(TmdbMovieDetailsScreen, isNotNull);
    expect(MovieSeasonsList, isNotNull);
    expect(ExtensionsScreen, isNotNull);
    expect(VlcPlayerScreen, isNotNull);
    expect(MediaKitPlayerScreen, isNotNull);
    expect(ContinueWatchingCard, isNotNull);
    expect(ContinueWatchingSection, isNotNull);
    expect(HoverBorderGradient, isNotNull);
  });
}
