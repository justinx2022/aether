import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skystream/core/theme/app_theme.dart';
import 'package:skystream/features/player/presentation/mediakit/liquid_glass_player_chrome.dart';
import 'package:skystream/features/player/presentation/mediakit/mediakit_classic_chrome.dart';
import 'package:skystream/features/player/presentation/mediakit/mediakit_diagnostics_overlay.dart';
import 'package:skystream/features/player/presentation/mediakit/mediakit_more_sheet.dart';
import 'package:skystream/features/player/presentation/widgets/player_control_components.dart';
import 'package:skystream/features/player/presentation/widgets/player_stream_widgets.dart';
import 'package:skystream/l10n/generated/app_localizations.dart';

Widget _wrapApp(
  Widget child, {
  TargetPlatform platform = TargetPlatform.windows,
}) {
  return ProviderScope(
    child: MaterialApp(
      theme: AppTheme.createDarkTheme(null).copyWith(platform: platform),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: child),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('MediaKit Liquid Glass smoothness isolation', () {
    testWidgets(
      '1.A: position & buffer notifiers update clock/bar without rebuilding dock',
      (tester) async {
        final posNotifier = ValueNotifier<Duration>(const Duration(minutes: 1));
        final bufNotifier = ValueNotifier<Duration>(const Duration(minutes: 2));
        addTearDown(posNotifier.dispose);
        addTearDown(bufNotifier.dispose);

        int outerBuilds = 0;
        await tester.pumpWidget(
          _wrapApp(
            Builder(
              builder: (context) {
                outerBuilds++;
                return Align(
                  alignment: Alignment.bottomCenter,
                  child: LiquidGlassBottomDock(
                    position: Duration.zero,
                    duration: const Duration(minutes: 10),
                    buffer: Duration.zero,
                    positionListenable: posNotifier,
                    bufferListenable: bufNotifier,
                    showRemainingTime: false,
                    onToggleRemainingTime: () {},
                    onSeekStart: () {},
                    onSeekUpdate: (_) {},
                    onSeekEnd: (_) {},
                    hasEpisodes: true,
                    onOpenEpisodes: () {},
                    onOpenAudio: () {},
                    onOpenSubtitles: () {},
                    subtitlesActive: false,
                    subtitleDelay: Duration.zero,
                    playbackSpeed: 1.0,
                    onCycleSpeed: () {},
                    onOpenSources: () {},
                    onOpenMore: () {},
                  ),
                );
              },
            ),
          ),
        );

        expect(outerBuilds, 1);
        expect(find.text('01:00 / 10:00'), findsOneWidget);

        posNotifier.value = const Duration(minutes: 2, seconds: 15);
        await tester.pump();
        expect(find.text('02:15 / 10:00'), findsOneWidget);
        expect(outerBuilds, 1);

        bufNotifier.value = const Duration(minutes: 5);
        await tester.pump();
        final bufferedBox = tester
            .widgetList<FractionallySizedBox>(
              find.byType(FractionallySizedBox),
            )
            .firstWhere((w) => w.widthFactor == 0.5);
        expect(bufferedBox.widthFactor, 0.5);
        expect(outerBuilds, 1);
      },
    );

    testWidgets(
      '1.B & Windows zero-blur: center transport & independent chrome bars skip BackdropFilter',
      (tester) async {
        tester.view.physicalSize = const Size(1920, 1080);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(
          _wrapApp(
            Stack(
              fit: StackFit.expand,
              children: <Widget>[
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: AnimatedOpacity(
                    opacity: 1,
                    duration: const Duration(milliseconds: 200),
                    child: LiquidGlassTopHud(
                      title: 'Example',
                      onBack: () {},
                      nightAudioEnabled: false,
                      showPipButton: false,
                      onEnterPip: () {},
                      sleepTimerMinutes: null,
                      onOpenSleepTimer: () {},
                      isLocked: false,
                      onLockScreen: () {},
                    ),
                  ),
                ),
                Center(
                  child: AnimatedOpacity(
                    opacity: 1,
                    duration: const Duration(milliseconds: 200),
                    child: LiquidGlassCenterTransport(
                      isPlaying: true,
                      isBuffering: false,
                      seekStepSeconds: 10,
                      onPlayPause: () {},
                      onSeekBackward: () {},
                      onSeekForward: () {},
                    ),
                  ),
                ),
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: AnimatedOpacity(
                    opacity: 1,
                    duration: const Duration(milliseconds: 200),
                    child: LiquidGlassBottomDock(
                      position: const Duration(seconds: 30),
                      duration: const Duration(minutes: 10),
                      buffer: const Duration(minutes: 1),
                      showRemainingTime: false,
                      onToggleRemainingTime: () {},
                      onSeekStart: () {},
                      onSeekUpdate: (_) {},
                      onSeekEnd: (_) {},
                      hasEpisodes: false,
                      onOpenEpisodes: () {},
                      onOpenAudio: () {},
                      onOpenSubtitles: () {},
                      subtitlesActive: false,
                      subtitleDelay: Duration.zero,
                      playbackSpeed: 1.0,
                      onCycleSpeed: () {},
                      onOpenSources: () {},
                      onOpenMore: () {},
                    ),
                  ),
                ),
              ],
            ),
            platform: TargetPlatform.windows,
          ),
        );
        await tester.pump();

        expect(find.byType(BackdropFilter), findsNothing);
        final opacityLayers = tester
            .renderObjectList<RenderAnimatedOpacity>(
              find.byType(AnimatedOpacity),
            )
            .toList();
        expect(opacityLayers.length, 3);
        const viewportArea = 1920 * 1080;
        for (final layer in opacityLayers) {
          final area = layer.paintBounds.width * layer.paintBounds.height;
          expect(area / viewportArea, lessThan(0.25));
        }
      },
    );

    testWidgets(
      '#5: Diagnostics overlay updates cleanly & More sheet toggles HUD + video-sync',
      (tester) async {
        final snapshot = ValueNotifier<PlayerDiagnosticsSnapshot>(
          const PlayerDiagnosticsSnapshot(
            uiFps: 59.8,
            buildMs: 1.4,
            rasterMs: 2.1,
            totalMs: 3.5,
            videoSync: 'audio',
            hwdec: 'd3d11va',
            displayFps: '60.00',
            containerFps: '23.98',
            displaySyncActive: 'no',
            frameDrops: '0',
            decoderDrops: '0',
            voDelayed: '0',
            avSync: '0.001',
          ),
        );
        addTearDown(snapshot.dispose);

        bool closed = false;
        bool syncToggled = false;

        await tester.pumpWidget(
          _wrapApp(
            MediaKitDiagnosticsOverlay(
              snapshot: snapshot,
              onClose: () => closed = true,
              onToggleVideoSync: () => syncToggled = true,
            ),
          ),
        );
        await tester.pump();

        expect(find.textContaining('UI FPS: 59.8'), findsOneWidget);
        expect(find.text('audio'), findsOneWidget);
        expect(find.byType(BackdropFilter), findsNothing);

        snapshot.value = snapshot.value.copyWith(videoSync: 'display-resample');
        await tester.pump();
        expect(find.text('display-resample'), findsOneWidget);

        await tester.tap(find.text('display-resample'));
        await tester.tap(find.byIcon(Icons.close_rounded));
        expect(syncToggled, isTrue);
        expect(closed, isTrue);
      },
    );

    testWidgets('#5: More sheet toggles Performance HUD & MPV video-sync', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      bool diagOn = false;
      String syncMode = 'audio';
      await tester.pumpWidget(
        _wrapApp(
          MediaKitMoreSheet(
            speed: 1.0,
            fit: BoxFit.contain,
            isFullscreen: false,
            quality: '1080p',
            isTv: false,
            isLive: false,
            onSpeed: (_) {},
            onFit: (_) {},
            onFullscreen: () {},
            onSources: () {},
            showDiagnostics: diagOn,
            onToggleDiagnostics: (v) => diagOn = v,
            mpvVideoSync: syncMode,
            onToggleMpvVideoSync: () {
              syncMode = syncMode == 'display-resample'
                  ? 'audio'
                  : 'display-resample';
            },
          ),
        ),
      );
      await tester.pump();

      await tester.scrollUntilVisible(
        find.text('MPV Video Sync'),
        100,
        scrollable: find.byType(Scrollable),
      );
      await tester.ensureVisible(find.text('MPV Video Sync'));
      await tester.pump();
      await tester.tap(find.text('MPV Video Sync'));
      await tester.pump();

      await tester.scrollUntilVisible(
        find.text('Performance & MPV HUD'),
        100,
        scrollable: find.byType(Scrollable),
      );
      await tester.ensureVisible(find.text('Performance & MPV HUD'));
      await tester.pump();
      await tester.tap(find.text('Performance & MPV HUD'));
      await tester.pump();

      expect(syncMode, 'display-resample');
      expect(diagOn, isTrue);
    });

    testWidgets(
      'HUD auto-hide: fading bars animate to 0.0 opacity and ignore pointers when hidden',
      (tester) async {
        final visible = ValueNotifier<bool>(true);
        addTearDown(visible.dispose);

        await tester.pumpWidget(
          _wrapApp(
            ValueListenableBuilder<bool>(
              valueListenable: visible,
              builder: (context, show, _) => Stack(
                children: [
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: IgnorePointer(
                      ignoring: !show,
                      child: AnimatedOpacity(
                        opacity: show ? 1.0 : 0.0,
                        duration: const Duration(milliseconds: 200),
                        curve: Curves.easeOutCubic,
                        child: LiquidGlassTopHud(
                          title: 'HUD Fade Test',
                          onBack: () {},
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );

        await tester.pump();
        final opacityFinder = find.byType(AnimatedOpacity);
        expect(
          tester
              .renderObject<RenderAnimatedOpacity>(opacityFinder)
              .opacity
              .value,
          1.0,
        );

        visible.value = false;
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 250));

        expect(
          tester
              .renderObject<RenderAnimatedOpacity>(opacityFinder)
              .opacity
              .value,
          0.0,
        );
        final ignorePointer = tester.widget<IgnorePointer>(
          find
              .ancestor(
                of: opacityFinder,
                matching: find.byType(IgnorePointer),
              )
              .first,
        );
        expect(ignorePointer.ignoring, isTrue);
      },
    );

    testWidgets(
      'Classic UI: renders PlayerTopBar & PlayerBottomBar and isolates position ticks',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 720);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        final posNotifier = ValueNotifier<Duration>(const Duration(minutes: 1));
        final bufNotifier = ValueNotifier<Duration>(const Duration(minutes: 3));
        addTearDown(posNotifier.dispose);
        addTearDown(bufNotifier.dispose);

        int outerBuilds = 0;
        await tester.pumpWidget(
          _wrapApp(
            Builder(
              builder: (context) {
                outerBuilds++;
                return Stack(
                  fit: StackFit.expand,
                  children: [
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      child: ClassicMediaKitTopBar(
                        title: 'Classic Sample Movie',
                        subtitleTag: 'S1 E1',
                        onBack: () {},
                      ),
                    ),
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: ClassicMediaKitBottomBar(
                        position: Duration.zero,
                        duration: const Duration(minutes: 10),
                        buffer: Duration.zero,
                        positionListenable: posNotifier,
                        bufferListenable: bufNotifier,
                        playing: true,
                        seekStepSeconds: 10,
                        onPlayPause: () {},
                        onSeekRelative: (_) {},
                        onSeekStart: () {},
                        onSeekUpdate: (_) {},
                        onSeekEnd: (_) {},
                        hasEpisodes: true,
                        onOpenEpisodes: () {},
                        onOpenAudio: () {},
                        onOpenSubtitles: () {},
                        subtitlesActive: false,
                        subtitleDelay: Duration.zero,
                        playbackSpeed: 1.0,
                        onCycleSpeed: () {},
                        onOpenSources: () {},
                        onOpenMore: () {},
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        );

        expect(outerBuilds, 1);
        expect(find.byType(PlayerTopBar), findsOneWidget);
        expect(find.byType(PlayerBottomBar), findsOneWidget);
        expect(find.byType(PlayerScrubber), findsOneWidget);
        expect(find.byType(PlayerTimeLabel), findsOneWidget);
        expect(find.byType(BackdropFilter), findsNothing);
        expect(find.text('1:00 / 10:00'), findsOneWidget);

        posNotifier.value = const Duration(minutes: 2, seconds: 15);
        await tester.pump();
        expect(find.text('2:15 / 10:00'), findsOneWidget);
        expect(outerBuilds, 1);
      },
    );

    testWidgets('More sheet toggles Player Controls Style (Classic vs Liquid Glass)', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      bool classicUi = false;
      await tester.pumpWidget(
        _wrapApp(
          MediaKitMoreSheet(
            speed: 1.0,
            fit: BoxFit.contain,
            isFullscreen: false,
            quality: '1080p',
            isTv: false,
            isLive: false,
            onSpeed: (_) {},
            onFit: (_) {},
            onFullscreen: () {},
            onSources: () {},
            useClassicUi: classicUi,
            onToggleClassicUi: (v) => classicUi = v,
          ),
        ),
      );
      await tester.pump();

      await tester.scrollUntilVisible(
        find.text('Player Controls Style'),
        100,
        scrollable: find.byType(Scrollable),
      );
      await tester.ensureVisible(find.text('Player Controls Style'));
      await tester.pump();
      expect(find.text('Liquid Glass'), findsOneWidget);

      await tester.tap(find.text('Player Controls Style'));
      await tester.pump();

      expect(classicUi, isTrue);
      expect(find.text('Classic'), findsOneWidget);
    });
  });
}
