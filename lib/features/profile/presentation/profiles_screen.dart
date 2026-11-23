import 'package:flutter/material.dart';
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
  final _pinController = TextEditingController();
  final _addNameController = TextEditingController();
  final _editNameController = TextEditingController();

  @override
  void dispose() {
    _pinController.dispose();
    _addNameController.dispose();
    _editNameController.dispose();
    super.dispose();
  }

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
    _pinController.clear();
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
          controller: _pinController,
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
              if (profile.verifyPin(_pinController.text.trim())) {
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
    _addNameController.clear();
    String selectedAvatarId = ProfileAvatars.all.first.id;
    String selectedCategory = ProfileAvatars.categories.first;
    String searchQuery = '';
    bool isKids = false;
    final List<String> selectedGenres = [];
    String feedMode = 'all';
    String maturityRating = '18+';

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
        builder: (context, setModalState) {
          final displayedAvatars = searchQuery.isNotEmpty
              ? ProfileAvatars.all.where((a) {
                  final q = searchQuery.toLowerCase();
                  return a.label.toLowerCase().contains(q) ||
                      a.subtitle.toLowerCase().contains(q) ||
                      a.category.toLowerCase().contains(q);
                }).toList()
              : ProfileAvatars.byCategory(selectedCategory);

          return AlertDialog(
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
                      controller: _addNameController,
                      autofocus: true,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: 'Profile Name',
                        labelStyle: const TextStyle(color: Colors.white60),
                        hintText: 'e.g. Sara, Mathew, Walter, Alex',
                        hintStyle: const TextStyle(color: Colors.white30),
                        filled: true,
                        fillColor: Colors.white.withValues(alpha: 0.05),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),

                    // Search and Category Selector
                    TextField(
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                      decoration: InputDecoration(
                        hintText: 'Search 100+ character avatars...',
                        hintStyle: const TextStyle(color: Colors.white38, fontSize: 12),
                        prefixIcon: const Icon(Icons.search_rounded, color: Colors.white54, size: 18),
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        filled: true,
                        fillColor: Colors.white.withValues(alpha: 0.05),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      onChanged: (val) => setModalState(() => searchQuery = val.trim()),
                    ),
                    const SizedBox(height: 10),

                    if (searchQuery.isEmpty)
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
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 240),
                      child: SingleChildScrollView(
                        child: Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: displayedAvatars.map((avatar) {
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
                      ),
                    ),

                    const SizedBox(height: 16),
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
                        final isSelected = selectedGenres.contains(genre);
                        return FilterChip(
                          label: Text(
                            genre,
                            style: TextStyle(
                              fontSize: 11,
                              color: isSelected ? Colors.white : Colors.white70,
                            ),
                          ),
                          selected: isSelected,
                          selectedColor: const Color(0xFF6366F1),
                          backgroundColor: Colors.white.withValues(alpha: 0.05),
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
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: feedMode,
                      dropdownColor: const Color(0xFF0F121C),
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                      decoration: InputDecoration(
                        labelText: 'Initial Feed Experience',
                        labelStyle: const TextStyle(color: Colors.white60),
                        filled: true,
                        fillColor: Colors.white.withValues(alpha: 0.05),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'all', child: Text('Universal Feed (All Content)')),
                        DropdownMenuItem(value: 'movies', child: Text('Cinema Only (Feature Films)')),
                        DropdownMenuItem(value: 'series', child: Text('Series Only (Television Focus)')),
                        DropdownMenuItem(value: 'anime', child: Text('Anime Priority')),
                      ],
                      onChanged: (val) {
                        if (val != null) setModalState(() => feedMode = val);
                      },
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      initialValue: maturityRating,
                      dropdownColor: const Color(0xFF0F121C),
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                      decoration: InputDecoration(
                        labelText: 'Maturity Rating (Max)',
                        labelStyle: const TextStyle(color: Colors.white60),
                        filled: true,
                        fillColor: Colors.white.withValues(alpha: 0.05),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'All', child: Text('All Ages')),
                        DropdownMenuItem(value: '7+', child: Text('7+ (Older Kids)')),
                        DropdownMenuItem(value: '13+', child: Text('13+ (Teen)')),
                        DropdownMenuItem(value: '16+', child: Text('16+ (Mature)')),
                        DropdownMenuItem(value: '18+', child: Text('18+ (Adults Only)')),
                      ],
                      onChanged: (val) {
                        if (val != null) setModalState(() => maturityRating = val);
                      },
                    ),
                    const SizedBox(height: 8),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Kids Safe Shield', style: TextStyle(color: Colors.white, fontSize: 13)),
                      subtitle: const Text('Filters out adult & mature content', style: TextStyle(color: Colors.white54, fontSize: 11)),
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
                  final name = _addNameController.text.trim().isEmpty ? 'Viewer' : _addNameController.text.trim();
                  ref.read(profileControllerProvider.notifier).addProfile(
                    name: name,
                    avatarId: selectedAvatarId,
                    isKids: isKids,
                    preferredGenres: selectedGenres,
                    feedMode: feedMode,
                    maturityRating: maturityRating,
                  );
                  Navigator.pop(ctx);
                },
                child: const Text(
                  'Create Profile',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showEditProfileDialog(UserProfile profile) {
    _editNameController.text = profile.name;
    String selectedAvatarId = profile.avatarId;
    final currentAvatar = ProfileAvatars.get(profile.avatarId);
    String selectedCategory = currentAvatar.category;
    String searchQuery = '';
    final List<String> selectedGenres = List.from(profile.preferredGenres);
    String feedMode = profile.feedMode;
    String maturityRating = profile.maturityRating;
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
        builder: (context, setModalState) {
          final displayedAvatars = searchQuery.isNotEmpty
              ? ProfileAvatars.all.where((a) {
                  final q = searchQuery.toLowerCase();
                  return a.label.toLowerCase().contains(q) ||
                      a.subtitle.toLowerCase().contains(q) ||
                      a.category.toLowerCase().contains(q);
                }).toList()
              : ProfileAvatars.byCategory(selectedCategory);

          return AlertDialog(
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
                      controller: _editNameController,
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
                    const SizedBox(height: 18),

                    // Search and Category Selector
                    TextField(
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                      decoration: InputDecoration(
                        hintText: 'Search 100+ character avatars...',
                        hintStyle: const TextStyle(color: Colors.white38, fontSize: 12),
                        prefixIcon: const Icon(Icons.search_rounded, color: Colors.white54, size: 18),
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        filled: true,
                        fillColor: Colors.white.withValues(alpha: 0.05),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      onChanged: (val) => setModalState(() => searchQuery = val.trim()),
                    ),
                    const SizedBox(height: 10),

                    if (searchQuery.isEmpty)
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
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 240),
                      child: SingleChildScrollView(
                        child: Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: displayedAvatars.map((avatar) {
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
                      ),
                    ),

                    const SizedBox(height: 16),
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
                        final isSelected = selectedGenres.contains(genre);
                        return FilterChip(
                          label: Text(
                            genre,
                            style: TextStyle(
                              fontSize: 11,
                              color: isSelected ? Colors.white : Colors.white70,
                            ),
                          ),
                          selected: isSelected,
                          selectedColor: const Color(0xFF6366F1),
                          backgroundColor: Colors.white.withValues(alpha: 0.05),
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
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: feedMode,
                      dropdownColor: const Color(0xFF0F121C),
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                      decoration: InputDecoration(
                        labelText: 'Initial Feed Experience',
                        labelStyle: const TextStyle(color: Colors.white60),
                        filled: true,
                        fillColor: Colors.white.withValues(alpha: 0.05),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'all', child: Text('Universal Feed (All Content)')),
                        DropdownMenuItem(value: 'movies', child: Text('Cinema Only (Feature Films)')),
                        DropdownMenuItem(value: 'series', child: Text('Series Only (Television Focus)')),
                        DropdownMenuItem(value: 'anime', child: Text('Anime Priority')),
                      ],
                      onChanged: (val) {
                        if (val != null) setModalState(() => feedMode = val);
                      },
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      initialValue: maturityRating,
                      dropdownColor: const Color(0xFF0F121C),
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                      decoration: InputDecoration(
                        labelText: 'Maturity Rating (Max)',
                        labelStyle: const TextStyle(color: Colors.white60),
                        filled: true,
                        fillColor: Colors.white.withValues(alpha: 0.05),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'All', child: Text('All Ages')),
                        DropdownMenuItem(value: '7+', child: Text('7+ (Older Kids)')),
                        DropdownMenuItem(value: '13+', child: Text('13+ (Teen)')),
                        DropdownMenuItem(value: '16+', child: Text('16+ (Mature)')),
                        DropdownMenuItem(value: '18+', child: Text('18+ (Adults Only)')),
                      ],
                      onChanged: (val) {
                        if (val != null) setModalState(() => maturityRating = val);
                      },
                    ),
                    const SizedBox(height: 8),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Kids Safe Shield', style: TextStyle(color: Colors.white, fontSize: 13)),
                      subtitle: const Text('Filters out adult & mature content', style: TextStyle(color: Colors.white54, fontSize: 11)),
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
                  ref.read(profileControllerProvider.notifier).updateProfile(
                    profile.copyWith(
                      name: _editNameController.text.trim().isEmpty ? profile.name : _editNameController.text.trim(),
                      avatarId: selectedAvatarId,
                      isKids: isKids,
                      preferredGenres: selectedGenres,
                      feedMode: feedMode,
                      maturityRating: maturityRating,
                    ),
                  );
                  Navigator.pop(ctx);
                },
                child: const Text(
                  'Save Changes',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

    @override
  Widget build(BuildContext context) {
    final profileState = ref.watch(profileControllerProvider);
    final profiles = profileState.profiles;

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
      backgroundColor: const Color(0xFF000000),
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
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0.0, -0.35),
            radius: 1.3,
            colors: [
              Color(0xFF0D2524),
              Color(0xFF091717),
              Color(0xFF040A0A),
              Color(0xFF000000),
            ],
            stops: [0.0, 0.4, 0.75, 1.0],
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  "Who's watching?",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 34,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _isManaging
                      ? 'Tap a profile to edit its settings'
                      : 'Select a profile to continue',
                  style: const TextStyle(
                    color: Colors.white60,
                    fontSize: 15,
                    fontWeight: FontWeight.w400,
                  ),
                ),
                const SizedBox(height: 52),
                Wrap(
                  spacing: 32,
                  runSpacing: 32,
                  alignment: WrapAlignment.center,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    for (int i = 0; i < profiles.length; i++)
                      _ProfileCard(
                        profile: profiles[i],
                        isPrimary: profiles[i].isPrimary || (i == 0),
                        isManaging: _isManaging,
                        onTap: () => _selectProfile(profiles[i]),
                        onLongPress: () => _showEditProfileDialog(profiles[i]),
                      ),
                    if (profiles.length < 5)
                      _AddProfileCard(onTap: _showAddProfileDialog),
                  ],
                ),
                const SizedBox(height: 48),
                OutlinedButton.icon(
                  icon: Icon(
                    _isManaging ? Icons.check_rounded : Icons.edit_rounded,
                    size: 18,
                  ),
                  label: Text(_isManaging ? 'Done' : 'Manage Profiles'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white.withValues(alpha: 0.85),
                    side: BorderSide(
                      color: Colors.white.withValues(alpha: 0.4),
                      width: 1,
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  onPressed: () => setState(() => _isManaging = !_isManaging),
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
  final bool isPrimary;
  final bool isManaging;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _ProfileCard({
    required this.profile,
    this.isPrimary = false,
    required this.isManaging,
    required this.onTap,
    required this.onLongPress,
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
        onLongPress: widget.onLongPress,
        child: AnimatedScale(
          scale: _isHovered ? 1.08 : 1.0,
          duration: const Duration(milliseconds: 180),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                alignment: Alignment.center,
                clipBehavior: Clip.none,
                children: [
                  CharacterAvatarWidget(
                    avatarId: widget.profile.avatarId,
                    size: 130,
                    square: true,
                    isSelected: _isHovered,
                    showGlow: true,
                    isPrimary: widget.isPrimary,
                  ),
                  if (widget.isManaging)
                    Container(
                      width: 130,
                      height: 130,
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(130 * 0.24),
                      ),
                      child: const Icon(
                        Icons.edit_rounded,
                        color: Colors.white,
                        size: 36,
                      ),
                    ),
                  if (widget.profile.hasPin)
                    Positioned(
                      bottom: 0,
                      left: 0,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.black87,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white24, width: 1),
                        ),
                        child: const Icon(
                          Icons.lock_rounded,
                          color: Colors.white70,
                          size: 11,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                widget.profile.name,
                style: TextStyle(
                  color: _isHovered ? Colors.white : Colors.white.withValues(alpha: 0.65),
                  fontSize: 17,
                  fontWeight: FontWeight.w500,
                  letterSpacing: -0.2,
                ),
              ),
              if (widget.isPrimary)
                const Padding(
                  padding: EdgeInsets.only(top: 3),
                  child: Text(
                    'PRIMARY',
                    style: TextStyle(
                      color: Color(0xFFF59E0B),
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.2,
                    ),
                  ),
                )
              else if (widget.profile.feedMode != 'all')
                Padding(
                  padding: const EdgeInsets.only(top: 3),
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
                width: 130,
                height: 130,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(130 * 0.24),
                  color: _isHovered
                      ? Colors.white.withValues(alpha: 0.12)
                      : const Color(0xFF22282A).withValues(alpha: 0.8),
                  border: Border.all(
                    color: _isHovered ? Colors.white : Colors.white.withValues(alpha: 0.15),
                    width: 2,
                  ),
                ),
                child: Icon(
                  Icons.add_rounded,
                  color: _isHovered ? Colors.white : Colors.white60,
                  size: 48,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'Add Profile',
                style: TextStyle(
                  color: _isHovered ? Colors.white : Colors.white.withValues(alpha: 0.65),
                  fontSize: 17,
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
    final dev = ref.watch(deviceProfileProvider).asData?.value;
    final isTv = dev?.isTv ?? false;

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
                          separatorBuilder: (_, _) => const SizedBox(width: 14),
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
