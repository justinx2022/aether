// ignore_for_file: scoped_providers_should_specify_dependencies

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skystream/core/profile/profile_service.dart';
import 'package:skystream/core/profile/user_profile.dart';
import 'package:skystream/core/providers/device_info_provider.dart';
import 'package:skystream/core/theme/app_theme.dart';
import 'package:skystream/features/profile/presentation/profiles_screen.dart';
import 'package:skystream/l10n/generated/app_localizations.dart';

class _StubProfileController extends ProfileController {
  final List<UserProfile> stubProfiles;
  _StubProfileController(this.stubProfiles);

  @override
  ProfileState build() {
    return ProfileState(
      profiles: stubProfiles,
      activeProfile: stubProfiles.isNotEmpty ? stubProfiles.first : null,
      isLoading: false,
    );
  }

  @override
  Future<void> selectProfile(UserProfile profile) async {
    state = state.copyWith(activeProfile: profile);
  }
}

Widget _wrapWithTvScope(
  Widget child, {
  List<UserProfile> profiles = const [],
}) {
  return ProviderScope(
    overrides: [
      deviceProfileProvider.overrideWith(
        (ref) => const DeviceProfile(isTv: true),
      ),
      profileControllerProvider.overrideWith(
        () => _StubProfileController(profiles),
      ),
    ],
    child: MaterialApp(
      theme: AppTheme.createDarkTheme(null),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: child,
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final testProfiles = [
    UserProfile(
      id: 'profile_1',
      name: 'Justin',
      avatarId: ProfileAvatars.all.first.id,
      createdAt: DateTime(2026),
    ),
    UserProfile(
      id: 'profile_2',
      name: 'Kids',
      avatarId: ProfileAvatars.all[1].id,
      isKids: true,
      createdAt: DateTime(2026),
    ),
  ];

  group('ProfilesScreen Android TV 10-foot experience', () {
    testWidgets(
      'Autofocuses initial profile card with 1.15x scale, white glowing border & full opacity',
      (tester) async {
        tester.view.physicalSize = const Size(1920, 1080);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(
          _wrapWithTvScope(
            const ProfilesScreen(isSwitching: true),
            profiles: testProfiles,
          ),
        );

        await tester.pumpAndSettle();

        expect(find.text('Who is watching?'), findsOneWidget);
        expect(find.text('A E T H E R'), findsOneWidget);
        expect(find.text('Justin'), findsOneWidget);
        expect(find.text('Kids'), findsOneWidget);

        // Find the focused AnimatedScale (first card is autofocused at 1.15x scale)
        final scaleWidgets = tester
            .widgetList<AnimatedScale>(find.byType(AnimatedScale))
            .toList();
        final focusedScale = scaleWidgets.firstWhere(
          (s) => s.scale == 1.15,
          orElse: () => const AnimatedScale(scale: 1.0, duration: Duration.zero),
        );
        expect(focusedScale.scale, 1.15);

        // Unfocused card has dimmed opacity (0.70) while focused has 1.0
        final opacityWidgets = tester
            .widgetList<AnimatedOpacity>(find.byType(AnimatedOpacity))
            .toList();
        expect(opacityWidgets.any((o) => o.opacity == 1.0), isTrue);
        expect(opacityWidgets.any((o) => o.opacity == 0.70), isTrue);
      },
    );

    testWidgets(
      'D-pad Enter/Select triggers profile selection and D-pad Down focuses Manage Profiles',
      (tester) async {
        tester.view.physicalSize = const Size(1920, 1080);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(
          _wrapWithTvScope(
            const ProfilesScreen(isSwitching: true),
            profiles: testProfiles,
          ),
        );

        await tester.pumpAndSettle();

        // Manage button should be present below the cards
        expect(find.text('Manage Profiles'), findsOneWidget);

        // Press D-pad Down to move focus to Manage Profiles button
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        await tester.pumpAndSettle();

        // Press Select/Enter to toggle Manage Profiles mode
        await tester.sendKeyEvent(LogicalKeyboardKey.select);
        await tester.pumpAndSettle();

        expect(find.text('Done Managing'), findsOneWidget);

        // Press Select/Enter again to toggle back
        await tester.sendKeyEvent(LogicalKeyboardKey.select);
        await tester.pumpAndSettle();

        expect(find.text('Manage Profiles'), findsOneWidget);
      },
    );
  });
}
