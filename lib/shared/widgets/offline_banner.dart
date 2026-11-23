import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';

/// Slim banner shown across the top of Home/Explore when the device is
/// offline, so empty shelves read as "no connection" instead of "no content".
///
/// Self-contained: listens to `connectivity_plus` directly and does an
/// initial check, since the change stream does not replay the current state.
class OfflineBanner extends StatefulWidget {
  const OfflineBanner({super.key});

  @override
  State<OfflineBanner> createState() => _OfflineBannerState();
}

class _OfflineBannerState extends State<OfflineBanner> {
  bool _offline = false;
  StreamSubscription<List<ConnectivityResult>>? _sub;

  @override
  void initState() {
    super.initState();
    _check();
    _sub = Connectivity().onConnectivityChanged.listen(_update);
  }

  Future<void> _check() async {
    try {
      final results = await Connectivity().checkConnectivity();
      _update(results);
    } catch (_) {
      // A failed check must not show a false "offline" banner.
    }
  }

  void _update(List<ConnectivityResult> results) {
    final offline = !results.any((r) => r != ConnectivityResult.none);
    if (offline != _offline && mounted) {
      setState(() => _offline = offline);
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_offline) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: const Color(0xFFB45309),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.wifi_off_rounded, color: Colors.white, size: 16),
          const SizedBox(width: 8),
          Text(
            "You're offline — some shelves can't load",
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.95),
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
