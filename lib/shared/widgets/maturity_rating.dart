import 'dart:async';

import 'package:flutter/material.dart';

/// Maps any content-certification string onto Aether's five maturity tiers.
///
/// Tier order matters: [maturityRank] compares it against a profile's limit.
/// MPAA film ratings and US TV parental ratings both collapse onto the same
/// ladder, so 'R' and 'TV-MA' gate identically.
const List<String> kMaturityTiers = ['All', '7+', '13+', '16+', '18+'];

/// Collapses a certification string ('TV-MA', 'R', 'PG-13', 'NC-17', …)
/// onto one of [kMaturityTiers]. Unknown or empty certifications map to
/// '13+' — a mid-tier default is safer than the top or bottom rung.
String maturityTier(String? certification) {
  final c = (certification ?? '').trim().toUpperCase();
  if (c.isEmpty) return '13+';
  if (c == 'G' || c == 'TV-Y' || c == 'TV-G' || c == 'ALL' || c == 'ALL AGES') {
    return 'All';
  }
  if (c == 'PG' || c == 'TV-Y7' || c == 'TV-PG' || c == '7') return '7+';
  if (c == 'PG-13' || c == 'TV-14' || c == '13' || c == '12' || c == '12A') {
    return '13+';
  }
  if (c == 'R' || c == 'TV-MA' || c == '16' || c == 'MA15+') return '16+';
  if (c == 'NC-17' || c == 'X' || c == '18' || c == '18A' || c == 'R18+') {
    return '18+';
  }
  // Anything else (unrated, foreign scales) lands mid-ladder.
  return '13+';
}

/// Numeric rank of a tier, for `contentRank > profileRank` comparisons.
int maturityRank(String tier) => kMaturityTiers.indexOf(tier).clamp(0, 4);

/// True when [certification] sits above a profile's allowed [maturityRating].
bool exceedsMaturityRating(String? certification, String maturityRating) {
  return maturityRank(maturityTier(certification)) >
      maturityRank(maturityRating);
}

/// Short audience description shown next to a rating, Netflix-style.
String maturityDescription(String? certification) {
  final tier = maturityTier(certification);
  switch (tier) {
    case 'All':
      return 'Suitable for all ages';
    case '7+':
      return 'Suitable for ages 7 and up';
    case '13+':
      return 'Parental guidance suggested — ages 13 and up';
    case '16+':
      return 'Violence, coarse language — ages 16 and up';
    default:
      return 'Mature content — violence, nudity, drugs';
  }
}

/// Netflix-style maturity badge shown when a video starts.
///
/// A white-bordered rating box ("18+") with a plain-language description
/// beside it, rendered over the picture for [visibleDuration] and then
/// fading out. Purely informational — enforcement lives in the playback
/// launcher's age gate.
class MaturityBadgeOverlay extends StatefulWidget {
  final String? certification;
  final Duration visibleDuration;

  const MaturityBadgeOverlay({
    super.key,
    required this.certification,
    this.visibleDuration = const Duration(seconds: 6),
  });

  @override
  State<MaturityBadgeOverlay> createState() => _MaturityBadgeOverlayState();
}

class _MaturityBadgeOverlayState extends State<MaturityBadgeOverlay> {
  bool _visible = true;
  Timer? _hideTimer;

  @override
  void initState() {
    super.initState();
    _hideTimer = Timer(widget.visibleDuration, () {
      if (mounted) setState(() => _visible = false);
    });
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tier = maturityTier(widget.certification);
    return Positioned(
      left: 24,
      bottom: 96,
      child: IgnorePointer(
        // Stays mounted at opacity 0 after the fade — a subtree swap would
        // skip the animation entirely.
        child: AnimatedOpacity(
          opacity: _visible ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 600),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // The bordered rating box itself.
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.white, width: 1.5),
                  borderRadius: BorderRadius.circular(3),
                  color: Colors.black.withValues(alpha: 0.35),
                ),
                child: Text(
                  tier,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                maturityDescription(widget.certification),
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.85),
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                  shadows: const [
                    Shadow(blurRadius: 8, color: Colors.black54),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
