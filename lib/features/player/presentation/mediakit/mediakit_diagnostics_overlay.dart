import 'dart:ui' show FramePhase;

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

/// Live snapshot of Flutter frame timings and libmpv render statistics.
@immutable
class PlayerDiagnosticsSnapshot {
  const PlayerDiagnosticsSnapshot({
    this.buildMs = 0,
    this.rasterMs = 0,
    this.totalMs = 0,
    this.uiFps = 0,
    this.videoSync = 'audio',
    this.hwdec = '-',
    this.displayFps = '-',
    this.containerFps = '-',
    this.displaySyncActive = '-',
    this.frameDrops = '-',
    this.decoderDrops = '-',
    this.voDelayed = '-',
    this.avSync = '-',
  });

  final double buildMs;
  final double rasterMs;
  final double totalMs;
  final double uiFps;
  final String videoSync;
  final String hwdec;
  final String displayFps;
  final String containerFps;
  final String displaySyncActive;
  final String frameDrops;
  final String decoderDrops;
  final String voDelayed;
  final String avSync;

  /// Computes Flutter UI build, raster, total ms, and effective FPS from recent
  /// [FrameTiming] samples without allocating per-frame heavy objects.
  PlayerDiagnosticsSnapshot copyWithFrameTimings(List<FrameTiming> timings) {
    if (timings.isEmpty) return this;
    double buildUs = 0;
    double rasterUs = 0;
    double totalUs = 0;
    for (final t in timings) {
      buildUs += t.buildDuration.inMicroseconds;
      rasterUs += t.rasterDuration.inMicroseconds;
      totalUs += t.totalSpan.inMicroseconds;
    }
    final count = timings.length;
    final avgBuildMs = (buildUs / count) / 1000.0;
    final avgRasterMs = (rasterUs / count) / 1000.0;
    final avgTotalMs = (totalUs / count) / 1000.0;

    double fps = 0;
    if (timings.length >= 2) {
      final firstStart = timings.first.timestampInMicroseconds(
        FramePhase.vsyncStart,
      );
      final lastStart = timings.last.timestampInMicroseconds(
        FramePhase.vsyncStart,
      );
      final spanUs = lastStart - firstStart;
      if (spanUs > 0) {
        fps = ((timings.length - 1) * 1000000.0 / spanUs).clamp(0.0, 240.0);
      }
    }

    return copyWith(
      buildMs: avgBuildMs,
      rasterMs: avgRasterMs,
      totalMs: avgTotalMs,
      uiFps: fps,
    );
  }

  PlayerDiagnosticsSnapshot copyWith({
    double? buildMs,
    double? rasterMs,
    double? totalMs,
    double? uiFps,
    String? videoSync,
    String? hwdec,
    String? displayFps,
    String? containerFps,
    String? displaySyncActive,
    String? frameDrops,
    String? decoderDrops,
    String? voDelayed,
    String? avSync,
  }) => PlayerDiagnosticsSnapshot(
    buildMs: buildMs ?? this.buildMs,
    rasterMs: rasterMs ?? this.rasterMs,
    totalMs: totalMs ?? this.totalMs,
    uiFps: uiFps ?? this.uiFps,
    videoSync: videoSync ?? this.videoSync,
    hwdec: hwdec ?? this.hwdec,
    displayFps: displayFps ?? this.displayFps,
    containerFps: containerFps ?? this.containerFps,
    displaySyncActive: displaySyncActive ?? this.displaySyncActive,
    frameDrops: frameDrops ?? this.frameDrops,
    decoderDrops: decoderDrops ?? this.decoderDrops,
    voDelayed: voDelayed ?? this.voDelayed,
    avSync: avSync ?? this.avSync,
  );
}

/// Compact non-blurring HUD showing Flutter UI/Raster frame timings and mpv
/// cadence statistics for live debugging without polluting the main chrome.
class MediaKitDiagnosticsOverlay extends StatelessWidget {
  const MediaKitDiagnosticsOverlay({
    required this.snapshot,
    required this.onClose,
    this.onToggleVideoSync,
    super.key,
  });

  final ValueListenable<PlayerDiagnosticsSnapshot> snapshot;
  final VoidCallback onClose;
  final VoidCallback? onToggleVideoSync;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: ValueListenableBuilder<PlayerDiagnosticsSnapshot>(
        valueListenable: snapshot,
        builder: (context, s, _) {
          const textStyle = TextStyle(
            color: Color(0xFFE2E8F0),
            fontSize: 11,
            height: 1.35,
            fontFamily: 'monospace',
            fontFeatures: <FontFeature>[FontFeature.tabularFigures()],
          );
          return DecoratedBox(
            decoration: BoxDecoration(
              color: const Color(0xCC060912),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.16),
                width: 0.75,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(11, 8, 9, 9),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 320),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        const Icon(
                          Icons.speed_rounded,
                          size: 14,
                          color: Color(0xFF38BDF8),
                        ),
                        const SizedBox(width: 6),
                        const Expanded(
                          child: Text(
                            'Perf & MPV HUD',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        if (onToggleVideoSync != null)
                          GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: onToggleVideoSync,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.10),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                s.videoSync,
                                style: const TextStyle(
                                  color: Color(0xFF7DD3FC),
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                        const SizedBox(width: 4),
                        GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: onClose,
                          child: const Padding(
                            padding: EdgeInsets.all(2),
                            child: Icon(
                              Icons.close_rounded,
                              size: 15,
                              color: Colors.white70,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(
                      'UI FPS: ${s.uiFps.toStringAsFixed(1)} | '
                      'Build: ${s.buildMs.toStringAsFixed(1)}ms | '
                      'Raster: ${s.rasterMs.toStringAsFixed(1)}ms\n'
                      'Total frame: ${s.totalMs.toStringAsFixed(1)}ms | '
                      'hwdec: ${s.hwdec}\n'
                      'FPS disp/src: ${s.displayFps} / ${s.containerFps} '
                      '(sync: ${s.displaySyncActive})\n'
                      'Drops vo/dec/delay: ${s.frameDrops} / '
                      '${s.decoderDrops} / ${s.voDelayed}\n'
                      'A/V sync: ${s.avSync}',
                      style: textStyle,
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
