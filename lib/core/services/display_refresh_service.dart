import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_displaymode/flutter_displaymode.dart';

@immutable
class DisplayRefreshInfo {
  const DisplayRefreshInfo({
    required this.currentHz,
    required this.maxHz,
    required this.supportedHz,
    required this.highRefreshEnabled,
  });

  final double currentHz;
  final double maxHz;
  final List<double> supportedHz;
  final bool highRefreshEnabled;

  String get badgeLabel {
    final hz = currentHz > 0 ? currentHz.round() : maxHz.round();
    if (hz <= 0) return highRefreshEnabled ? '120Hz' : 'Auto';
    return '${hz}Hz';
  }

  bool get supportsHighRefresh => maxHz >= 90 || supportedHz.any((h) => h >= 90);
}

/// Coordinates native high-refresh-rate locks (120Hz/144Hz+) on Android and Windows
/// and maintains live display capability telemetry for Settings UI.
class DisplayRefreshService {
  DisplayRefreshService._();

  static final DisplayRefreshService instance = DisplayRefreshService._();

  static const MethodChannel _channel = MethodChannel('dev.akash.skystream/display');

  final ValueNotifier<DisplayRefreshInfo?> infoNotifier = ValueNotifier<DisplayRefreshInfo?>(null);

  bool _enabled = true;

  bool get isEnabled => _enabled;

  Future<DisplayRefreshInfo> apply(bool enabled) async {
    _enabled = enabled;
    DisplayRefreshInfo? info;

    if (!kIsWeb && (Platform.isAndroid || Platform.isWindows)) {
      try {
        final raw = await _channel.invokeMapMethod<String, dynamic>(
          'setHighRefreshRate',
          <String, dynamic>{'enabled': enabled},
        );
        if (raw != null) {
          info = _parseInfoMap(raw, fallbackEnabled: enabled);
        }
      } on MissingPluginException {
        // Fallback below if running in unit tests or without host channel.
      } catch (e) {
        if (kDebugMode) {
          debugPrint('DisplayRefreshService native apply error: $e');
        }
      }

      if (Platform.isAndroid) {
        try {
          if (enabled) {
            await FlutterDisplayMode.setHighRefreshRate();
          } else {
            final modes = await FlutterDisplayMode.supported;
            DisplayMode? sixtyHz;
            for (final mode in modes) {
              if (mode.refreshRate >= 59 && mode.refreshRate <= 61) {
                sixtyHz = mode;
                break;
              }
            }
            if (sixtyHz != null) {
              await FlutterDisplayMode.setPreferredMode(sixtyHz);
            }
          }
          if (info == null) {
            final active = await FlutterDisplayMode.active;
            final modes = await FlutterDisplayMode.supported;
            final rates = modes.map((m) => m.refreshRate).toSet().toList()..sort();
            final maxHz = rates.isNotEmpty ? rates.last : active.refreshRate;
            info = DisplayRefreshInfo(
              currentHz: active.refreshRate,
              maxHz: maxHz,
              supportedHz: rates,
              highRefreshEnabled: enabled,
            );
          }
        } catch (e) {
          if (kDebugMode) {
            debugPrint('FlutterDisplayMode fallback error: $e');
          }
        }
      }
    }

    info ??= await refreshInfo();
    infoNotifier.value = info;
    return info;
  }

  Future<DisplayRefreshInfo> refreshInfo() async {
    if (!kIsWeb && (Platform.isAndroid || Platform.isWindows)) {
      try {
        final raw = await _channel.invokeMapMethod<String, dynamic>('getDisplayInfo');
        if (raw != null) {
          final parsed = _parseInfoMap(raw, fallbackEnabled: _enabled);
          infoNotifier.value = parsed;
          return parsed;
        }
      } on MissingPluginException {
        // Fall back to Flutter's display telemetry.
      } catch (e) {
        if (kDebugMode) {
          debugPrint('DisplayRefreshService getDisplayInfo error: $e');
        }
      }
    }

    final displays = PlatformDispatcher.instance.displays;
    final hz = displays.isNotEmpty ? displays.first.refreshRate : 60.0;
    final cleanHz = hz > 0 ? hz : 60.0;
    final info = DisplayRefreshInfo(
      currentHz: cleanHz,
      maxHz: cleanHz,
      supportedHz: <double>[cleanHz],
      highRefreshEnabled: _enabled,
    );
    infoNotifier.value = info;
    return info;
  }

  DisplayRefreshInfo _parseInfoMap(
    Map<String, dynamic> map, {
    required bool fallbackEnabled,
  }) {
    final current = (map['currentHz'] as num?)?.toDouble() ?? 60.0;
    final maxHz = (map['maxHz'] as num?)?.toDouble() ?? current;
    final rawSupported = map['supportedHz'];
    final supported = <double>[];
    if (rawSupported is List) {
      for (final item in rawSupported) {
        if (item is num) {
          supported.add(item.toDouble());
        }
      }
    }
    if (supported.isEmpty && current > 0) {
      supported.add(current);
    }
    supported.sort();
    return DisplayRefreshInfo(
      currentHz: current,
      maxHz: maxHz,
      supportedHz: supported,
      highRefreshEnabled: (map['enabled'] as bool?) ?? fallbackEnabled,
    );
  }
}
