import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/layout_constants.dart';
import '../../../core/theme/theme_provider.dart';
import '../../../core/theme/theme_presets.dart';
import '../../../core/network/doh_service.dart';
import '../../../core/profile/profile_service.dart';
import '../../../core/profile/character_avatar_widget.dart';
import '../../../core/providers/update_provider.dart';
import '../../../core/widgets/update_dialog.dart';
import '../../../core/services/notification_service.dart';

import 'widgets/settings_widgets.dart';
import 'widgets/settings_dialogs.dart';
import 'widgets/subtitle_appearance_settings.dart';
import 'full_screen_mode_provider.dart';
import 'general_settings_provider.dart';
import 'player_settings_provider.dart';
import 'app_version_provider.dart';

import 'package:aether/l10n/generated/app_localizations.dart';

import '../../../core/providers/locale_provider.dart';
import '../../../core/router/app_router.dart';
import 'cache_provider.dart';
import '../../profile/presentation/profiles_screen.dart';

class SettingsScreen extends ConsumerWidget {
  final String? initialCategory;
  const SettingsScreen({super.key, this.initialCategory});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;

    final versionAsync = ref.watch(appVersionProvider);
    final themeMode = ref.watch(appThemeModeProvider);
    final generalSettings = ref.watch(generalSettingsProvider);
    final playerSettings =
        ref.watch(playerSettingsProvider).asData?.value ??
        const PlayerSettings();
    final profileState = ref.watch(profileControllerProvider);
    final updateState = ref.watch(updateControllerProvider);
    final dohState =
        ref.watch(dohSettingsProvider).asData?.value ?? const DohSettings();

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: Text(l10n.settings)),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: FocusTraversalGroup(
            policy: ReadingOrderTraversalPolicy(),
            child: ListView(
              padding: const EdgeInsets.symmetric(
                vertical: LayoutConstants.spacingSm,
              ).copyWith(
                bottom: LayoutConstants.shellBottomContentPadding(context),
              ),
              children: [
                // 1. Playback & Engine
                _buildPlaybackEngineGroup(
                  context,
                  ref,
                  l10n,
                  playerSettings,
                ),
                const SizedBox(height: LayoutConstants.spacingLg),

                // 2. Subtitles & Styling
                _buildSubtitlesStylingGroup(
                  context,
                  ref,
                  l10n,
                  playerSettings,
                ),
                const SizedBox(height: LayoutConstants.spacingLg),

                // 3. Extensions & Addons
                _buildExtensionsAddonsGroup(context, l10n),
                const SizedBox(height: LayoutConstants.spacingLg),

                // 4. Profiles & Cloud Sync
                _buildProfilesCloudSyncGroup(
                  context,
                  ref,
                  l10n,
                  generalSettings,
                  playerSettings,
                  profileState,
                ),
                const SizedBox(height: LayoutConstants.spacingLg),

                // 5. Network & Debrid
                _buildNetworkDebridGroup(
                  context,
                  ref,
                  l10n,
                  generalSettings,
                  dohState,
                ),
                const SizedBox(height: LayoutConstants.spacingLg),

                // 6. Appearance & Display
                _buildAppearanceDisplayGroup(
                  context,
                  ref,
                  l10n,
                  themeMode,
                  generalSettings,
                ),
                const SizedBox(height: LayoutConstants.spacingLg),

                // 7. Performance & Fluid Motion
                _buildPerformanceExperienceGroup(
                  context,
                  ref,
                  l10n,
                  generalSettings,
                ),
                const SizedBox(height: LayoutConstants.spacingLg),

                // 8. About & Updates
                _buildAboutUpdatesGroup(
                  context,
                  ref,
                  l10n,
                  versionAsync,
                  updateState,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // --- 1. Playback & Engine ---
  Widget _buildPlaybackEngineGroup(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
    PlayerSettings playerSettings,
  ) {
    return SettingsGroup(
      title: 'Playback & Engine',
      children: [
        SettingsTile(
          icon: Icons.smart_display_rounded,
          title: l10n.defaultPlayer,
          subtitle: getPlayerDisplayName(playerSettings.preferredPlayer, l10n),
          onTap: () => showDefaultPlayerDialog(
            context,
            ref,
            playerSettings.preferredPlayer,
          ),
        ),
        SettingsTile(
          icon: Icons.flash_on_rounded,
          title: 'Multi-Connection Speed Booster',
          subtitle: playerSettings.multiConnectionBooster
              ? 'Parallel segment prefetching active (Fast multi-stream buffering)'
              : 'Disabled (single connection download)',
          trailing: Switch(
            value: playerSettings.multiConnectionBooster,
            onChanged: (val) => ref
                .read(playerSettingsProvider.notifier)
                .setMultiConnectionBooster(val),
          ),
          onTap: () => ref
              .read(playerSettingsProvider.notifier)
              .setMultiConnectionBooster(!playerSettings.multiConnectionBooster),
        ),
        SettingsTile(
          icon: Icons.movie_filter_rounded,
          title: 'Seamless One-Click Play',
          subtitle: playerSettings.seamlessPlayback
              ? 'Dives into playback immediately from Continue Watching'
              : 'Opens details screen and provider selector first',
          trailing: Switch(
            value: playerSettings.seamlessPlayback,
            onChanged: (val) => ref
                .read(playerSettingsProvider.notifier)
                .setSeamlessPlayback(val),
          ),
          onTap: () => ref
              .read(playerSettingsProvider.notifier)
              .setSeamlessPlayback(!playerSettings.seamlessPlayback),
        ),
        SettingsTile(
          icon: Icons.blur_on_rounded,
          title: 'Stremio-style Loading Screen',
          subtitle: playerSettings.stremioLoadScreen
              ? 'Pulsating title & backdrop while resolving sources'
              : 'Classic minimal spinner',
          trailing: Switch(
            value: playerSettings.stremioLoadScreen,
            onChanged: (val) => ref
                .read(playerSettingsProvider.notifier)
                .setStremioLoadScreen(val),
          ),
          onTap: () => ref
              .read(playerSettingsProvider.notifier)
              .setStremioLoadScreen(!playerSettings.stremioLoadScreen),
        ),
        SettingsTile(
          icon: Icons.tune_rounded,
          title: 'Player Controls, Audio & Gestures',
          subtitle: 'Buffer timing, decoder, volume boost & gestures',
          onTap: () => const PlayerSettingsRoute().go(context),
        ),
        SettingsTile(
          icon: Icons.psychology_rounded,
          title: 'AI Neural Engine',
          subtitle: 'Dahl autonomous healing, shaders & stream acceleration',
          isLast: true,
          onTap: () => const AiSettingsRoute().go(context),
        ),
      ],
    );
  }

  // --- 2. Subtitles & Styling ---
  Widget _buildSubtitlesStylingGroup(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
    PlayerSettings playerSettings,
  ) {
    return SettingsGroup(
      title: 'Subtitles & Styling',
      children: [
        SettingsTile(
          icon: Icons.subtitles_rounded,
          title: l10n.subtitleDefault,
          subtitle: subtitleDefaultLabel(playerSettings.subtitleDefault, l10n),
          onTap: () => showSubtitleDefaultDialog(
            context,
            ref,
            playerSettings.subtitleDefault,
          ),
        ),
        SettingsTile(
          icon: Icons.style_rounded,
          title: 'Subtitle Appearance & Styling',
          subtitle:
              'Size ${playerSettings.subtitleSize.round()}, ${subtitleColorLabel(l10n, playerSettings.subtitleColor)}, background ${subtitleBackgroundLabel(l10n, playerSettings)}',
          onTap: () {
            showModalBottomSheet<void>(
              context: context,
              isScrollControlled: true,
              backgroundColor: Theme.of(context).scaffoldBackgroundColor,
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              builder: (ctx) => DraggableScrollableSheet(
                initialChildSize: 0.75,
                minChildSize: 0.5,
                maxChildSize: 0.95,
                expand: false,
                builder: (ctx, scrollController) => ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(
                    vertical: LayoutConstants.spacingSm,
                  ),
                  children: [
                    SubtitleAppearanceGroup(settings: playerSettings),
                  ],
                ),
              ),
            );
          },
        ),
        SettingsTile(
          icon: Icons.vpn_key_rounded,
          title: l10n.openSubtitles,
          subtitle: !playerSettings.hasOpenSubtitlesKey
              ? l10n.keyNotSet
              : (playerSettings.osUsername.isNotEmpty
                  ? l10n.loggedInAs(playerSettings.osUsername)
                  : l10n.notLoggedIn),
          onTap: () => showOpenSubtitlesAuthDialog(
            context,
            ref,
            playerSettings,
          ),
        ),
        SettingsTile(
          icon: Icons.cloud_download_rounded,
          title: 'SubDL & SubSource Accounts',
          subtitle: playerSettings.subdlApiKey.isNotEmpty ||
                  playerSettings.subsourceApiKey.isNotEmpty
              ? 'External subtitle API keys configured'
              : 'Add API keys for SubDL and SubSource',
          isLast: true,
          onTap: () => const AccountSettingsRoute().go(context),
        ),
      ],
    );
  }

  // --- 3. Extensions ---
  Widget _buildExtensionsAddonsGroup(
    BuildContext context,
    AppLocalizations l10n,
  ) {
    return SettingsGroup(
      title: 'Extensions',
      children: [
        SettingsTile(
          icon: Icons.extension_rounded,
          title: 'Aether Providers',
          subtitle: l10n.installRemoveProviders,
          isLast: true,
          onTap: () => const ExtensionsRoute().go(context),
        ),
      ],
    );
  }

  // --- 4. Profiles & Cloud Sync ---
  Widget _buildProfilesCloudSyncGroup(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
    GeneralSettings generalSettings,
    PlayerSettings playerSettings,
    ProfileState profileState,
  ) {
    final activeProfile = profileState.activeProfile;

    return SettingsGroup(
      title: 'Profiles & Cloud Sync',
      children: [
        SettingsTile(
          icon: Icons.account_circle_rounded,
          leading: activeProfile != null
              ? SizedBox(
                  width: 32,
                  height: 32,
                  child: CharacterAvatarWidget(
                    avatarId: activeProfile.avatarId,
                    size: 32,
                    showGlow: false,
                  ),
                )
              : null,
          title: 'Profiles & Persona',
          subtitle: activeProfile != null
              ? 'Active: ${activeProfile.name} • Tap to switch or edit profiles'
              : 'Tap to setup your profile',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute<void>(
              builder: (_) => const ProfilesScreen(isSwitching: true),
            ),
          ),
        ),
        SettingsTile(
          icon: Icons.history_rounded,
          title: l10n.recordWatchHistory,
          subtitle: generalSettings.watchHistoryEnabled
              ? l10n.enabled
              : l10n.disabled,
          trailing: Switch(
            value: generalSettings.watchHistoryEnabled,
            onChanged: (val) => ref
                .read(generalSettingsProvider.notifier)
                .setWatchHistoryEnabled(val),
          ),
          onTap: () => ref
              .read(generalSettingsProvider.notifier)
              .setWatchHistoryEnabled(!generalSettings.watchHistoryEnabled),
        ),
        SettingsTile(
          icon: Icons.sync_rounded,
          title: 'Local Network Watch Sync',
          subtitle: playerSettings.lanSync
              ? 'Auto-syncs watch progress across PC, TV & phone on home Wi-Fi'
              : 'Disabled',
          trailing: Switch(
            value: playerSettings.lanSync,
            onChanged: (val) =>
                ref.read(playerSettingsProvider.notifier).setLanSync(val),
          ),
          onTap: () => ref
              .read(playerSettingsProvider.notifier)
              .setLanSync(!playerSettings.lanSync),
        ),
        SettingsTile(
          icon: Icons.cloud_sync_rounded,
          title: 'Cloud Tracking & Scrobble',
          subtitle: 'Connect Trakt, Simkl, MyAnimeList & AniList accounts',
          isLast: true,
          onTap: () => const AccountSettingsRoute().go(context),
        ),
      ],
    );
  }

  // --- 5. Network & Debrid ---
  Widget _buildNetworkDebridGroup(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
    GeneralSettings generalSettings,
    DohSettings dohState,
  ) {
    return SettingsGroup(
      title: '${l10n.network} & Debrid',
      children: [
        SettingsTile(
          icon: Icons.dns_rounded,
          title: l10n.dnsOverHttps,
          subtitle: dohState.enabled
              ? '${l10n.on} (${getDohProviderLabel(dohState.provider, dohState.customUrl, l10n)})'
              : l10n.off,
          trailing: Switch(
            value: dohState.enabled,
            onChanged: (val) {
              ref.read(dohSettingsProvider.notifier).setEnabled(val);
            },
          ),
          onTap: () {
            ref
                .read(dohSettingsProvider.notifier)
                .setEnabled(!dohState.enabled);
          },
        ),
        if (dohState.enabled)
          SettingsTile(
            icon: Icons.cloud_rounded,
            title: l10n.dohProvider,
            subtitle: getDohProviderLabel(
              dohState.provider,
              dohState.customUrl,
              l10n,
            ),
            onTap: () => showDohProviderDialog(context, ref),
          ),
        SettingsTile(
          icon: Icons.alt_route_rounded,
          title: l10n.githubProxy,
          subtitle: l10n.githubProxySubtitle,
          trailing: Switch(
            value: generalSettings.githubProxyEnabled,
            onChanged: (val) {
              ref
                  .read(generalSettingsProvider.notifier)
                  .setGithubProxyEnabled(val);
            },
          ),
          onTap: () {
            ref.read(generalSettingsProvider.notifier).setGithubProxyEnabled(
                  !generalSettings.githubProxyEnabled,
                );
          },
        ),
        SettingsTile(
          icon: Icons.download_rounded,
          title: l10n.downloads,
          subtitle:
              '${generalSettings.downloadDirectory ?? "System Downloads/Aether"} • ${generalSettings.downloadConcurrency} parallel',
          onTap: () => showDownloadLocationDialog(
            context,
            ref,
            generalSettings,
          ),
        ),
        SettingsTile(
          icon: Icons.integration_instructions_rounded,
          title: 'Integrations & Metadata',
          subtitle: 'TMDB API key, AnimeSkip & IntroDB skip segments',
          isLast: true,
          onTap: () => const AccountSettingsRoute().go(context),
        ),
      ],
    );
  }

  // --- 6. Appearance & Display ---
  Widget _buildAppearanceDisplayGroup(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
    ThemeMode themeMode,
    GeneralSettings generalSettings,
  ) {
    final fullScreenModeEnabled = ref.watch(fullScreenModeProvider);
    final customization = ref.watch(themeCustomizationProvider);
    final modeLabel = themeMode == ThemeMode.system
        ? l10n.system
        : (themeMode == ThemeMode.dark ? l10n.dark : l10n.light);

    final themeLabel = <String>[
      modeLabel,
      if (customization.palette != AppPalette.dynamic)
        appearancePaletteLabel(customization.palette, l10n),
      if (customization.surface != AppSurfaceStyle.automatic)
        appearanceSurfaceLabel(customization.surface, l10n),
    ].join(' · ');

    final supportsFullScreen = _supportsFullScreenMode(context);

    return SettingsGroup(
      title: 'Appearance & Display',
      children: [
        SettingsTile(
          icon: Icons.dark_mode_rounded,
          title: l10n.appTheme,
          subtitle: themeLabel,
          onTap: () => showThemeDialog(context, ref, themeMode),
        ),
        SettingsTile(
          icon: Icons.translate_rounded,
          title: l10n.language,
          subtitle: l10n.languageName,
          onTap: () => showLanguageDialog(
            context,
            ref,
            ref.read(localeProvider),
          ),
        ),
        SettingsTile(
          icon: Icons.home_rounded,
          title: l10n.defaultHomeScreen,
          subtitle: getHomeScreenLabel(generalSettings.defaultHomeScreen, l10n),
          onTap: () => showDefaultHomeScreenDialog(
            context,
            ref,
            generalSettings.defaultHomeScreen,
          ),
        ),
        SettingsTile(
          icon: Icons.title_rounded,
          title: l10n.titlePosition,
          subtitle: getTitlePositionLabel(generalSettings.titlePosition, l10n),
          isLast: !supportsFullScreen,
          onTap: () => showTitlePositionDialog(
            context,
            ref,
            generalSettings.titlePosition,
          ),
        ),
        if (supportsFullScreen)
          SettingsTile(
            icon: Icons.tv_rounded,
            title: l10n.fullScreenMode,
            subtitle: l10n.fullScreenModeSubtitle,
            isLast: true,
            trailing: Switch(
              value: fullScreenModeEnabled,
              onChanged: (val) =>
                  ref.read(fullScreenModeProvider.notifier).setEnabled(val),
            ),
            onTap: () => ref
                .read(fullScreenModeProvider.notifier)
                .setEnabled(!fullScreenModeEnabled),
          ),
      ],
    );
  }

  // --- 7. Performance & Fluid Motion ---
  Widget _buildPerformanceExperienceGroup(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
    GeneralSettings generalSettings,
  ) {
    return SettingsGroup(
      title: 'Performance & Fluid Motion',
      children: [
        SettingsTile(
          icon: Icons.speed_rounded,
          title: 'Ultra-Fluid 120Hz Motion',
          subtitle: generalSettings.ultraFluidMotion
              ? 'ProMotion high-refresh pacing & inertial spring scroll physics enabled'
              : 'Standard frame pacing',
          trailing: Switch(
            value: generalSettings.ultraFluidMotion,
            onChanged: (val) => ref
                .read(generalSettingsProvider.notifier)
                .setUltraFluidMotion(val),
          ),
          onTap: () => ref
              .read(generalSettingsProvider.notifier)
              .setUltraFluidMotion(!generalSettings.ultraFluidMotion),
        ),
        SettingsTile(
          icon: Icons.auto_awesome_rounded,
          title: 'Ambient Specular Glass Aura',
          subtitle: generalSettings.ambientGlassAura
              ? 'iOS 27-style rim highlights & glass depth with zero compositor lag'
              : 'Solid matte high-contrast surfaces',
          trailing: Switch(
            value: generalSettings.ambientGlassAura,
            onChanged: (val) => ref
                .read(generalSettingsProvider.notifier)
                .setAmbientGlassAura(val),
          ),
          onTap: () => ref
              .read(generalSettingsProvider.notifier)
              .setAmbientGlassAura(!generalSettings.ambientGlassAura),
        ),
        SettingsTile(
          icon: Icons.bolt_rounded,
          title: 'Predictive Artwork Pre-warming',
          subtitle: generalSettings.predictivePrewarm
              ? 'Pre-caches next-view posters in memory for instant pop-in-free browsing'
              : 'Lazy load on viewport entry only',
          trailing: Switch(
            value: generalSettings.predictivePrewarm,
            onChanged: (val) => ref
                .read(generalSettingsProvider.notifier)
                .setPredictivePrewarm(val),
          ),
          onTap: () => ref
              .read(generalSettingsProvider.notifier)
              .setPredictivePrewarm(!generalSettings.predictivePrewarm),
        ),
        SettingsTile(
          icon: Icons.manage_search_rounded,
          title: 'Typo-Tolerant Smart Search',
          subtitle: generalSettings.smartFuzzySearch
              ? 'Damerau-Levenshtein typo forgiveness and case-insensitive matching'
              : 'Strict literal substring matching only',
          isLast: true,
          trailing: Switch(
            value: generalSettings.smartFuzzySearch,
            onChanged: (val) => ref
                .read(generalSettingsProvider.notifier)
                .setSmartFuzzySearch(val),
          ),
          onTap: () => ref
              .read(generalSettingsProvider.notifier)
              .setSmartFuzzySearch(!generalSettings.smartFuzzySearch),
        ),
      ],
    );
  }

  // --- 8. About & Updates ---
  Widget _buildAboutUpdatesGroup(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
    AsyncValue<String> versionAsync,
    UpdateState updateState,
  ) {
    return SettingsGroup(
      title: '${l10n.about} & Updates',
      children: [
        SettingsTile(
          icon: Icons.auto_awesome_rounded,
          title: 'Aether v1.0.0',
          subtitle: 'Celestial Streaming Experience',
          onTap: () => showDeveloperDialog(context),
        ),
        SettingsTile(
          icon: Icons.system_update_rounded,
          title: 'Check for Updates',
          subtitle: switch (updateState) {
            UpdateChecking() => 'Checking GitHub for releases...',
            UpdateAvailable(:final release) =>
              'New version ${release.tagName} available! Tap to install',
            UpdateDownloading(:final progress) =>
              'Downloading update: ${(progress * 100).toStringAsFixed(0)}%',
            UpdateDownloaded() => 'Update downloaded. Tap to install',
            UpdateError(:final message) => 'Error checking updates: $message',
            _ => 'Push updates directly in-app without re-downloading',
          },
          trailing: updateState is UpdateChecking
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : (updateState is UpdateAvailable
                  ? const Icon(
                      Icons.download_rounded,
                      color: Colors.greenAccent,
                    )
                  : null),
          onTap: () async {
            if (updateState is UpdateAvailable) {
              unawaited(UpdateDialog.show(
                context,
                updateState.release,
              ));
            } else {
              await ref
                  .read(updateControllerProvider.notifier)
                  .checkForUpdates();
              final updated = ref.read(updateControllerProvider);
              if (updated is UpdateAvailable && context.mounted) {
                unawaited(UpdateDialog.show(context, updated.release));
              } else if (updated is UpdateInitial && context.mounted) {
                ref.read(notificationServiceProvider).showSuccess(
                      'Aether v1.0.0 is up to date!',
                      title: 'Updates',
                      icon: Icons.check_circle_rounded,
                    );
              }
            }
          },
        ),
        if (!kIsWeb)
          SettingsTile(
            icon: Icons.cleaning_services_rounded,
            title: l10n.clearCache,
            subtitle: ref.watch(cacheSizeProvider).when(
                  data: (bytes) =>
                      '${l10n.clearCacheSubtitle} • ${_formatBytes(bytes)}',
                  loading: () => l10n.calculating,
                  error: (_, _) => l10n.clearCacheSubtitle,
                ),
            onTap: () => showClearCacheDialog(context, ref),
          ),
        SettingsTile(
          icon: Icons.restore_rounded,
          title: l10n.resetDataKeepExtensions,
          subtitle: l10n.resetDataSubtitle,
          onTap: () => showResetDataDialog(context, ref),
        ),
        SettingsTile(
          icon: Icons.delete_forever_rounded,
          title: l10n.factoryReset,
          subtitle: l10n.factoryResetSubtitle,
          onTap: () => showFactoryResetDialog(context, ref),
        ),
        SettingsTile(
          icon: Icons.developer_mode_rounded,
          title: l10n.developerOptions,
          subtitle: l10n.developerOptionsSubtitle,
          isLast: true,
          onTap: () => const DeveloperOptionsRoute().go(context),
        ),
      ],
    );
  }
}

String _formatBytes(int bytes) {
  if (bytes <= 0) return '0 B';
  const units = ['B', 'KB', 'MB', 'GB', 'TB'];
  var size = bytes.toDouble();
  var unitIndex = 0;
  while (size >= 1024 && unitIndex < units.length - 1) {
    size /= 1024;
    unitIndex++;
  }
  final value = unitIndex == 0
      ? size.toStringAsFixed(0)
      : size.toStringAsFixed(1);
  return '$value ${units[unitIndex]}';
}

bool _supportsFullScreenMode(BuildContext context) {
  if (kIsWeb) return false;
  return switch (Theme.of(context).platform) {
    TargetPlatform.windows ||
    TargetPlatform.linux ||
    TargetPlatform.macOS => true,
    _ => false,
  };
}
