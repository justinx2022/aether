import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/layout_constants.dart';
import '../../../core/theme/theme_provider.dart';
import '../../../core/theme/theme_presets.dart';

import 'widgets/settings_widgets.dart';
import '../../../core/services/display_refresh_service.dart';
import '../../../shared/widgets/glass_surface.dart';
import 'widgets/settings_dialogs.dart';
import 'full_screen_mode_provider.dart';
import 'general_settings_provider.dart';
import 'app_version_provider.dart';

import 'package:skystream/l10n/generated/app_localizations.dart';

import '../../../core/providers/locale_provider.dart';
import '../../../core/providers/update_provider.dart';
import '../../../core/router/app_router.dart';
import '../../../core/widgets/update_dialog.dart';
import 'cache_provider.dart';

class SettingsScreen extends ConsumerWidget {
  final String? initialCategory;
  const SettingsScreen({super.key, this.initialCategory});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;

    final versionAsync = ref.watch(appVersionProvider);
    final themeMode = ref.watch(appThemeModeProvider);
    final generalSettings = ref.watch(generalSettingsProvider);

    final theme = Theme.of(context);
    final isWindows = theme.platform == TargetPlatform.windows;

    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(l10n.settings),
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: GlassSurface(
          borderRadius: BorderRadius.zero,
          padding: EdgeInsets.zero,
          blurSigma: isWindows ? 0 : 18,
          shadow: false,
          rimStrength: 0.35,
          fill: isWindows
              ? theme.colorScheme.surface.withValues(alpha: 0.86)
              : null,
          child: const SizedBox.expand(),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: FocusTraversalGroup(
            policy: ReadingOrderTraversalPolicy(),
            child: ListView(
              // Vertical only. SettingsGroup already insets its title and its
              // card by spacingMd, so a horizontal inset here would be paid
              // for twice and the cards would sit further in than on the
              // Accounts screen, which never added one.
              padding: EdgeInsets.only(
                top: MediaQuery.paddingOf(context).top +
                    kToolbarHeight +
                    LayoutConstants.spacingSm,
                bottom: LayoutConstants.shellBottomContentPadding(context),
              ),
              children: [
                _buildGeneralSettingsGroup(
                  context,
                  ref,
                  l10n,
                  themeMode,
                  generalSettings,
                ),
                const SizedBox(height: LayoutConstants.spacingLg),
                SettingsGroup(
                  title: l10n.extensions,
                  children: [
                    SettingsTile(
                      icon: Icons.extension_rounded,
                      title: 'SkyStream Providers',
                      subtitle: l10n.installRemoveProviders,
                      onTap: () => const ExtensionsRoute().go(context),
                    ),
                    SettingsTile(
                      icon: Icons.hub_rounded,
                      title: 'Nuvio Plugins',
                      subtitle: 'Manage and configure Nuvio scrapers',
                      isLast: true,
                      onTap: () => const NuvioPluginsRoute().go(context),
                    ),
                  ],
                ),
                const SizedBox(height: LayoutConstants.spacingLg),
                _buildAppDataSettingsGroup(context, ref, l10n),
                const SizedBox(height: LayoutConstants.spacingLg),
                _buildAboutSettingsGroup(
                  context,
                  ref,
                  l10n,
                  versionAsync,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGeneralSettingsGroup(
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
    // Only the choices that differ from what the app would do anyway are
    // named: "Dark" alone says everything there is to say until the palette
    // or surface has been moved off its default.
    final themeLabel = <String>[
      modeLabel,
      if (customization.liquidGlass) l10n.liquidGlassShort,
      if (customization.highRefreshRate) l10n.highRefreshEnabledBadge,
      if (customization.palette != AppPalette.dynamic)
        appearancePaletteLabel(customization.palette, l10n),
      if (customization.surface != AppSurfaceStyle.automatic)
        appearanceSurfaceLabel(customization.surface, l10n),
    ].join(' · ');
    return SettingsGroup(
      title: l10n.general,
      children: [
        SettingsTile(
          icon: Icons.dark_mode_rounded,
          title: l10n.appTheme,
          subtitle: themeLabel,
          onTap: () => showThemeDialog(context, ref, themeMode),
        ),
        ValueListenableBuilder<DisplayRefreshInfo?>(
          valueListenable: DisplayRefreshService.instance.infoNotifier,
          builder: (context, info, _) {
            final subtitle = customization.highRefreshRate
                ? (info != null
                      ? l10n.highRefreshStatusLabel(
                          info.badgeLabel,
                          info.maxHz.round(),
                        )
                      : l10n.highRefreshFallbackEnabled)
                : l10n.highRefreshStandardSubtitle;
            return SettingsTile(
              icon: Icons.speed_rounded,
              title: l10n.highRefreshMode,
              subtitle: subtitle,
              trailing: Switch.adaptive(
                value: customization.highRefreshRate,
                onChanged: (value) => ref
                    .read(themeCustomizationProvider.notifier)
                    .setHighRefreshRate(value),
              ),
              onTap: () => ref
                  .read(themeCustomizationProvider.notifier)
                  .setHighRefreshRate(!customization.highRefreshRate),
            );
          },
        ),
        SettingsTile(
          icon: Icons.translate_rounded,
          title: l10n.language,
          subtitle: l10n.languageName,
          onTap: () =>
              showLanguageDialog(context, ref, ref.read(localeProvider)),
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
          icon: Icons.title_rounded,
          title: l10n.titlePosition,
          subtitle: getTitlePositionLabel(generalSettings.titlePosition, l10n),
          onTap: () => showTitlePositionDialog(
            context,
            ref,
            generalSettings.titlePosition,
          ),
        ),
        // Only shown where it means something. A phone, a tablet and a
        // television are already the size they are going to be; only a
        // desktop has a window that can change.
        if (_supportsFullScreenMode(context))
          SettingsTile(
            icon: Icons.tv_rounded,
            title: l10n.fullScreenMode,
            subtitle: l10n.fullScreenModeSubtitle,
            trailing: Switch(
              value: fullScreenModeEnabled,
              onChanged: (val) =>
                  ref.read(fullScreenModeProvider.notifier).setEnabled(val),
            ),
            onTap: () => ref
                .read(fullScreenModeProvider.notifier)
                .setEnabled(!fullScreenModeEnabled),
          ),
        SettingsTile(
          icon: Icons.play_circle_outline_rounded,
          title: l10n.player,
          subtitle: 'Default player, gestures, decoding & quality',
          onTap: () => const PlayerSettingsRoute().go(context),
        ),
        SettingsTile(
          icon: Icons.psychology_rounded,
          title: 'AI Neural Engine',
          subtitle: 'Dahl autonomous healing, shaders & stream acceleration',
          onTap: () => const AiSettingsRoute().go(context),
        ),
        SettingsTile(
          icon: Icons.manage_accounts_rounded,
          title: '${l10n.accounts}, ${l10n.network} & ${l10n.downloads}',
          subtitle: 'Subtitles, tracking, network, DNS & downloads',
          isLast: true,
          onTap: () => const AccountSettingsRoute().go(context),
        ),
      ],
    );
  }

  Widget _buildAppDataSettingsGroup(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
  ) {
    return SettingsGroup(
      title: '${l10n.appData} & ${l10n.developer}',
      children: [
        if (!kIsWeb)
          SettingsTile(
            icon: Icons.cleaning_services_rounded,
            title: l10n.clearCache,
            subtitle: ref
                .watch(cacheSizeProvider)
                .when(
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

  Widget _buildAboutSettingsGroup(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
    AsyncValue<String> versionAsync,
  ) {
    final updateState = ref.watch(updateControllerProvider);
    final isCheckingUpdates = updateState is UpdateChecking;

    return SettingsGroup(
      title: l10n.about,
      children: [
        SettingsTile(
          icon: Icons.auto_awesome_rounded,
          title: 'Aether',
          subtitle: 'Celestial Streaming Experience',
          onTap: () => showDeveloperDialog(context),
        ),
        SettingsTile(
          icon: Icons.info_outline_rounded,
          title: l10n.version,
          subtitle: versionAsync.when(
            data: (v) => v,
            loading: () => l10n.loading,
            error: (err, stack) => l10n.unknown,
          ),
          trailing: const SizedBox.shrink(),
        ),
        SettingsTile(
          icon: Icons.system_update_rounded,
          title: 'Check for Updates',
          subtitle: isCheckingUpdates
              ? 'Checking GitHub releases...'
              : 'Scan for new builds and auto-update in place',
          trailing: isCheckingUpdates
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2.2),
                )
              : null,
          isLast: true,
          onTap: () async {
            if (isCheckingUpdates) return;
            final release = await ref
                .read(updateControllerProvider.notifier)
                .checkForUpdates(manual: true);
            if (!context.mounted) return;
            if (release != null) {
              await UpdateDialog.show(context, release);
            } else {
              await showDialog<void>(
                context: context,
                builder: (ctx) => AlertDialog(
                  backgroundColor: const Color(0xFF0F121C),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                    side: const BorderSide(color: Color(0xFF1E2638), width: 1),
                  ),
                  title: const Row(
                    children: [
                      Icon(Icons.check_circle_rounded, color: Color(0xFF10B981)),
                      SizedBox(width: 10),
                      Text(
                        'App Up to Date',
                        style: TextStyle(color: Colors.white, fontSize: 18),
                      ),
                    ],
                  ),
                  content: Text(
                    'You are running the latest version (${versionAsync.asData?.value ?? '2.8.1'}).\n\nWould you like to force download and reinstall the latest GitHub release?',
                    style: const TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text(
                        'OK',
                        style: TextStyle(color: Colors.white60),
                      ),
                    ),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF6366F1),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      icon: const Icon(
                        Icons.download_rounded,
                        size: 16,
                        color: Colors.white,
                      ),
                      label: const Text(
                        'Reinstall Build',
                        style: TextStyle(color: Colors.white),
                      ),
                      onPressed: () async {
                        Navigator.pop(ctx);
                        final forcedRelease = await ref
                            .read(updateControllerProvider.notifier)
                            .checkForUpdates(manual: true, force: true);
                        if (context.mounted && forcedRelease != null) {
                          await UpdateDialog.show(context, forcedRelease);
                        }
                      },
                    ),
                  ],
                ),
              );
            }
          },
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

/// Whether the full screen / windowed choice is offered at all.
///
/// It needs a window to make full screen and a form factor worth overriding,
/// which is the three desktops and nowhere else. A phone, a tablet and an
/// Android TV never see the row, so its subtitle never has to hedge about
/// devices that have no window to speak of. Read through [ThemeData.platform]
/// rather than dart:io so a test can state which device it is pretending to
/// be.
bool _supportsFullScreenMode(BuildContext context) {
  if (kIsWeb) return false;
  return switch (Theme.of(context).platform) {
    TargetPlatform.windows ||
    TargetPlatform.linux ||
    TargetPlatform.macOS => true,
    _ => false,
  };
}
