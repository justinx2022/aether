import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/monetization/pass_service.dart';
import '../../core/profile/profile_service.dart';
import '../../core/profile/user_profile.dart';
import '../../features/profile/presentation/auth_sheet.dart';

class ProfileAppBarButton extends ConsumerWidget {
  const ProfileAppBarButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileState = ref.watch(profileControllerProvider);
    final passState = ref.watch(passControllerProvider);
    final active = profileState.activeProfile;

    final avatar = active != null
        ? ProfileAvatars.get(active.avatarId)
        : ProfileAvatars.all.first;

    return GestureDetector(
      onTap: () => AuthSheet.show(context),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.06),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: passState.isVip ? const Color(0xFF6366F1).withOpacity(0.5) : Colors.white12,
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: avatar.gradientColors),
                shape: BoxShape.circle,
              ),
              child: Icon(avatar.icon, color: Colors.white, size: 16),
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
            if (passState.isVip) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'VIP',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
            const SizedBox(width: 4),
          ],
        ),
      ),
    );
  }
}
