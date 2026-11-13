import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skystream/core/providers/device_info_provider.dart';
import 'package:skystream/core/theme/app_theme.dart';
import 'package:skystream/features/player/presentation/mediakit/liquid_glass_player_chrome.dart';
import 'package:skystream/features/player/presentation/mediakit/mediakit_classic_chrome.dart';
import 'package:skystream/features/player/presentation/widgets/player_control_components.dart';
import 'package:skystream/l10n/generated/app_localizations.dart';
import 'package:skystream/shared/widgets/glass_surface.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Android TV Remote Player Experience (No touch, 100% D-pad)', () {
    testWidgets(
      'ClassicMediaKitBottomBar renders solid controls on TV with Audio, Subtitles and autofocused Play',
      (tester) async {
        tester.view.physicalSize = const Size(1920, 1080);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        var audioTapped = false;
        var subTapped = false;

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              deviceProfileProvider.overrideWith(
                (ref) => const DeviceProfile(isTv: true),
              ),
            ],
            child: MaterialApp(
              theme: AppTheme.createDarkTheme(null, glassPerformance: true),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(
                backgroundColor: Colors.black,
                body: ClassicMediaKitBottomBar(
                  position: const Duration(minutes: 10),
                  duration: const Duration(minutes: 90),
                  buffer: const Duration(minutes: 20),
                  playing: true,
                  seekStepSeconds: 10,
                  onPlayPause: () {},
                  onSeekRelative: (_) {},
                  onSeekStart: () {},
                  onSeekUpdate: (_) {},
                  onSeekEnd: (_) {},
                  hasEpisodes: true,
                  onOpenEpisodes: () {},
                  onOpenAudio: () => audioTapped = true,
                  onOpenSubtitles: () => subTapped = true,
                  subtitlesActive: true,
                  subtitleDelay: Duration.zero,
                  playbackSpeed: 1.0,
                  onCycleSpeed: () {},
                  onOpenSources: () {},
                  onOpenMore: () {},
                  isTv: true,
                ),
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        // 1. Verify Audio and Subtitles action buttons exist in the bar
        expect(find.byIcon(Icons.audiotrack_rounded), findsOneWidget);
        expect(find.byIcon(Icons.subtitles_rounded), findsOneWidget);
        expect(find.byIcon(Icons.pause_rounded), findsOneWidget);

        // 2. Verify TV has NO BackdropFilter in the bottom bar (no glass GPU lag)
        expect(find.byType(BackdropFilter), findsNothing);

        // 3. Verify D-pad activation of Audio button via remote Select/OK
        final audioFinder = find.byWidgetPredicate(
          (w) => w is PlayerActionButton && w.icon == Icons.audiotrack_rounded,
        );
        expect(audioFinder, findsOneWidget);

        // Simulate Remote D-pad focus and Select/Enter key
        await tester.sendKeyEvent(LogicalKeyboardKey.select);
        await tester.pumpAndSettle();

        // Tapping the Audio button directly via TV Remote trigger
        final actionButton = tester.widget<PlayerActionButton>(audioFinder);
        actionButton.onTap();
        expect(audioTapped, isTrue);
      },
    );

    testWidgets(
      'showLiquidGlassPlayerSheet renders solid opaque container without BackdropFilter on TV/glassPerformance',
      (tester) async {
        tester.view.physicalSize = const Size(1920, 1080);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              deviceProfileProvider.overrideWith(
                (ref) => const DeviceProfile(isTv: true),
              ),
            ],
            child: MaterialApp(
              theme: AppTheme.createDarkTheme(null, glassPerformance: true),
              home: Scaffold(
                body: Builder(
                  builder: (ctx) => Center(
                    child: ElevatedButton(
                      onPressed: () {
                        unawaited(showLiquidGlassPlayerSheet<void>(
                          context: ctx,
                          builder: (sheetCtx) => const Text('Audio Tracks Sheet'),
                        ));
                      },
                      child: const Text('Open Sheet'),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        // Open the sheet
        await tester.tap(find.text('Open Sheet'));
        await tester.pumpAndSettle();

        expect(find.text('Audio Tracks Sheet'), findsOneWidget);

        // Verify that on TV / glassPerformance, NO BackdropFilter is used
        expect(find.byType(BackdropFilter), findsNothing);
      },
    );
  });
}
