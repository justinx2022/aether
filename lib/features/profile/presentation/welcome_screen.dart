import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/profile/profile_service.dart';
import '../../../core/profile/user_profile.dart';
import '../../../core/theme/app_backdrop_layer.dart';
import '../../../core/theme/theme_presets.dart';
import '../../../core/theme/theme_provider.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../settings/presentation/widgets/settings_dialogs.dart';

const _genres = <String>[
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

const _feeds = <(String, String)>[
  ('all', 'Everything'),
  ('movies', 'Movies'),
  ('series', 'Series'),
  ('anime', 'Anime'),
];

/// First-launch setup, and the same flow when a profile is added later.
///
/// Not shown when opening an existing profile. [creatingProfile] is true only
/// for the add-profile path, which returns to who's watching instead of Home.
class WelcomeScreen extends ConsumerStatefulWidget {
  final bool creatingProfile;

  const WelcomeScreen({super.key, this.creatingProfile = false});

  @override
  ConsumerState<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends ConsumerState<WelcomeScreen> {
  static const _stepCount = 4;

  final _nameController = TextEditingController();
  final _nameFocus = FocusNode();

  int _step = 0;
  int _direction = 1;
  bool _saving = false;

  String _avatarId = ProfileAvatars.all.first.id;
  String _avatarCategory = ProfileAvatars.categories.first;
  String _feedMode = 'all';
  bool _isKids = false;
  final List<String> _genresChosen = [];

  @override
  void dispose() {
    _nameController.dispose();
    _nameFocus.dispose();
    super.dispose();
  }

  void _go(int next) {
    if (next < 0 || next >= _stepCount) return;
    setState(() {
      _direction = next > _step ? 1 : -1;
      _step = next;
    });
    if (next == 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _nameFocus.requestFocus();
      });
    }
  }

  Future<void> _finish() async {
    final name = _nameController.text.trim();
    if (name.isEmpty || _saving) return;
    setState(() => _saving = true);
    final router = GoRouter.of(context);
    final navigator = Navigator.of(context);
    final created = await ref.read(profileControllerProvider.notifier).addProfile(
      name: name,
      avatarId: _avatarId,
      isKids: _isKids,
      preferredGenres: List<String>.from(_genresChosen),
      feedMode: _feedMode,
    );
    await ref.read(profileControllerProvider.notifier).selectProfile(created);
    if (!mounted) {
      if (!widget.creatingProfile) router.go('/home');
      return;
    }
    if (widget.creatingProfile && navigator.canPop()) {
      navigator.pop();
      return;
    }
    router.go('/home');
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final avatar = ProfileAvatars.get(_avatarId);
    final canContinue = _step != 0 || _nameController.text.trim().isNotEmpty;

    return Scaffold(
      backgroundColor: const Color(0xFF000000),
      body: AppBackdropLayer(
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
                child: Column(
                  children: [
                    _WelcomeHeader(
                      creatingProfile: widget.creatingProfile,
                      avatar: avatar,
                      step: _step,
                    ),
                    const SizedBox(height: 18),
                    _StepDots(count: _stepCount, index: _step),
                    const SizedBox(height: 22),
                    Expanded(
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 420),
                        switchInCurve: Curves.easeOutCubic,
                        switchOutCurve: Curves.easeInCubic,
                        transitionBuilder: (child, animation) {
                          final incoming = child.key == ValueKey(_step);
                          final begin = Offset(
                            0.08 * _direction * (incoming ? 1 : -1),
                            0,
                          );
                          return FadeTransition(
                            opacity: animation,
                            child: SlideTransition(
                              position: Tween<Offset>(
                                begin: begin,
                                end: Offset.zero,
                              ).animate(animation),
                              child: child,
                            ),
                          );
                        },
                        child: KeyedSubtree(
                          key: ValueKey(_step),
                          child: _stepBody(l10n),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        if (_step > 0)
                          TextButton(
                            onPressed: _saving ? null : () => _go(_step - 1),
                            child: const Text('Back'),
                          )
                        else
                          const SizedBox(width: 64),
                        const Spacer(),
                        FilledButton(
                          onPressed: !canContinue || _saving
                              ? null
                              : () {
                                  if (_step < _stepCount - 1) {
                                    _go(_step + 1);
                                  } else {
                                    _finish();
                                  }
                                },
                          child: Text(
                            _step == _stepCount - 1
                                ? (widget.creatingProfile
                                      ? 'Create profile'
                                      : 'Enter Aether')
                                : 'Continue',
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _stepBody(AppLocalizations? l10n) {
    return switch (_step) {
      0 => _NameStep(controller: _nameController, focusNode: _nameFocus, onChanged: () => setState(() {})),
      1 => _AvatarStep(
        category: _avatarCategory,
        avatarId: _avatarId,
        onCategory: (value) => setState(() => _avatarCategory = value),
        onAvatar: (value) => setState(() => _avatarId = value),
      ),
      2 => _PreferenceStep(
        feedMode: _feedMode,
        genres: _genresChosen,
        isKids: _isKids,
        onFeed: (value) => setState(() => _feedMode = value),
        onGenre: (genre, selected) => setState(() {
          if (selected) {
            _genresChosen.add(genre);
          } else {
            _genresChosen.remove(genre);
          }
        }),
        onKids: (value) => setState(() => _isKids = value),
      ),
      _ => _ThemeStep(l10n: l10n),
    };
  }
}

class _WelcomeHeader extends StatelessWidget {
  final bool creatingProfile;
  final ProfileAvatarInfo avatar;
  final int step;

  const _WelcomeHeader({
    required this.creatingProfile,
    required this.avatar,
    required this.step,
  });

  @override
  Widget build(BuildContext context) {
    final title = switch (step) {
      0 => creatingProfile ? 'New profile' : 'Welcome to Aether',
      1 => 'Pick a face',
      2 => 'What do you prefer?',
      _ => 'Make it yours',
    };
    final subtitle = switch (step) {
      0 => 'This is the name on your profile.',
      1 => 'Avatars are just for you. Change them any time.',
      2 => 'Home uses this for your feed and the Recommended row.',
      _ => 'Theme, colour, and the space behind the app.',
    };

    return Column(
      children: [
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.86, end: 1),
          duration: const Duration(milliseconds: 700),
          curve: Curves.easeOutBack,
          builder: (context, scale, child) => Transform.scale(scale: scale, child: child),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 350),
            curve: Curves.easeOutCubic,
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(colors: avatar.gradientColors),
              boxShadow: [
                BoxShadow(
                  color: avatar.gradientColors.first.withValues(alpha: 0.45),
                  blurRadius: 28,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Icon(step == 0 ? Icons.auto_awesome : avatar.icon, color: Colors.white),
          ),
        ),
        const SizedBox(height: 16),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 280),
          child: Text(
            title,
            key: ValueKey(title),
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.4,
            ),
          ),
        ),
        const SizedBox(height: 6),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 280),
          child: Text(
            subtitle,
            key: ValueKey(subtitle),
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white60, fontSize: 14),
          ),
        ),
      ],
    );
  }
}

