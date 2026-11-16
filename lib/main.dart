import 'dart:async';
import 'dart:io';

import 'package:flutter_displaymode/flutter_displaymode.dart';
import 'package:flutter/material.dart';

import 'features/player/presentation/player_debug_flags.dart'
    show kPlayerRepaintRainbow;

import 'package:flutter/rendering.dart' show debugRepaintRainbowEnabled;
import 'package:flutter/services.dart'; // LogicalKeyboardKey, KeyDownEvent
import 'package:flutter/foundation.dart'; // For kReleaseMode
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';
import 'package:media_kit/media_kit.dart';

import 'core/theme/theme_provider.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_presets.dart' show AppPalette;
import 'core/theme/world_provider.dart';
import 'core/storage/storage_service.dart';
import 'core/network/doh_service.dart';

import 'package:dynamic_color/dynamic_color.dart';

import 'core/utils/app_utils.dart';
import 'core/widgets/launch_error_app.dart';
import 'shared/widgets/custom_title_bar.dart';
import 'features/extensions/providers/extensions_controller.dart';
import 'core/addons/data/addon_repository.dart';
import 'core/models/extension_update_report.dart';
import 'core/nuvio/data/nuvio_repository.dart';
import 'features/extensions/widgets/extensions_sync_bridge.dart';
import 'core/providers/update_provider.dart';
import 'core/widgets/update_dialog.dart';
import 'core/widgets/app_error_boundary.dart';
import 'core/services/download_service.dart';
import 'core/services/notification_service.dart';
import 'core/services/lan_sync_service.dart';

import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:aether/l10n/generated/app_localizations.dart';

import 'core/providers/locale_provider.dart';
import 'core/network/cloudflare_bypass.dart';
import 'core/config/tmdb_config.dart';
import 'core/providers/bootstrap_provider.dart' show quietDesktopBrightness;
import 'core/providers/device_info_provider.dart';
import 'shared/focus/app_focus.dart';
import 'shared/widgets/loading_indicator.dart';
import 'shared/widgets/tv_logical_scale.dart';
import 'core/widgets/m3_toast_overlay.dart';
import 'features/settings/presentation/general_settings_provider.dart';
import 'features/settings/presentation/full_screen_mode_provider.dart';
import 'features/player/presentation/player_platform_service.dart'
    show immersiveRouteActive;

void main() async {
  // First statement in the process: a framework or async error raised while
  // the rest of this function runs has nowhere else to go. Installs
  // FlutterError.onError, PlatformDispatcher.onError and ErrorWidget.builder -
  // see lib/core/widgets/app_error_boundary.dart.
  installGlobalErrorHandlers();

  WidgetsFlutterBinding.ensureInitialized();

  // Cap Flutter's image cache. Default is 1000 entries / 100 MB which is too
  // generous for low-RAM TVs and even most phones — decoded TMDB posters fill
  // it quickly. Tighter limits force earlier eviction and keep raster smooth.
  PaintingBinding.instance.imageCache
    ..maximumSize = 150
    ..maximumSizeBytes = 80 * 1024 * 1024; // 80 MB prevents memory exhaustion and GC stutter

  // Repaint rainbow for the flicker hunt - see player_debug_flags.dart. A
  // compile-time constant, so a normal build carries no trace of it.
  if (kPlayerRepaintRainbow) debugRepaintRainbowEnabled = true;

  // Silence the console in release mode. Diagnostics are not lost: the Talker
  // ring buffer stays enabled in release (see app_logger.dart) so /logs and its
  // export still have the run-up to a crash in them.
  if (kReleaseMode) {
    debugPrint = (String? message, {int? wrapWidth}) {};
  }

  // Initialize media_kit engine (libmpv) on Windows and Android
  if (Platform.isWindows || Platform.isAndroid) {
    MediaKit.ensureInitialized();
  }

  // Native window init (Desktop) - Run once
  if (Platform.isMacOS || Platform.isWindows || Platform.isLinux) {
    await windowManager.ensureInitialized();

    final windowOptions = WindowOptions(
      size: const Size(1280, 720),
      minimumSize: const Size(360, 640),
      center: true,
      backgroundColor: Colors.black, // Solid black prevents transparency during fullscreen transition
      skipTaskbar: false,
      titleBarStyle: Platform.isMacOS
          ? TitleBarStyle.normal
          : TitleBarStyle.hidden,
    );

    unawaited(
      windowManager.waitUntilReadyToShow(windowOptions, () async {
        await windowManager.show();
        await windowManager.focus();
      }),
    );
  }

  // AppRoot opens storage and then builds the app's ProviderScope, which the
  // rule cannot see through.
  // ignore: riverpod_lint/missing_provider_scope
  AppUtils.setRestartFunction(() => runApp(const AppRoot()));
  // ignore: riverpod_lint/missing_provider_scope
  runApp(const AppRoot());
}

