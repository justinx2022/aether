import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/profile/user_profile.dart';
import '../../../core/profile/profile_service.dart';
import '../../../core/profile/character_avatar_widget.dart';
import '../../../core/providers/device_info_provider.dart';
import '../../../core/theme/app_backdrop_layer.dart';

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

    if (profile.hasPin) {
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
              if (profile.verifyPin(controller.text.trim())) {
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
      'Crime',
      'Thriller',
      'Documentary',
      'Mystery',
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
            width: 520,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: nameController,
                    autofocus: true,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Profile Name',
                      labelStyle: const TextStyle(color: Colors.white60),
                      hintText: 'e.g. Baby, Holden, Walter, Alex',
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

                  // Category Selector
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
                  const SizedBox(height: 14),

                  // Avatar Grid with Actual Character Art
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: ProfileAvatars.byCategory(selectedCategory).map((avatar) {
                      final isSelected = avatar.id == selectedAvatarId;
                      return GestureDetector(
                        onTap: () => setModalState(() => selectedAvatarId = avatar.id),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CharacterAvatarWidget(
                              avatarId: avatar.id,
                              size: 56,
                              isSelected: isSelected,
                              showGlow: isSelected,
                            ),
                            const SizedBox(height: 4),
                            SizedBox(
                              width: 64,
                              child: Text(
                                avatar.label,
                                style: TextStyle(
                                  fontSize: 10,
                                  color: isSelected ? Colors.white : Colors.white60,
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ],
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
                        selectedColor: const Color(0xFF6366F1).withValues(alpha: 0.35),
                        checkmarkColor: const Color(0xFF818CF8),
                        backgroundColor: const Color(0xFF141824),
                        labelStyle: TextStyle(
                          color: isChosen ? const Color(0xFFA5B4FC) : Colors.white60,
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
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'all', child: Text('All Streams (Universal)')),
                      DropdownMenuItem(value: 'movies', child: Text('Cinematic Movies Only')),
                      DropdownMenuItem(value: 'series', child: Text('Binge Series Focus')),
                    ],
                    onChanged: (val) {
                      if (val != null) setModalState(() => feedMode = val);
                    },
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Kids Safe Shield', style: TextStyle(color: Colors.white, fontSize: 14)),
                    subtitle: const Text('Filters out adult & mature content', style: TextStyle(color: Colors.white54, fontSize: 12)),
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
              child: const Text('Cancel', style: TextStyle(color: Colors.white60)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6366F1),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () {
                final name = nameController.text.trim().isEmpty ? 'Viewer' : nameController.text.trim();
                ref.read(profileControllerProvider.notifier).addProfile(
                  name: name,
                  avatarId: selectedAvatarId,
                  isKids: isKids,
                  preferredGenres: selectedGenres,
                  feedMode: feedMode,
                );
                Navigator.pop(ctx);
              },
              child: const Text(
                'Create Profile',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
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
      'Crime',
      'Thriller',
      'Documentary',
      'Mystery',
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
            width: 520,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: nameController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Profile Name',
                      labelStyle: const TextStyle(color: Colors.white60),
                      filled: true,
                      fillColor: Colors.white.withValues(alpha: 0.05),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    ),
                  ),
                  const SizedBox(height: 20),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Choose Avatar',
                        style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                      Text(
                        selectedCategory,
                        style: const TextStyle(color: Color(0xFF818CF8), fontSize: 12, fontWeight: FontWeight.bold),
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
                                color: isCatSelected ? Colors.white : Colors.white60,
                                fontWeight: isCatSelected ? FontWeight.bold : FontWeight.normal,
                              ),
                            ),
                            selected: isCatSelected,
                            selectedColor: const Color(0xFF4F46E5),
                            backgroundColor: const Color(0xFF151926),
                            onSelected: (val) {
                              if (val) setModalState(() => selectedCategory = cat);
                            },
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 14),

                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: ProfileAvatars.byCategory(selectedCategory).map((avatar) {
                      final isSelected = avatar.id == selectedAvatarId;
                      return GestureDetector(
                        onTap: () => setModalState(() => selectedAvatarId = avatar.id),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CharacterAvatarWidget(
                              avatarId: avatar.id,
                              size: 56,
                              isSelected: isSelected,
                              showGlow: isSelected,
                            ),
                            const SizedBox(height: 4),
                            SizedBox(
                              width: 64,
                              child: Text(
                                avatar.label,
                                style: TextStyle(
                                  fontSize: 10,
                                  color: isSelected ? Colors.white : Colors.white60,
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: 20),
                  const Divider(color: Color(0xFF1E2638)),
                  const SizedBox(height: 8),

                  const Text(
                    'Content Affinity (Genres)',
                    style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
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
                        selectedColor: const Color(0xFF6366F1).withValues(alpha: 0.35),
                        checkmarkColor: const Color(0xFF818CF8),
                        backgroundColor: const Color(0xFF141824),
                        labelStyle: TextStyle(
                          color: isChosen ? const Color(0xFFA5B4FC) : Colors.white60,
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
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Kids Safe Shield', style: TextStyle(color: Colors.white, fontSize: 14)),
                    subtitle: const Text('Filters out adult & mature content', style: TextStyle(color: Colors.white54, fontSize: 12)),
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
                ref.read(profileControllerProvider.notifier).deleteProfile(profile.id);
              },
              child: const Text('Delete Profile', style: TextStyle(color: Colors.redAccent)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6366F1),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () {
                ref.read(profileControllerProvider.notifier).updateProfile(
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
              child: const Text('Save Changes', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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

    // ── Glamorous First-Run Netflix-Style Setup when no profiles exist ──
    if (profiles.isEmpty) {
      return Scaffold(
        backgroundColor: const Color(0xFF000000),
        body: AppBackdropLayer(
          child: _FirstRunSetupView(
            onCreated: (profile) => _selectProfile(profile),
          ),
        ),
      );
    }

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
      body: AppBackdropLayer(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ── Glowing Celestial Aether Brand Emblem ──
                Container(
                  width: 72,
                  height: 72,
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
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 4.0,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Who is watching?',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _isManaging
                      ? 'Select a profile to customize characters and preferences'
                      : 'Choose your profile to resume your personalized cinema',
                  style: const TextStyle(color: Colors.white54, fontSize: 14),
                ),
                const SizedBox(height: 48),
                Wrap(
                  spacing: 28,
                  runSpacing: 28,
                  alignment: WrapAlignment.center,
                  children: [
                    ...profiles.map(
                      (p) => _ProfileCard(
                        profile: p,
                        isManaging: _isManaging,
                        onTap: () => _selectProfile(p),
                      ),
                    ),
                    if (profiles.length < 5)
                      _AddProfileCard(onTap: _showAddProfileDialog),
                  ],
                ),
              ],
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
  final VoidCallback onTap;

  const _ProfileCard({
    required this.profile,
    required this.isManaging,
    required this.onTap,
  });

  @override
  State<_ProfileCard> createState() => _ProfileCardState();
}

class _ProfileCardState extends State<_ProfileCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return FocusableActionDetector(
      onShowHoverHighlight: (val) => setState(() => _isHovered = val),
      onShowFocusHighlight: (val) => setState(() => _isHovered = val),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _isHovered ? 1.08 : 1.0,
          duration: const Duration(milliseconds: 180),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                alignment: Alignment.center,
                children: [
                  CharacterAvatarWidget(
                    avatarId: widget.profile.avatarId,
                    size: 104,
                    isSelected: _isHovered,
                    showGlow: true,
                  ),
                  if (widget.isManaging)
                    Container(
                      width: 104,
                      height: 104,
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.55),
                        borderRadius: BorderRadius.circular(22),
                      ),
                      child: const Icon(
                        Icons.edit_rounded,
                        color: Colors.white,
                        size: 32,
                      ),
                    ),
                  if (widget.profile.hasPin)
                    Positioned(
                      bottom: 6,
                      right: 6,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.black87,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.lock_rounded,
                          color: Colors.white70,
                          size: 12,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                widget.profile.name,
                style: TextStyle(
                  color: _isHovered ? Colors.white : Colors.white70,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (widget.profile.feedMode != 'all')
                Padding(
                  padding: const EdgeInsets.only(top: 2),
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
    );
  }
}

class _AddProfileCard extends StatefulWidget {
  final VoidCallback onTap;

  const _AddProfileCard({required this.onTap});

  @override
  State<_AddProfileCard> createState() => _AddProfileCardState();
}

class _AddProfileCardState extends State<_AddProfileCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return FocusableActionDetector(
      onShowHoverHighlight: (val) => setState(() => _isHovered = val),
      onShowFocusHighlight: (val) => setState(() => _isHovered = val),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _isHovered ? 1.08 : 1.0,
          duration: const Duration(milliseconds: 180),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 104,
                height: 104,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: _isHovered ? Colors.white70 : Colors.white24,
                    width: 1.5,
                  ),
                ),
                child: Icon(
                  Icons.add_rounded,
                  color: _isHovered ? Colors.white : Colors.white54,
                  size: 44,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Add Profile',
                style: TextStyle(
                  color: _isHovered ? Colors.white : Colors.white54,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════
// ── FIRST-RUN GLAMOROUS NETFLIX-STYLE SETUP VIEW ──
// ══════════════════════════════════════════════════════════════════════

class _FirstRunSetupView extends ConsumerStatefulWidget {
  final ValueChanged<UserProfile> onCreated;

  const _FirstRunSetupView({required this.onCreated});

  @override
  ConsumerState<_FirstRunSetupView> createState() => _FirstRunSetupViewState();
}

class _FirstRunSetupViewState extends ConsumerState<_FirstRunSetupView> {
  final _nameController = TextEditingController();
  String _selectedAvatarId = 'avatar_baby_driver';
  bool _isCustomizing = false;

  // TV / Remote-Optimized Quick Launch Presets
  static const _presets = [
    (
      title: 'Baby',
      subtitle: 'Baby Driver · Movies Focus',
      avatarId: 'avatar_baby_driver',
      name: 'Baby',
      feed: 'movies',
    ),
    (
      title: 'Holden',
      subtitle: 'The Expanse · Sci-Fi & Series',
      avatarId: 'avatar_expanse',
      name: 'Holden',
      feed: 'series',
    ),
    (
      title: 'Paul',
      subtitle: 'Dune · Epic Cinema',
      avatarId: 'avatar_paul_atreides',
      name: 'Paul',
      feed: 'all',
    ),
    (
      title: 'Officer K',
      subtitle: 'Blade Runner 2049 · Neo-Noir',
      avatarId: 'avatar_blade_runner',
      name: 'Officer K',
      feed: 'movies',
    ),
    (
      title: 'Heisenberg',
      subtitle: 'Breaking Bad · Prestige Binge',
      avatarId: 'avatar_heisenberg',
      name: 'Walter',
      feed: 'series',
    ),
    (
      title: 'Aurora',
      subtitle: 'Northern Lights · Universal',
      avatarId: 'avatar_aurora',
      name: 'Voyager',
      feed: 'all',
    ),
  ];

  Future<void> _createWithPreset(String name, String avatarId, String feed) async {
    final profile = await ref.read(profileControllerProvider.notifier).addProfile(
      name: name,
      avatarId: avatarId,
      feedMode: feed,
    );
    widget.onCreated(profile);
  }

  Future<void> _createCustom() async {
    final name = _nameController.text.trim().isEmpty ? 'Viewer' : _nameController.text.trim();
    final profile = await ref.read(profileControllerProvider.notifier).addProfile(
      name: name,
      avatarId: _selectedAvatarId,
    );
    widget.onCreated(profile);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dev = ref.watch(deviceProfileProvider);
    final isTv = dev.isTv;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 820),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Glowing Celestial Emblem ──
              Container(
                width: 80,
                height: 80,
                margin: const EdgeInsets.only(bottom: 24),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF6366F1).withValues(alpha: 0.45),
                      blurRadius: 36,
                      spreadRadius: 6,
                    ),
                    BoxShadow(
                      color: const Color(0xFF06B6D4).withValues(alpha: 0.25),
                      blurRadius: 48,
                      spreadRadius: 10,
                    ),
                  ],
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.35),
                    width: 2.0,
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
                      child: const Icon(Icons.auto_awesome, color: Colors.white, size: 36),
                    ),
                  ),
                ),
              ),

              const Text(
                'A E T H E R',
                style: TextStyle(
                  color: Color(0xFFA5B4FC),
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 6.0,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Welcome to Pure Cinema',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.8,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Text(
                isTv
                    ? 'Use your remote to select your cinema persona and launch instantly.'
                    : 'Personalize your profile with iconic characters from cinema & television.',
                style: const TextStyle(color: Colors.white60, fontSize: 15),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 36),

              if (!_isCustomizing) ...[
                // ── Device-Aware Netflix Quick Start Deck ──
                Wrap(
                  spacing: 20,
                  runSpacing: 20,
                  alignment: WrapAlignment.center,
                  children: _presets.map((p) {
                    return _PresetTile(
                      preset: p,
                      isTv: isTv,
                      onTap: () => _createWithPreset(p.name, p.avatarId, p.feed),
                    );
                  }).toList(),
                ),

                const SizedBox(height: 32),
                TextButton.icon(
                  onPressed: () => setState(() => _isCustomizing = true),
                  icon: const Icon(Icons.tune_rounded, color: Color(0xFF818CF8), size: 18),
                  label: const Text(
                    'Custom Profile Name & Avatar',
                    style: TextStyle(
                      color: Color(0xFF818CF8),
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ] else ...[
                // ── Deep Customization View ──
                Container(
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0E1322),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: const Color(0xFF1E293B)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          CharacterAvatarWidget(
                            avatarId: _selectedAvatarId,
                            size: 72,
                            isSelected: true,
                          ),
                          const SizedBox(width: 20),
                          Expanded(
                            child: TextField(
                              controller: _nameController,
                              autofocus: !isTv,
                              style: const TextStyle(color: Colors.white, fontSize: 17),
                              decoration: InputDecoration(
                                labelText: 'Your Profile Name',
                                labelStyle: const TextStyle(color: Colors.white60),
                                hintText: 'Enter name...',
                                hintStyle: const TextStyle(color: Colors.white24),
                                filled: true,
                                fillColor: Colors.white.withValues(alpha: 0.05),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      const Text(
                        'Choose from 30 Iconic Characters & Backdrops',
                        style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 96,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: ProfileAvatars.all.length,
                          separatorBuilder: (_, __) => const SizedBox(width: 14),
                          itemBuilder: (context, idx) {
                            final av = ProfileAvatars.all[idx];
                            final isSel = av.id == _selectedAvatarId;
                            return GestureDetector(
                              onTap: () => setState(() => _selectedAvatarId = av.id),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  CharacterAvatarWidget(
                                    avatarId: av.id,
                                    size: 60,
                                    isSelected: isSel,
                                    showGlow: isSel,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    av.label,
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: isSel ? Colors.white : Colors.white54,
                                      fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 28),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () => setState(() => _isCustomizing = false),
                            child: const Text('Back to Presets', style: TextStyle(color: Colors.white60)),
                          ),
                          const SizedBox(width: 12),
                          FilledButton(
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFF6366F1),
                              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            onPressed: _createCustom,
                            child: const Text(
                              'Start Watching',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _PresetTile extends StatefulWidget {
  final ({String title, String subtitle, String avatarId, String name, String feed}) preset;
  final bool isTv;
  final VoidCallback onTap;

  const _PresetTile({
    required this.preset,
    required this.isTv,
    required this.onTap,
  });

  @override
  State<_PresetTile> createState() => _PresetTileState();
}

class _PresetTileState extends State<_PresetTile> {
  bool _isFocused = false;

  @override
  Widget build(BuildContext context) {
    return FocusableActionDetector(
      autofocus: false,
      onShowFocusHighlight: (v) => setState(() => _isFocused = v),
      onShowHoverHighlight: (v) => setState(() => _isFocused = v),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          width: widget.isTv ? 240 : 220,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _isFocused ? const Color(0xFF1E293B) : const Color(0xFF0F172A),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: _isFocused ? const Color(0xFF818CF8) : Colors.white.withValues(alpha: 0.12),
              width: _isFocused ? 2.5 : 1.0,
            ),
            boxShadow: _isFocused
                ? [
                    BoxShadow(
                      color: const Color(0xFF6366F1).withValues(alpha: 0.40),
                      blurRadius: 20,
                      spreadRadius: 2,
                    ),
                  ]
                : null,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CharacterAvatarWidget(
                avatarId: widget.preset.avatarId,
                size: widget.isTv ? 90 : 80,
                isSelected: _isFocused,
              ),
              const SizedBox(height: 12),
              Text(
                widget.preset.title,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                widget.preset.subtitle,
                style: const TextStyle(color: Colors.white54, fontSize: 11),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: _isFocused ? const Color(0xFF6366F1) : Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Launch',
                  style: TextStyle(
                    color: _isFocused ? Colors.white : const Color(0xFF818CF8),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
