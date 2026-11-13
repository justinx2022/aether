import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/profile/user_profile.dart';
import '../../../core/profile/profile_service.dart';
import '../../../core/providers/device_info_provider.dart';
import '../../../core/theme/app_backdrop_layer.dart';
import '../../../shared/widgets/tv_logical_scale.dart';

class ProfilesScreen extends ConsumerStatefulWidget {
  final bool isSwitching;

  const ProfilesScreen({super.key, this.isSwitching = false});

  @override
  ConsumerState<ProfilesScreen> createState() => _ProfilesScreenState();
}

class _ProfilesScreenState extends ConsumerState<ProfilesScreen> {
  bool _isManaging = false;

  void _selectProfile(UserProfile profile) {
    if (_isManaging) {
      _showEditProfileDialog(profile);
      return;
    }

    if (profile.pin != null && profile.pin!.isNotEmpty) {
      _showPinDialog(profile);
      return;
    }

    ref.read(profileControllerProvider.notifier).selectProfile(profile);
    if (widget.isSwitching && context.canPop()) {
      context.pop();
    } else {
      context.go('/home');
    }
  }

  void _showPinDialog(UserProfile profile) {
    final controller = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0F121C),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: Color(0xFF1E2638), width: 1),
        ),
        title: Text(
          'Enter PIN for ${profile.name}',
          style: const TextStyle(color: Colors.white, fontSize: 18),
        ),
        content: TextField(
          controller: controller,
          obscureText: true,
          keyboardType: TextInputType.number,
          maxLength: 4,
          autofocus: true,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) {
            if (controller.text == profile.pin) {
              Navigator.pop(ctx);
              ref
                  .read(profileControllerProvider.notifier)
                  .selectProfile(profile);
              if (widget.isSwitching && context.canPop()) {
                context.pop();
              } else {
                context.go('/home');
              }
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Incorrect PIN. Try again.')),
              );
            }
          },
          style: const TextStyle(
            color: Colors.white,
            letterSpacing: 8,
            fontSize: 20,
          ),
          decoration: InputDecoration(
            counterText: '',
            hintText: '••••',
            hintStyle: const TextStyle(color: Colors.white30),
            filled: true,
            fillColor: Colors.white.withValues(alpha: 0.05),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Colors.white60)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6366F1),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () {
              if (controller.text == profile.pin) {
                Navigator.pop(ctx);
                ref
                    .read(profileControllerProvider.notifier)
                    .selectProfile(profile);
                if (widget.isSwitching && context.canPop()) {
                  context.pop();
                } else {
                  context.go('/home');
                }
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Incorrect PIN. Try again.')),
                );
              }
            },
            child: const Text('Unlock', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showAddProfileDialog() {
    final nameController = TextEditingController();
    String selectedAvatarId = ProfileAvatars.all.first.id;
    String selectedCategory = ProfileAvatars.categories.first;
    bool isKids = false;
    final List<String> selectedGenres = [];
    String feedMode = 'all';

    final availableGenres = [
      'Action',
      'Sci-Fi',
      'Drama',
      'Comedy',
      'Horror',
      'Animation',
      'Romance',
      'Thriller',
      'Documentary',
    ];

    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          backgroundColor: const Color(0xFF0D0F18),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
            side: const BorderSide(color: Color(0xFF1E2638), width: 1),
          ),
          title: const Text(
            'Create New Profile',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 19,
            ),
          ),
          content: SizedBox(
            width: 480,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: nameController,
                    autofocus: true,
                    textInputAction: TextInputAction.next,
                    onSubmitted: (_) {
                      FocusScope.of(ctx).unfocus();
                      FocusScope.of(ctx).nextFocus();
                    },
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Profile Name',
                      labelStyle: const TextStyle(color: Colors.white60),
                      hintText: 'e.g. Alex, Roomie, Sister',
                      hintStyle: const TextStyle(color: Colors.white30),
                      filled: true,
                      fillColor: Colors.white.withValues(alpha: 0.05),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Category Selector for 30+ Avatars
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Choose Avatar',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        selectedCategory,
                        style: const TextStyle(
                          color: Color(0xFF818CF8),
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: ProfileAvatars.categories.map((cat) {
                        final isCatSelected = cat == selectedCategory;
                        return Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: ChoiceChip(
                            label: Text(
                              cat,
                              style: TextStyle(
                                fontSize: 11,
                                color: isCatSelected
                                    ? Colors.white
                                    : Colors.white60,
                                fontWeight: isCatSelected
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                            ),
                            selected: isCatSelected,
                            selectedColor: const Color(0xFF4F46E5),
                            backgroundColor: const Color(0xFF151926),
                            onSelected: (val) {
                              if (val) {
                                setModalState(() => selectedCategory = cat);
                              }
                            },
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Avatar Grid for selected category
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: ProfileAvatars.byCategory(selectedCategory).map((
                      avatar,
                    ) {
                      final isSelected = avatar.id == selectedAvatarId;
                      return GestureDetector(
                        onTap: () =>
                            setModalState(() => selectedAvatarId = avatar.id),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: avatar.gradientColors,
                            ),
                            borderRadius: BorderRadius.circular(14),
                            border: isSelected
                                ? Border.all(color: Colors.white, width: 2.5)
                                : Border.all(
                                    color: Colors.white.withValues(alpha: 0.15),
                                    width: 1,
                                  ),
                            boxShadow: isSelected
                                ? [
                                    BoxShadow(
                                      color: avatar.gradientColors.first
                                          .withValues(alpha: 0.55),
                                      blurRadius: 10,
                                      spreadRadius: 2,
                                    ),
                                  ]
                                : null,
                          ),
                          child: Icon(
                            avatar.icon,
                            color: Colors.white,
                            size: 26,
                          ),
                        ),
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: 20),
                  const Divider(color: Color(0xFF1E2638)),
                  const SizedBox(height: 8),

                  // Content Preferences: Genre Affinities
                  const Text(
                    'Content Affinity (Genres)',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: availableGenres.map((genre) {
                      final isChosen = selectedGenres.contains(genre);
                      return FilterChip(
                        label: Text(genre, style: const TextStyle(fontSize: 11)),
                        selected: isChosen,
                        selectedColor: const Color(
                          0xFF6366F1,
                        ).withValues(alpha: 0.35),
                        checkmarkColor: const Color(0xFF818CF8),
                        backgroundColor: const Color(0xFF141824),
                        labelStyle: TextStyle(
                          color: isChosen
                              ? const Color(0xFFA5B4FC)
                              : Colors.white60,
                        ),
                        onSelected: (val) {
                          setModalState(() {
                            if (val) {
                              selectedGenres.add(genre);
                            } else {
                              selectedGenres.remove(genre);
                            }
                          });
                        },
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: 16),

                  // Feed Focus
                  const Text(
                    'Feed Mode',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: feedMode,
                    dropdownColor: const Color(0xFF151926),
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.white.withValues(alpha: 0.05),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'all',
                        child: Text('All Streams (Universal)'),
                      ),
                      DropdownMenuItem(
                        value: 'movies',
                        child: Text('Cinematic Movies Only'),
                      ),
                      DropdownMenuItem(
                        value: 'series',
                        child: Text('Binge Series Focus'),
                      ),
                      DropdownMenuItem(
                        value: 'anime',
                        child: Text('Anime & Animation Focus'),
                      ),
                    ],
                    onChanged: (val) {
                      if (val != null) setModalState(() => feedMode = val);
                    },
                  ),

                  const SizedBox(height: 12),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text(
                      'Kids Safe Shield',
                      style: TextStyle(color: Colors.white, fontSize: 14),
                    ),
                    subtitle: const Text(
                      'Filters out adult & mature content',
                      style: TextStyle(color: Colors.white54, fontSize: 12),
                    ),
                    value: isKids,
                    activeTrackColor: const Color(0xFF6366F1),
                    onChanged: (val) => setModalState(() => isKids = val),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text(
                'Cancel',
                style: TextStyle(color: Colors.white60),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6366F1),
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: () {
                if (nameController.text.trim().isNotEmpty) {
                  ref
                      .read(profileControllerProvider.notifier)
                      .addProfile(
                        name: nameController.text.trim(),
                        avatarId: selectedAvatarId,
                        isKids: isKids,
                        preferredGenres: selectedGenres,
                        feedMode: feedMode,
                      );
                  Navigator.pop(ctx);
                }
              },
              child: const Text(
                'Create Profile',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditProfileDialog(UserProfile profile) {
    final nameController = TextEditingController(text: profile.name);
    String selectedAvatarId = profile.avatarId;
    final currentAvatar = ProfileAvatars.get(profile.avatarId);
    String selectedCategory = currentAvatar.category;
    final List<String> selectedGenres = List.from(profile.preferredGenres);
    String feedMode = profile.feedMode;
    bool isKids = profile.isKids;

    final availableGenres = [
      'Action',
      'Sci-Fi',
      'Drama',
      'Comedy',
      'Horror',
      'Animation',
      'Romance',
      'Thriller',
      'Documentary',
    ];

    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          backgroundColor: const Color(0xFF0D0F18),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
            side: const BorderSide(color: Color(0xFF1E2638), width: 1),
          ),
          title: Text(
            'Edit ${profile.name}',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 19,
            ),
          ),
          content: SizedBox(
            width: 480,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: nameController,
                    textInputAction: TextInputAction.next,
                    onSubmitted: (_) {
                      FocusScope.of(ctx).unfocus();
                      FocusScope.of(ctx).nextFocus();
                    },
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Profile Name',
                      labelStyle: const TextStyle(color: Colors.white60),
                      filled: true,
                      fillColor: Colors.white.withValues(alpha: 0.05),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Change Avatar',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        selectedCategory,
                        style: const TextStyle(
                          color: Color(0xFF818CF8),
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: ProfileAvatars.categories.map((cat) {
                        final isCatSelected = cat == selectedCategory;
                        return Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: ChoiceChip(
                            label: Text(
                              cat,
                              style: TextStyle(
                                fontSize: 11,
                                color: isCatSelected
                                    ? Colors.white
                                    : Colors.white60,
                                fontWeight: isCatSelected
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                            ),
                            selected: isCatSelected,
                            selectedColor: const Color(0xFF4F46E5),
                            backgroundColor: const Color(0xFF151926),
                            onSelected: (val) {
                              if (val) {
                                setModalState(() => selectedCategory = cat);
                              }
                            },
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 12),

                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: ProfileAvatars.byCategory(selectedCategory).map((
                      avatar,
                    ) {
                      final isSelected = avatar.id == selectedAvatarId;
                      return GestureDetector(
                        onTap: () =>
                            setModalState(() => selectedAvatarId = avatar.id),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: avatar.gradientColors,
                            ),
                            borderRadius: BorderRadius.circular(14),
                            border: isSelected
                                ? Border.all(color: Colors.white, width: 2.5)
                                : Border.all(
                                    color: Colors.white.withValues(alpha: 0.15),
                                    width: 1,
                                  ),
                            boxShadow: isSelected
                                ? [
                                    BoxShadow(
                                      color: avatar.gradientColors.first
                                          .withValues(alpha: 0.55),
                                      blurRadius: 10,
                                      spreadRadius: 2,
                                    ),
                                  ]
                                : null,
                          ),
                          child: Icon(
                            avatar.icon,
                            color: Colors.white,
                            size: 26,
                          ),
                        ),
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: 20),
                  const Divider(color: Color(0xFF1E2638)),
                  const SizedBox(height: 8),

                  const Text(
                    'Content Affinity (Genres)',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: availableGenres.map((genre) {
                      final isChosen = selectedGenres.contains(genre);
                      return FilterChip(
                        label: Text(genre, style: const TextStyle(fontSize: 11)),
                        selected: isChosen,
                        selectedColor: const Color(
                          0xFF6366F1,
                        ).withValues(alpha: 0.35),
                        checkmarkColor: const Color(0xFF818CF8),
                        backgroundColor: const Color(0xFF141824),
                        labelStyle: TextStyle(
                          color: isChosen
                              ? const Color(0xFFA5B4FC)
                              : Colors.white60,
                        ),
                        onSelected: (val) {
                          setModalState(() {
                            if (val) {
                              selectedGenres.add(genre);
                            } else {
                              selectedGenres.remove(genre);
                            }
                          });
                        },
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: 16),

                  const Text(
                    'Feed Mode',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: feedMode,
                    dropdownColor: const Color(0xFF151926),
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.white.withValues(alpha: 0.05),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'all',
                        child: Text('All Streams (Universal)'),
                      ),
                      DropdownMenuItem(
                        value: 'movies',
                        child: Text('Cinematic Movies Only'),
                      ),
                      DropdownMenuItem(
                        value: 'series',
                        child: Text('Binge Series Focus'),
                      ),
                      DropdownMenuItem(
                        value: 'anime',
                        child: Text('Anime & Animation Focus'),
                      ),
                    ],
                    onChanged: (val) {
                      if (val != null) setModalState(() => feedMode = val);
                    },
                  ),

                  const SizedBox(height: 12),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text(
                      'Kids Safe Shield',
                      style: TextStyle(color: Colors.white, fontSize: 14),
                    ),
                    subtitle: const Text(
                      'Filters out adult & mature content',
                      style: TextStyle(color: Colors.white54, fontSize: 12),
                    ),
                    value: isKids,
                    activeTrackColor: const Color(0xFF6366F1),
                    onChanged: (val) => setModalState(() => isKids = val),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                ref
                    .read(profileControllerProvider.notifier)
                    .deleteProfile(profile.id);
              },
              child: const Text(
                'Delete Profile',
                style: TextStyle(color: Colors.redAccent),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6366F1),
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: () {
                ref
                    .read(profileControllerProvider.notifier)
                    .updateProfile(
                      profile.copyWith(
                        name: nameController.text.trim(),
                        avatarId: selectedAvatarId,
                        isKids: isKids,
                        preferredGenres: selectedGenres,
                        feedMode: feedMode,
                      ),
                    );
                Navigator.pop(ctx);
              },
              child: const Text(
                'Save Changes',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final profileState = ref.watch(profileControllerProvider);
    final profiles = profileState.profiles;
    final isTv = ref.watch(deviceProfileProvider).asData?.value.isTv ?? false;
    final activeProfile = profileState.activeProfile;

    return Scaffold(
      backgroundColor: const Color(0xFF000000), // Pure OLED pitch-black
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: widget.isSwitching
            ? IconButton(
                icon: const Icon(Icons.close_rounded, color: Colors.white70),
                onPressed: () => context.pop(),
              )
            : null,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: TextButton.icon(
              icon: Icon(
                _isManaging ? Icons.check_circle_rounded : Icons.edit_rounded,
                size: 18,
                color: const Color(0xFF818CF8),
              ),
              label: Text(
                _isManaging ? 'Done' : 'Manage',
                style: const TextStyle(
                  color: Color(0xFF818CF8),
                  fontWeight: FontWeight.bold,
                ),
              ),
              onPressed: () => setState(() => _isManaging = !_isManaging),
            ),
          ),
        ],
      ),
      body: TvLogicalScale(
        enabled: isTv,
        child: AppBackdropLayer(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // ── Glowing Celestial Aether Logo Emblem ──
                  Container(
                    width: isTv ? 84 : 72,
                    height: isTv ? 84 : 72,
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF6366F1).withValues(alpha: 0.35),
                          blurRadius: 28,
                          spreadRadius: 4,
                        ),
                        BoxShadow(
                          color: const Color(0xFF06B6D4).withValues(alpha: 0.20),
                          blurRadius: 40,
                          spreadRadius: 8,
                        ),
                      ],
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.25),
                        width: 1.5,
                      ),
                    ),
                    child: ClipOval(
                      child: Image.asset(
                        'assets/images/aether_logo.jpg',
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Container(
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Color(0xFF6366F1), Color(0xFF06B6D4)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                          ),
                          child: const Icon(
                            Icons.auto_awesome,
                            color: Colors.white,
                            size: 32,
                          ),
                        ),
                      ),
                    ),
                  ),

                  const Text(
                    'A E T H E R',
                    style: TextStyle(
                      color: Color(0xFFA5B4FC),
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 4.5,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Who is watching?',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: isTv ? 34 : 28,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.6,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _isManaging
                        ? 'Select a profile to customize avatars and content preferences'
                        : 'Choose your profile to resume your personalized cinema',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white54,
                      fontSize: isTv ? 16 : 14,
                    ),
                  ),
                  SizedBox(height: isTv ? 56 : 44),
                  FocusTraversalGroup(
                    policy: WidgetOrderTraversalPolicy(),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      clipBehavior: Clip.none,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          for (int i = 0; i < profiles.length; i++) ...[
                            _ProfileCard(
                              profile: profiles[i],
                              isManaging: _isManaging,
                              isTv: isTv,
                              autofocus: activeProfile != null
                                  ? profiles[i].id == activeProfile.id
                                  : (i == 0),
                              onTap: () => _selectProfile(profiles[i]),
                            ),
                            SizedBox(width: isTv ? 32 : 24),
                          ],
                          if (profiles.length < 5)
                            _AddProfileCard(
                              isTv: isTv,
                              onTap: _showAddProfileDialog,
                            ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: isTv ? 52 : 38),
                  _ManageProfilesButton(
                    isManaging: _isManaging,
                    isTv: isTv,
                    onTap: () => setState(() => _isManaging = !_isManaging),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ProfileCard extends StatefulWidget {
  final UserProfile profile;
  final bool isManaging;
  final bool isTv;
  final bool autofocus;
  final VoidCallback onTap;

  const _ProfileCard({
    required this.profile,
    required this.isManaging,
    this.isTv = false,
    this.autofocus = false,
    required this.onTap,
  });

  @override
  State<_ProfileCard> createState() => _ProfileCardState();
}

class _ProfileCardState extends State<_ProfileCard> {
  bool _isFocused = false;
  bool _isHovered = false;
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode(debugLabel: 'profile_${widget.profile.id}');
    _focusNode.addListener(_onFocusChange);
  }

  void _onFocusChange() {
    if (mounted) setState(() => _isFocused = _focusNode.hasFocus);
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final avatar = ProfileAvatars.get(widget.profile.avatarId);
    final cardSize = widget.isTv ? 132.0 : 104.0;

    return FocusableActionDetector(
      focusNode: _focusNode,
      autofocus: widget.autofocus,
      onShowFocusHighlight: (val) => setState(() => _isFocused = _focusNode.hasFocus || val),
      onShowHoverHighlight: (val) => setState(() => _isHovered = val),
      actions: <Type, Action<Intent>>{
        ActivateIntent: CallbackAction<ActivateIntent>(
          onInvoke: (_) {
            widget.onTap();
            return null;
          },
        ),
        ButtonActivateIntent: CallbackAction<ButtonActivateIntent>(
          onInvoke: (_) {
            widget.onTap();
            return null;
          },
        ),
      },
      child: Focus(
        canRequestFocus: false,
        skipTraversal: true,
        onKeyEvent: (node, event) {
          if (event is KeyDownEvent) {
            final key = event.logicalKey;
            if (key == LogicalKeyboardKey.select ||
                key == LogicalKeyboardKey.enter ||
                key == LogicalKeyboardKey.numpadEnter ||
                key == LogicalKeyboardKey.space ||
                key == LogicalKeyboardKey.gameButtonA ||
                key == LogicalKeyboardKey.gameButtonSelect ||
                key == LogicalKeyboardKey.gameButtonStart) {
              widget.onTap();
              return KeyEventResult.handled;
            }
          }
          return KeyEventResult.ignored;
        },
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            _focusNode.requestFocus();
            widget.onTap();
          },
          child: AnimatedScale(
            scale: _isFocused ? 1.15 : (_isHovered ? 1.08 : 1.0),
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            child: AnimatedOpacity(
              opacity: _isFocused ? 1.0 : (_isHovered ? 0.95 : 0.70),
              duration: const Duration(milliseconds: 200),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Stack(
                    alignment: Alignment.center,
                    clipBehavior: Clip.none,
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        curve: Curves.easeOutCubic,
                        width: cardSize,
                        height: cardSize,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: avatar.gradientColors,
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius:
                              BorderRadius.circular(widget.isTv ? 28 : 22),
                          boxShadow: [
                            if (_isFocused) ...[
                              BoxShadow(
                                color: const Color(0xFF6366F1).withValues(
                                  alpha: 0.85,
                                ),
                                blurRadius: 32,
                                spreadRadius: 4,
                              ),
                              BoxShadow(
                                color: const Color(0xFF06B6D4).withValues(
                                  alpha: 0.50,
                                ),
                                blurRadius: 44,
                                spreadRadius: 8,
                              ),
                              const BoxShadow(
                                color: Colors.white38,
                                blurRadius: 18,
                                spreadRadius: 2,
                              ),
                            ] else ...[
                              BoxShadow(
                                color: avatar.gradientColors.first.withValues(
                                  alpha: _isHovered ? 0.45 : 0.20,
                                ),
                                blurRadius: _isHovered ? 18 : 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ],
                          border: _isFocused
                              ? Border.all(color: Colors.white, width: 3.5)
                              : (_isHovered
                                  ? Border.all(color: Colors.white, width: 2.5)
                                  : Border.all(
                                      color: Colors.white.withValues(
                                        alpha: 0.16,
                                      ),
                                      width: 1.5,
                                    )),
                        ),
                        child: Icon(
                          avatar.icon,
                          color: Colors.white,
                          size: widget.isTv ? 60 : 48,
                        ),
                      ),
                      if (widget.isManaging)
                        Container(
                          width: cardSize,
                          height: cardSize,
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.58),
                            borderRadius:
                                BorderRadius.circular(widget.isTv ? 28 : 22),
                          ),
                          child: Icon(
                            Icons.edit_rounded,
                            color: Colors.white,
                            size: widget.isTv ? 38 : 30,
                          ),
                        ),
                      if (widget.profile.pin != null)
                        Positioned(
                          bottom: 8,
                          right: 8,
                          child: Container(
                            padding: const EdgeInsets.all(5),
                            decoration: BoxDecoration(
                              color: Colors.black87,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.lock_rounded,
                              color: Colors.white70,
                              size: 14,
                            ),
                          ),
                        ),
                    ],
                  ),
                  SizedBox(height: widget.isTv ? 16 : 12),
                  Text(
                    widget.profile.name,
                    style: TextStyle(
                      color: _isFocused
                          ? Colors.white
                          : (_isHovered ? Colors.white : Colors.white70),
                      fontSize: widget.isTv ? 18 : 15,
                      fontWeight:
                          _isFocused ? FontWeight.w800 : FontWeight.w600,
                      letterSpacing: _isFocused ? 0.3 : 0,
                    ),
                  ),
                  if (_isFocused)
                    Container(
                      margin: const EdgeInsets.only(top: 6),
                      width: 26,
                      height: 4,
                      decoration: BoxDecoration(
                        color: const Color(0xFF818CF8),
                        borderRadius: BorderRadius.circular(2),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF818CF8).withValues(
                              alpha: 0.85,
                            ),
                            blurRadius: 8,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                    )
                  else if (widget.profile.feedMode != 'all')
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        widget.profile.feedMode.toUpperCase(),
                        style: const TextStyle(
                          color: Color(0xFF818CF8),
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AddProfileCard extends StatefulWidget {
  final bool isTv;
  final VoidCallback onTap;

  const _AddProfileCard({
    this.isTv = false,
    required this.onTap,
  });

  @override
  State<_AddProfileCard> createState() => _AddProfileCardState();
}

class _AddProfileCardState extends State<_AddProfileCard> {
  bool _isFocused = false;
  bool _isHovered = false;
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode(debugLabel: 'add_profile_card');
    _focusNode.addListener(_onFocusChange);
  }

  void _onFocusChange() {
    if (mounted) setState(() => _isFocused = _focusNode.hasFocus);
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cardSize = widget.isTv ? 132.0 : 104.0;

    return FocusableActionDetector(
      focusNode: _focusNode,
      onShowFocusHighlight: (val) => setState(() => _isFocused = _focusNode.hasFocus || val),
      onShowHoverHighlight: (val) => setState(() => _isHovered = val),
      actions: <Type, Action<Intent>>{
        ActivateIntent: CallbackAction<ActivateIntent>(
          onInvoke: (_) {
            widget.onTap();
            return null;
          },
        ),
        ButtonActivateIntent: CallbackAction<ButtonActivateIntent>(
          onInvoke: (_) {
            widget.onTap();
            return null;
          },
        ),
      },
      child: Focus(
        canRequestFocus: false,
        skipTraversal: true,
        onKeyEvent: (node, event) {
          if (event is KeyDownEvent) {
            final key = event.logicalKey;
            if (key == LogicalKeyboardKey.select ||
                key == LogicalKeyboardKey.enter ||
                key == LogicalKeyboardKey.numpadEnter ||
                key == LogicalKeyboardKey.space ||
                key == LogicalKeyboardKey.gameButtonA ||
                key == LogicalKeyboardKey.gameButtonSelect ||
                key == LogicalKeyboardKey.gameButtonStart) {
              widget.onTap();
              return KeyEventResult.handled;
            }
          }
          return KeyEventResult.ignored;
        },
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            _focusNode.requestFocus();
            widget.onTap();
          },
          child: AnimatedScale(
            scale: _isFocused ? 1.15 : (_isHovered ? 1.08 : 1.0),
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            child: AnimatedOpacity(
              opacity: _isFocused ? 1.0 : (_isHovered ? 0.95 : 0.70),
              duration: const Duration(milliseconds: 200),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeOutCubic,
                    width: cardSize,
                    height: cardSize,
                    decoration: BoxDecoration(
                      color: _isFocused
                          ? const Color(0xFF6366F1).withValues(alpha: 0.22)
                          : Colors.white.withValues(alpha: 0.05),
                      borderRadius:
                          BorderRadius.circular(widget.isTv ? 28 : 22),
                      boxShadow: _isFocused
                          ? [
                              BoxShadow(
                                color: const Color(0xFF6366F1).withValues(
                                  alpha: 0.65,
                                ),
                                blurRadius: 28,
                                spreadRadius: 3,
                              ),
                              const BoxShadow(
                                color: Colors.white30,
                                blurRadius: 16,
                                spreadRadius: 2,
                              ),
                            ]
                          : null,
                      border: _isFocused
                          ? Border.all(color: Colors.white, width: 3.5)
                          : Border.all(
                              color:
                                  _isHovered ? Colors.white70 : Colors.white24,
                              width: 1.5,
                            ),
                    ),
                    child: Icon(
                      Icons.add_rounded,
                      color: (_isFocused || _isHovered)
                          ? Colors.white
                          : Colors.white60,
                      size: widget.isTv ? 48 : 40,
                    ),
                  ),
                  SizedBox(height: widget.isTv ? 16 : 12),
                  Text(
                    'Add Profile',
                    style: TextStyle(
                      color: (_isFocused || _isHovered)
                          ? Colors.white
                          : Colors.white60,
                      fontSize: widget.isTv ? 18 : 15,
                      fontWeight:
                          _isFocused ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ManageProfilesButton extends StatefulWidget {
  final bool isManaging;
  final bool isTv;
  final VoidCallback onTap;

  const _ManageProfilesButton({
    required this.isManaging,
    this.isTv = false,
    required this.onTap,
  });

  @override
  State<_ManageProfilesButton> createState() => _ManageProfilesButtonState();
}

class _ManageProfilesButtonState extends State<_ManageProfilesButton> {
  bool _isFocused = false;
  bool _isHovered = false;
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode(debugLabel: 'manage_profiles_button');
    _focusNode.addListener(_onFocusChange);
  }

  void _onFocusChange() {
    if (mounted) setState(() => _isFocused = _focusNode.hasFocus);
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FocusableActionDetector(
      focusNode: _focusNode,
      onShowFocusHighlight: (val) => setState(() => _isFocused = _focusNode.hasFocus || val),
      onShowHoverHighlight: (val) => setState(() => _isHovered = val),
      actions: <Type, Action<Intent>>{
        ActivateIntent: CallbackAction<ActivateIntent>(
          onInvoke: (_) {
            widget.onTap();
            return null;
          },
        ),
        ButtonActivateIntent: CallbackAction<ButtonActivateIntent>(
          onInvoke: (_) {
            widget.onTap();
            return null;
          },
        ),
      },
      child: Focus(
        canRequestFocus: false,
        skipTraversal: true,
        onKeyEvent: (node, event) {
          if (event is KeyDownEvent) {
            final key = event.logicalKey;
            if (key == LogicalKeyboardKey.select ||
                key == LogicalKeyboardKey.enter ||
                key == LogicalKeyboardKey.numpadEnter ||
                key == LogicalKeyboardKey.space ||
                key == LogicalKeyboardKey.gameButtonA ||
                key == LogicalKeyboardKey.gameButtonSelect ||
                key == LogicalKeyboardKey.gameButtonStart) {
              widget.onTap();
              return KeyEventResult.handled;
            }
          }
          return KeyEventResult.ignored;
        },
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            _focusNode.requestFocus();
            widget.onTap();
          },
          child: AnimatedScale(
            scale: _isFocused ? 1.08 : (_isHovered ? 1.04 : 1.0),
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: EdgeInsets.symmetric(
                horizontal: widget.isTv ? 28 : 22,
                vertical: widget.isTv ? 14 : 10,
              ),
              decoration: BoxDecoration(
                color: _isFocused
                    ? const Color(0xFF6366F1).withValues(alpha: 0.35)
                    : (_isHovered
                        ? Colors.white.withValues(alpha: 0.12)
                        : Colors.white.withValues(alpha: 0.06)),
                borderRadius: BorderRadius.circular(30),
                border: _isFocused
                    ? Border.all(color: Colors.white, width: 2.5)
                    : Border.all(
                        color: _isHovered
                            ? Colors.white60
                            : Colors.white.withValues(alpha: 0.22),
                        width: 1.2,
                      ),
                boxShadow: _isFocused
                    ? [
                        BoxShadow(
                          color:
                              const Color(0xFF6366F1).withValues(alpha: 0.50),
                          blurRadius: 20,
                          spreadRadius: 2,
                        ),
                      ]
                    : null,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    widget.isManaging
                        ? Icons.check_circle_rounded
                        : Icons.edit_rounded,
                    size: widget.isTv ? 20 : 16,
                    color: _isFocused ? Colors.white : const Color(0xFFA5B4FC),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    widget.isManaging ? 'Done Managing' : 'Manage Profiles',
                    style: TextStyle(
                      color:
                          _isFocused ? Colors.white : const Color(0xFFA5B4FC),
                      fontSize: widget.isTv ? 16 : 14,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.4,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