class AppRoot extends StatefulWidget {
  const AppRoot({super.key});

  @override
  State<AppRoot> createState() => _AppRootState();
}

class _AppRootState extends State<AppRoot> {
  late StorageService _storageService;
  bool _initialized = false;
  Object? _error;
  StackTrace? _stackTrace;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    _storageService = StorageService();
    try {
      await Future.wait([
        _storageService.init(),
        DohService.instance.init(),
      ]);
      // Refresh-rate handoff is a platform round trip the first frame does not
      // depend on. Off the launch path, the launch screen is up that much
      // sooner and the switch happens behind it.
      if (Platform.isAndroid) {
        unawaited(
          FlutterDisplayMode.setHighRefreshRate().catchError((Object e) {
            if (kDebugMode) debugPrint("Error setting high refresh rate: $e");
          }),
        );
      }
      unawaited(LanSyncService.instance.start(_storageService));

      if (Platform.isMacOS || Platform.isWindows || Platform.isLinux) {
        final alwaysOnTop = _storageService.isAlwaysOnTop();
        await windowManager.setAlwaysOnTop(alwaysOnTop);
        // Stops screen_brightness issuing DDC/CI to the monitor on desktop.
        // Here rather than in Bootstrap: bootstrapProvider is never read by
        // anything, so Bootstrap.build() does not run in the shipped app and
        // this is the init path that does.
        //
        // Deliberately not awaited. Nothing below depends on it, it swallows
        // its own failures, and awaiting would put a plugin round-trip on the
        // launch critical path - a channel call that never returns would be an
        // app that never paints. Fire it and move on.
        unawaited(quietDesktopBrightness());
      }

      if (mounted) {
        setState(() {
          _initialized = true;
        });
        // Pre-warm the system WebView after the first frame so the initial
        // render isn't delayed. This eliminates the frame jank that occurs
        // when the CF bypass spawns its HeadlessInAppWebView cold during search.
        if (Platform.isAndroid || Platform.isIOS) {
          Future.delayed(
            const Duration(seconds: 3),
            CloudflareBypass.instance.prewarm,
          );
        }
      }
    } catch (e, stack) {
      if (mounted) {
        setState(() {
          _error = e;
          _stackTrace = stack;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return LaunchErrorApp(
        error: _error!,
        stackTrace: _stackTrace,
        storageService: _storageService,
      );
    }

    if (!_initialized) {
      return Directionality(
        textDirection: TextDirection.ltr,
        child: DynamicColorBuilder(
          builder: (lightDynamic, darkDynamic) {
            final color =
                lightDynamic?.primary ??
                const Color(0xFF6200EE); // Default Purple/Blue
            return ColoredBox(
              color: Colors.black,
              child: Center(child: AppLoadingIndicator(color: color)),
            );
          },
        ),
      );
    }

    return ProviderScope(
      // The app's root scope - below AppRoot only because storage has to open
      // first - so there is no parent scope for dependencies to describe.
      // ignore: riverpod_lint/scoped_providers_should_specify_dependencies
      overrides: [storageServiceProvider.overrideWithValue(_storageService)],
      child: const ExtensionsSyncBridge(child: MyApp()),
    );
  }
}

class MyApp extends ConsumerStatefulWidget {
  const MyApp({super.key});

  @override
  ConsumerState<MyApp> createState() => _MyAppState();
}

class _MyAppState extends ConsumerState<MyApp> {
  @override
  void initState() {
    super.initState();
    FocusManager.instance.addEarlyKeyEventHandler(_handleEarlyKeyEvent);
    // Brings back the ten-foot layout if the last session was left in it.
    // Applied here rather than in `main` because it reads through a provider,
    // which needs the scope this widget sits inside.
    ref.read(fullScreenModeProvider.notifier).initialize();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(downloadServiceProvider).init();
      unawaited(_loadInstalledExtensions());
      _checkAppUpdates();
      unawaited(_checkExtensionsUpdates());
    });
  }

  @override
  void dispose() {
    FocusManager.instance.removeEarlyKeyEventHandler(_handleEarlyKeyEvent);
    super.dispose();
  }