class _StepDots extends StatelessWidget {
  final int count;
  final int index;

  const _StepDots({required this.count, required this.index});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < count; i++)
          AnimatedContainer(
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeOutCubic,
            margin: const EdgeInsets.symmetric(horizontal: 4),
            height: 6,
            width: i == index ? 22 : 6,
            decoration: BoxDecoration(
              color: i == index ? const Color(0xFF818CF8) : Colors.white24,
              borderRadius: BorderRadius.circular(99),
            ),
          ),
      ],
    );
  }
}

class _NameStep extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback onChanged;

  const _NameStep({
    required this.controller,
    required this.focusNode,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        autofocus: true,
        textCapitalization: TextCapitalization.words,
        textInputAction: TextInputAction.done,
        style: const TextStyle(color: Colors.white, fontSize: 20),
        cursorColor: const Color(0xFF818CF8),
        onChanged: (_) => onChanged(),
        decoration: InputDecoration(
          hintText: 'Your name',
          hintStyle: const TextStyle(color: Colors.white30),
          filled: true,
          fillColor: Colors.white.withValues(alpha: 0.06),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }
}

class _AvatarStep extends StatelessWidget {
  final String category;
  final String avatarId;
  final ValueChanged<String> onCategory;
  final ValueChanged<String> onAvatar;

  const _AvatarStep({
    required this.category,
    required this.avatarId,
    required this.onCategory,
    required this.onAvatar,
  });

  @override
  Widget build(BuildContext context) {
    final avatars = ProfileAvatars.byCategory(category);
    return ListView(
      children: [
        SizedBox(
          height: 40,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: ProfileAvatars.categories.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final cat = ProfileAvatars.categories[index];
              final selected = cat == category;
              return ChoiceChip(
                label: Text(cat),
                selected: selected,
                onSelected: (_) => onCategory(cat),
              );
            },
          ),
        ),
        const SizedBox(height: 18),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final avatar in avatars)
              _AvatarChoice(
                avatar: avatar,
                selected: avatar.id == avatarId,
                onTap: () => onAvatar(avatar.id),
              ),
          ],
        ),
      ],
    );
  }
}

