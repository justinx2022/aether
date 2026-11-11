import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skystream/core/theme/app_backdrop_layer.dart';
import 'package:skystream/core/theme/app_theme.dart';
import 'package:skystream/features/player/presentation/mediakit/liquid_glass_player_chrome.dart';
import 'package:skystream/shared/widgets/glass_surface.dart';

void main() {
  Widget hostPlatform(TargetPlatform platform, Widget child) {
    return MaterialApp(
      key: ValueKey(platform),
      theme: AppTheme.createDarkTheme(null).copyWith(platform: platform),
      home: Scaffold(body: Center(child: child)),
    );
  }

  group('Windows Skia/ANGLE smoothness guards', () {
    testWidgets(
      'AppBackdropLayer isolates backdrop painting and disables shell BackdropFilter on Windows',
      (tester) async {
        await tester.pumpWidget(
          hostPlatform(
            TargetPlatform.windows,
            const AppBackdropLayer(
              child: GlassSurface(
                blurSigma: 14,
                child: Text('windows-shell'),
              ),
            ),
          ),
        );

        expect(find.text('windows-shell'), findsOneWidget);
        // Shell blur must be skipped on Windows so Skia/ANGLE never stalls on
        // D3D11 offscreen saveLayers.
        expect(find.byType(BackdropFilter), findsNothing);
        // Specular rim catchlight must remain intact for the Liquid Glass look.
        expect(
          find.byWidgetPredicate(
            (w) => w is CustomPaint && w.painter is LiquidGlassRimPainter,
          ),
          findsOneWidget,
        );
        // Background painter is isolated in its own RepaintBoundary separate
        // from the scrolling/animating child tree.
        expect(
          find.descendant(
            of: find.byType(AppBackdropLayer),
            matching: find.byType(RepaintBoundary),
          ),
          findsNWidgets(2),
        );
      },
    );

    testWidgets(
      'AppBackdropLayer preserves BackdropFilter blur on Android',
      (tester) async {
        await tester.pumpWidget(
          hostPlatform(
            TargetPlatform.android,
            const AppBackdropLayer(
              child: GlassSurface(
                blurSigma: 14,
                child: Text('android-shell'),
              ),
            ),
          ),
        );

        expect(find.text('android-shell'), findsOneWidget);
        expect(find.byType(BackdropFilter), findsOneWidget);
      },
    );

    testWidgets(
      'LiquidPlayerCapsule omits BackdropFilter on Windows and preserves it on Android',
      (tester) async {
        await tester.pumpWidget(
          hostPlatform(
            TargetPlatform.windows,
            const LiquidPlayerCapsule(child: Text('hud-pill')),
          ),
        );
        expect(find.text('hud-pill'), findsOneWidget);
        expect(find.byType(BackdropFilter), findsNothing);

        await tester.pumpWidget(
          hostPlatform(
            TargetPlatform.android,
            const LiquidPlayerCapsule(child: Text('hud-pill-android')),
          ),
        );
        expect(find.text('hud-pill-android'), findsOneWidget);
        expect(find.byType(BackdropFilter), findsOneWidget);
      },
    );
  });
}