  KeyEventResult _handleEarlyKeyEvent(KeyEvent event) {
    if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.f11) {
      _toggleFullscreen();
      return KeyEventResult.handled;
    }

    final primaryFocus = FocusManager.instance.primaryFocus;
    if (primaryFocus == null) {
      return KeyEventResult.ignored;
    }

    final context = primaryFocus.context;
    if (context == null || !context.mounted) {
      return KeyEventResult.ignored;
    }

    final renderObject = context.findRenderObject();
    if (renderObject == null) {
      return KeyEventResult.ignored;
    }

    RenderObject? current = renderObject;
    bool isLaidOut = true;
    while (current != null) {
      if (current is RenderBox && !current.hasSize) {
        isLaidOut = false;
        break;
      }
      final parent = current.parent;
      if (parent is RenderObject) {
        current = parent;
      } else {
        break;
      }
    }

    if (!isLaidOut) {
      if (kDebugMode) {
        debugPrint(
          '[FocusGuard] Consumed key event ${event.logicalKey.keyLabel} because primary focus context or its ancestor is not laid out.',
        );
      }
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  Future<void> _checkAppUpdates() async {
    if (kDebugMode) {
      debugPrint('[Lifecycle] Starting _checkAppUpdates after 5s delay...');
    }
    await Future<void>.delayed(const Duration(seconds: 5));
    if (!mounted) {
      if (kDebugMode) {
        debugPrint('[Lifecycle] _checkAppUpdates aborted: MyApp unmounted');
      }
      return;
    }

    try {
      final controller = ref.read(updateControllerProvider.notifier);
      await controller.checkForUpdates();
    } catch (e) {
      if (kDebugMode) {
        debugPrint("[Lifecycle] App update trigger failed: $e");
      }
    }
  }

  /// Reads the plugins the user already has on disk into
  /// [ExtensionsController], on every launch, before anything asks for a
  /// stream provider.
  ///
  /// Local disk only: no repository manifest is fetched here. Discovering
  /// *newer* versions is [_checkExtensionsUpdates]'s job, and it waits for the
  /// launch to finish first. Loading what is already installed must not wait
  /// on the network at all. The installed inventory is the only thing that
  /// ever populates [ExtensionManager] - `ExtensionsSyncBridge` listens for it
  /// to change and syncs it across - and with it empty `getAllProviders()` is
  /// empty, so search finds nothing, the details screen offers no sources, and
  /// the home screen's active-provider resolution never completes: it spins
  /// forever waiting for a sync that cannot arrive. Tying this to a
  /// repository answering would strand exactly the users who already have
  /// plugins installed, whenever that repository is slow or unreachable.
  Future<void> _loadInstalledExtensions() async {
    try {
      await ref
          .read(extensionsControllerProvider.notifier)
          .loadInstalledPlugins();
    } catch (e) {
      if (kDebugMode) debugPrint('Installed extension load failed: $e');
    }
  }

  /// How long the extension update check waits after the first frame.
  ///
  /// It used to run *in* that first post-frame callback: one HTTP round trip
  /// per repository, then a download and install of every outdated plugin,
  /// then a QuickJS precompile - in the same seconds the home screen is
  /// fetching and decoding posters. On a 2016-era Android TV stick that is the
  /// first scroll of the session. Nothing downstream of this check is on
  /// screen, so it waits until the launch is over rather than racing it.
  static const Duration _extensionsCheckDelay = Duration(seconds: 15);

  /// Brings every extension system up to date in the background - Aether
  /// plugins, Nuvio scrapers and Stremio add-ons - and says what changed:
  /// what was updated, which repositories a followed collection brought in,
  /// and which plugins appeared in a repository.
  ///
  /// Every launch, on any connection. Extensions scrape sites that change
  /// under them, and the app's core job - finding something to play - runs on
  /// them, so a stale one is the difference between a title playing and not.
  /// The three run side by side, each on its own, so one that fails does not
  /// hold the others back.
  Future<void> _checkExtensionsUpdates() async {
    await Future<void>.delayed(_extensionsCheckDelay);
    if (!mounted) return;

    final reports = await Future.wait(<Future<ExtensionUpdateReport>>[
      _updating(
        'Aether plugins',
        () => ref.read(extensionsControllerProvider.notifier).autoUpdate(),
      ),
      _updating(
        'Nuvio scrapers',
        () => ref.read(nuvioRepositoryProvider.notifier).autoUpdate(),
      ),
      _updating(
        'Stremio add-ons',
        () async => ExtensionUpdateReport(
          updated: await ref
              .read(addonRepositoryProvider.notifier)
              .autoUpdate(),
        ),
      ),
    ]);
    final report = ExtensionUpdateReport.merge(reports);
    if (report.isEmpty || !mounted) return;
    _announceExtensionUpdates(report);
  }

  /// One extension system's pass, with a failure read as "nothing changed".
  static Future<ExtensionUpdateReport> _updating(
    String what,
    Future<ExtensionUpdateReport> Function() update,
  ) async {
    try {
      return await update();
    } catch (e) {
      if (kDebugMode) debugPrint('Updating $what failed: $e');
      return const ExtensionUpdateReport();
    }
  }

  /// A toast per kind of news - see [ExtensionUpdateReport.toasts]. Nothing
  /// to act on: updates are installed, repositories added, and new plugins
  /// wait on the Extensions screen.
  ///
  /// Reads its strings off the *router's* context: this State sits above
  /// `MaterialApp`, so its own context has no `Localizations` ancestor. If the
  /// navigator is not up yet there is no toast; the work is done either way.
  void _announceExtensionUpdates(ExtensionUpdateReport report) {
    final router = ref.read(appRouterProvider);
    final navContext = router.routerDelegate.navigatorKey.currentContext;
    if (navContext == null || !navContext.mounted) return;
    final l10n = AppLocalizations.of(navContext);
    if (l10n == null) return;

    final notifications = ref.read(notificationServiceProvider);
    for (final toast in report.toasts(l10n)) {
      notifications.showToast(
        title: toast.title,
        message: toast.message,
        type: ToastType.extension,
        icon: Icons.extension_rounded,
      );
    }
  }

  Future<void> _toggleFullscreen() async {
    if (!(Platform.isMacOS || Platform.isWindows || Platform.isLinux)) return;
    try {
      final isFull = await windowManager.isFullScreen();
      await windowManager.setFullScreen(!isFull);
    } catch (e) {
      if (kDebugMode) debugPrint('_toggleFullscreen: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(appThemeModeProvider);
    final customization = ref.watch(themeCustomizationProvider);
    // Which world the shell is on. Written by AppScaffold from the branch and
    // read here so the whole MaterialApp - dialogs and sheets included -
    // carries the world's surfaces rather than only the branch subtree.
    final world = ref.watch(appWorldProvider);
    final appRouter = ref.watch(appRouterProvider);
    final locale = ref.watch(localeProvider);
    final profileAsync = ref.watch(deviceProfileProvider);

    // Mirror the resolved device profile into TmdbConfig's static cache so
    // pure-utility URL builders (AppImageFallbacks, TmdbDetails ctor) pick
    // TV / desktop-class image sizes once the async profile resolves.
    // Until then they fall back to the mobile defaults — a few cold-start
    // frames may use w1280 backdrops on TV before snapping to original.
    ref.listen<AsyncValue<DeviceProfile>>(deviceProfileProvider, (prev, next) {
      final value = next.value;
      if (value != null) TmdbConfig.setProfile(value);
    });

    return DynamicColorBuilder(
      builder: (lightDynamic, darkDynamic) {
        // A wallpaper only speaks for the dynamic palette. Picking a seed says
        // "generate from this instead", so the platform scheme is dropped
        // rather than blended with it.
        final dynamicPalette = customization.palette == AppPalette.dynamic;
        final lightScheme = dynamicPalette ? lightDynamic : null;
        final darkScheme = dynamicPalette ? darkDynamic : null;

        final materialApp = MaterialApp.router(
          scaffoldMessengerKey: ref
              .read(notificationServiceProvider)
              .messengerKey,
          title: 'Aether',
          debugShowCheckedModeBanner: false,
          themeMode: themeMode,
          theme: AppTheme.createLightTheme(
            lightScheme,
            palette: customization.palette,
            surface: customization.surface,
            backdrop: customization.backdrop,
            world: world,
          ),
          darkTheme: AppTheme.createDarkTheme(
            darkScheme,
            palette: customization.palette,
            surface: customization.surface,
            backdrop: customization.backdrop,
            world: world,
          ),
          routerConfig: appRouter,
          locale: locale,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (context, child) {
            Widget result = child!;

            // A television reports about 960 dp of width whatever its panel
            // is, so the same layout that breathes on a laptop is drawn at
            // twice the relative size on a set. [TvLogicalScale] hands the
            // tree more logical pixels and scales the result back up to fill
            // the screen; it steps aside on the player, whose video is a
            // platform view and has to be laid out at the panel's own
            // resolution. See that file for what this replaced and why the
            // old `devicePixelRatio: 1.0` never did it.
            final profile = profileAsync.asData?.value;
            result = TvLogicalScale(
              enabled: profile?.isTv == true,
              router: appRouter,
              child: result,
            );

            if (!kIsWeb &&
                (Platform.isWindows || Platform.isMacOS || Platform.isLinux)) {
              final isMac = Platform.isMacOS;
              if (!isMac) {
                result = Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned.fill(child: result),
                    const Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      child: CustomTitleBar(),
                    ),
                  ],
                );
              }
            }

            // Both of these stand down over the player, and both need the
            // router to know it, so they sit together here - inside
            // `MaterialApp.router`'s builder, i.e. around the Navigator that
            // builds the player route.
            result = UpdatePromptHost(child: M3ToastOverlay(child: result));

            // Outermost, so every focus indicator in the app - the browsing
            // UI, the player chrome, dialogs and the toast host alike - reads
            // one answer to "is anyone driving this with a remote or a
            // keyboard right now". See `shared/focus/app_focus.dart`.
            //
            // A television shows focus from the first frame; anything else
            // waits for a key. See the scope for the rule.
            return FocusVisibilityScope(
              television: profile?.isTv == true,
              child: result,
            );
          },
        );

        Widget rootWidget = materialApp;

        if (Platform.isMacOS) {
          final alwaysOnTop = ref.watch(
            generalSettingsProvider.select((s) => s.alwaysOnTop),
          );
          rootWidget = PlatformMenuBar(
            menus: <PlatformMenuItem>[
              PlatformMenu(
                label: 'Aether',
                menus: <PlatformMenuItem>[
                  if (PlatformProvidedMenuItem.hasMenu(
                    PlatformProvidedMenuItemType.about,
                  ))
                    const PlatformProvidedMenuItem(
                      type: PlatformProvidedMenuItemType.about,
                    ),
                  const PlatformProvidedMenuItem(
                    type: PlatformProvidedMenuItemType.quit,
                  ),
                ],
              ),
              PlatformMenu(
                label: 'Edit',
                menus: <PlatformMenuItem>[
                  PlatformMenuItem(
                    label: 'Undo',
                    shortcut: const SingleActivator(
                      LogicalKeyboardKey.keyZ,
                      meta: true,
                    ),
                    onSelected: () {},
                  ),
                  PlatformMenuItem(
                    label: 'Redo',
                    shortcut: const SingleActivator(
                      LogicalKeyboardKey.keyZ,
                      meta: true,
                      shift: true,
                    ),
                    onSelected: () {},
                  ),
                  const PlatformMenuItemGroup(
                    members: <PlatformMenuItem>[
                      PlatformMenuItem(
                        label: 'Cut',
                        shortcut: SingleActivator(
                          LogicalKeyboardKey.keyX,
                          meta: true,
                        ),
                        onSelected: null,
                      ),
                      PlatformMenuItem(
                        label: 'Copy',
                        shortcut: SingleActivator(
                          LogicalKeyboardKey.keyC,
                          meta: true,
                        ),
                        onSelected: null,
                      ),
                      PlatformMenuItem(
                        label: 'Paste',
                        shortcut: SingleActivator(
                          LogicalKeyboardKey.keyV,
                          meta: true,
                        ),
                        onSelected: null,
                      ),
                      PlatformMenuItem(
                        label: 'Select All',
                        shortcut: SingleActivator(
                          LogicalKeyboardKey.keyA,
                          meta: true,
                        ),
                        onSelected: null,
                      ),
                    ],
                  ),
                ],
              ),
              PlatformMenu(
                label: 'Window',
                menus: <PlatformMenuItem>[
                  const PlatformProvidedMenuItem(
                    type: PlatformProvidedMenuItemType.minimizeWindow,
                  ),
                  const PlatformProvidedMenuItem(
                    type: PlatformProvidedMenuItemType.zoomWindow,
                  ),
                  PlatformMenuItem(
                    label: alwaysOnTop ? 'Disable Stay on Top' : 'Stay on Top',
                    shortcut: const SingleActivator(
                      LogicalKeyboardKey.keyT,
                      meta: true,
                      control: true,
                    ),
                    onSelected: () async {
                      final nextVal = !alwaysOnTop;
                      await ref
                          .read(generalSettingsProvider.notifier)
                          .setAlwaysOnTop(nextVal);
                      await windowManager.setAlwaysOnTop(nextVal);
                    },
                  ),
                ],
              ),
            ],
            child: rootWidget,
          );
        }

        return rootWidget;
      },
    );
  }
}

