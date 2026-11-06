import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/profile/profile_service.dart';
import 'profiles_screen.dart';
import 'welcome_screen.dart';

/// Who's watching, or initial setup when there is no profile yet.
///
/// The choice is taken once. Creating the first profile must not swap this
/// route out from under the welcome screen before it navigates home.
class ProfileEntry extends ConsumerStatefulWidget {
  const ProfileEntry({super.key});

  @override
  ConsumerState<ProfileEntry> createState() => _ProfileEntryState();
}

class _ProfileEntryState extends ConsumerState<ProfileEntry> {
  late final bool _needsSetup;

  @override
  void initState() {
    super.initState();
    _needsSetup = ref.read(profileControllerProvider).profiles.isEmpty;
  }

  @override
  Widget build(BuildContext context) {
    if (_needsSetup) return const WelcomeScreen();
    return const ProfilesScreen();
  }
}
