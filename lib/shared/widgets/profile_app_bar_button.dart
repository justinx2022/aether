import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/profile/profile_service.dart';
import '../../core/profile/user_profile.dart';
import '../../features/profile/presentation/profiles_screen.dart';

class ProfileAppBarButton extends ConsumerWidget {
  const ProfileAppBarButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileState = ref.watch(profileControllerProvider);
    final active = profileState.activeProfile;

    final avatar = active != null
        ? ProfileAvatars.get(active.avatarId)
        : ProfileAvatars.all.first;

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute<void>(
            builder: (_) => const ProfilesScreen(isSwitching: true),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.15),
            width: 1.0,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: avatar.gradientColors),
                shape: BoxShape.circle,
              ),
              child: Icon(avatar.icon, color: Colors.white, size: 14),
            ),
            const SizedBox(width: 8),
            Text(
              active?.name ?? 'Profile',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
            const SizedBox(width: 4),
          ],
        ),
      ),
    );
  }
}