class _AvatarChoice extends StatelessWidget {
  final ProfileAvatarInfo avatar;
  final bool selected;
  final VoidCallback onTap;

  const _AvatarChoice({
    required this.avatar,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedScale(
        scale: selected ? 1.08 : 1,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: avatar.gradientColors),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: selected ? Colors.white : Colors.white24,
              width: selected ? 2.5 : 1,
            ),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: avatar.gradientColors.first.withValues(alpha: 0.55),
                      blurRadius: 16,
                    ),
                  ]
                : null,
          ),
          child: Icon(avatar.icon, color: Colors.white),
        ),
      ),
    );
  }
}

class _PreferenceStep extends StatelessWidget {
  final String feedMode;
  final List<String> genres;
  final bool isKids;
  final ValueChanged<String> onFeed;
  final void Function(String genre, bool selected) onGenre;
  final ValueChanged<bool> onKids;

  const _PreferenceStep({
    required this.feedMode,
    required this.genres,
    required this.isKids,
    required this.onFeed,
    required this.onGenre,
    required this.onKids,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        const Text(
          'Watch mostly',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final feed in _feeds)
              ChoiceChip(
                label: Text(feed.$2),
                selected: feedMode == feed.$1,
                onSelected: (_) => onFeed(feed.$1),
              ),
          ],
        ),
        const SizedBox(height: 22),
        const Text(
          'Genres you like',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final genre in _genres)
              FilterChip(
                label: Text(genre),
                selected: genres.contains(genre),
                onSelected: (selected) => onGenre(genre, selected),
              ),
          ],
        ),
        const SizedBox(height: 12),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Kids profile', style: TextStyle(color: Colors.white)),
          subtitle: const Text(
            'Hides titles marked adult or with a mature rating',
            style: TextStyle(color: Colors.white54),
          ),
          value: isKids,
          onChanged: onKids,
        ),
      ],
    );
  }
}

class _ThemeStep extends ConsumerWidget {
  final AppLocalizations? l10n;

  const _ThemeStep({required this.l10n});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(appThemeModeProvider);
    final look = ref.watch(themeCustomizationProvider);
    final labels = l10n;

    return ListView(
      children: [
        const Text(
          'Brightness',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          children: [
            for (final entry in const <(ThemeMode, String)>[
              (ThemeMode.dark, 'Dark'),
              (ThemeMode.light, 'Light'),
              (ThemeMode.system, 'System'),
            ])
              ChoiceChip(
                label: Text(entry.$2),
                selected: mode == entry.$1,
                onSelected: (_) => ref
                    .read(appThemeModeProvider.notifier)
                    .setThemeMode(entry.$1),
              ),
          ],
        ),
        const SizedBox(height: 22),
        const Text(
          'Colour',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final palette in AppPalette.values)
              ChoiceChip(
                label: Text(
                  labels == null
                      ? palette.name
                      : appearancePaletteLabel(palette, labels),
                ),
                selected: look.palette == palette,
                onSelected: (_) => ref
                    .read(themeCustomizationProvider.notifier)
                    .setPalette(palette),
              ),
          ],
        ),
        const SizedBox(height: 22),
        const Text(
          'Atmosphere',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final backdrop in AppBackdrop.values)
              ChoiceChip(
                label: Text(
                  labels == null
                      ? backdrop.name
                      : appearanceBackdropLabel(backdrop, labels),
                ),
                selected: look.backdrop == backdrop,
                onSelected: (_) => ref
                    .read(themeCustomizationProvider.notifier)
                    .setBackdrop(backdrop),
              ),
          ],
        ),
      ],
    );
  }
}
