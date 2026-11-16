import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'user_profile.dart';

/// Renders genuine vector-crafted cinematic character art and natural landscapes
/// for Aether profiles. Contains 30 iconic live-action film/series characters
/// (Baby Driver, The Expanse, Dune, Blade Runner, Drive, Heisenberg, etc.)
/// and scenic vistas.
class CharacterAvatarWidget extends StatelessWidget {
  final String avatarId;
  final double size;
  final bool isSelected;
  final bool showGlow;
  final VoidCallback? onTap;

  const CharacterAvatarWidget({
    super.key,
    required this.avatarId,
    this.size = 80,
    this.isSelected = false,
    this.showGlow = true,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final avatar = ProfileAvatars.get(avatarId);

    final widgetContent = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * 0.22),
        gradient: LinearGradient(
          colors: avatar.gradientColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: showGlow
            ? [
                BoxShadow(
                  color: avatar.glowColor.withValues(alpha: isSelected ? 0.65 : 0.25),
                  blurRadius: isSelected ? size * 0.25 : size * 0.15,
                  spreadRadius: isSelected ? 2.5 : 0.0,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
        border: Border.all(
          color: isSelected
              ? Colors.white
              : Colors.white.withValues(alpha: 0.18),
          width: isSelected ? 3.0 : 1.5,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(size * 0.22),
        child: CustomPaint(
          size: Size(size, size),
          painter: _getPainter(avatar.id),
        ),
      ),
    );

    if (onTap != null) {
      return GestureDetector(
        onTap: onTap,
        child: widgetContent,
      );
    }

    return widgetContent;
  }

  static CustomPainter _getPainter(String id) {
    switch (id) {
      // ── Live-Action Prestigious Film & Series Characters ──
      case 'avatar_baby_driver':
        return const _BabyDriverPainter();
      case 'avatar_expanse':
        return const _ExpanseRocinantePainter();
      case 'avatar_paul_atreides':
        return const _DuneAtreidesPainter();
      case 'avatar_blade_runner':
        return const _BladeRunnerKPainter();
      case 'avatar_drive':
        return const _DriveScorpionPainter();
      case 'avatar_heisenberg':
        return const _HeisenbergPainter();
      case 'avatar_shelby':
        return const _ShelbyPainter();
      case 'avatar_john_wick':
        return const _JohnWickPainter();
      case 'avatar_interstellar':
        return const _InterstellarCooperPainter();
      case 'avatar_severance':
        return const _SeveranceMarkPainter();
      case 'avatar_succession':
        return const _SuccessionLoganPainter();
      case 'avatar_saul_goodman':
        return const _SaulGoodmanPainter();
      case 'avatar_rust_cohle':
        return const _RustCohlePainter();
      case 'avatar_witcher':
        return const _WitcherPainter();
      case 'avatar_wednesday':
        return const _WednesdayPainter();
      case 'avatar_neo':
        return const _NeoPainter();
      case 'avatar_joel':
        return const _JoelMillerPainter();
      case 'avatar_beth_harmon':
        return const _BethHarmonPainter();
      case 'avatar_daenerys':
        return const _DaenerysPainter();
      case 'avatar_jon_snow':
        return const _JonSnowPainter();
      case 'avatar_tyler_durden':
        return const _TylerDurdenPainter();
      case 'avatar_bateman':
        return const _PatrickBatemanPainter();

      // ── 8 Natural & Scenic Backdrops ──
      case 'avatar_aurora':
        return const _AuroraPainter();
      case 'avatar_nebula':
        return const _NebulaPainter();
      case 'avatar_alpine':
        return const _AlpineGlacierPainter();
      case 'avatar_eclipse':
        return const _EclipsePainter();
      case 'avatar_forest':
        return const _BioluminescentForestPainter();
      case 'avatar_sahara':
        return const _SaharaDunesPainter();
      case 'avatar_pacific':
        return const _AbyssalTrenchPainter();
      case 'avatar_void':
      default:
        return const _CosmicVoidPainter();
    }
  }
}

// ══════════════════════════════════════════════════════════════════════
// ── LIVE-ACTION PRESTIGIOUS CINEMA CHARACTER PAINTERS ──
// ══════════════════════════════════════════════════════════════════════

/// 1. Baby Driver (Baby / Miles): Wayfarer shades, white earbuds, two-tone varsity jacket
class _BabyDriverPainter extends CustomPainter {
  const _BabyDriverPainter();
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;

    // Messy brown hair
    final hair = Path()..moveTo(w * 0.24, h * 0.40)..lineTo(w * 0.26, h * 0.24)..quadraticBezierTo(w * 0.5, h * 0.12, w * 0.74, h * 0.24)..lineTo(w * 0.76, h * 0.40)..close();
    canvas.drawPath(hair, Paint()..color = const Color(0xFF4A3728));

    // Youthful face
    canvas.drawOval(Rect.fromCenter(center: Offset(w * 0.5, h * 0.50), width: w * 0.38, height: h * 0.44), Paint()..color = const Color(0xFFE8CDB5));

    // Black Wayfarer Sunglasses
    final shades = Paint()..color = const Color(0xFF09090B);
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(w * 0.31, h * 0.44, w * 0.16, h * 0.11), const Radius.circular(3)), shades);
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(w * 0.53, h * 0.44, w * 0.16, h * 0.11), const Radius.circular(3)), shades);
    canvas.drawRect(Rect.fromLTWH(w * 0.46, h * 0.47, w * 0.08, h * 0.03), shades);

    // Subtle lens reflections
    canvas.drawLine(Offset(w * 0.34, h * 0.46), Offset(w * 0.42, h * 0.52), Paint()..color = Colors.white24..strokeWidth = 2);
    canvas.drawLine(Offset(w * 0.56, h * 0.46), Offset(w * 0.64, h * 0.52), Paint()..color = Colors.white24..strokeWidth = 2);

    // Iconic White Wired Earphones (looping from ears to chest)
    final wire = Paint()..color = Colors.white..strokeWidth = 1.8..style = PaintingStyle.stroke;
    canvas.drawCircle(Offset(w * 0.28, h * 0.52), 3.0, Paint()..color = Colors.white);
    canvas.drawCircle(Offset(w * 0.72, h * 0.52), 3.0, Paint()..color = Colors.white);
    final wirePath = Path()..moveTo(w * 0.28, h * 0.52)..quadraticBezierTo(w * 0.38, h * 0.72, w * 0.48, h * 0.82);
    final wirePath2 = Path()..moveTo(w * 0.72, h * 0.52)..quadraticBezierTo(w * 0.62, h * 0.72, w * 0.52, h * 0.82);
    canvas.drawPath(wirePath, wire);
    canvas.drawPath(wirePath2, wire);

    // Two-tone Varsity Bomber Jacket (Charcoal body, white sleeves)
    final jacket = Path()..moveTo(w * 0.18, h)..lineTo(w * 0.35, h * 0.75)..lineTo(w * 0.50, h * 0.85)..lineTo(w * 0.65, h * 0.75)..lineTo(w * 0.82, h)..close();
    canvas.drawPath(jacket, Paint()..color = const Color(0xFF1E293B));
    // White sleeves
    canvas.drawRect(Rect.fromLTWH(w * 0.15, h * 0.78, w * 0.18, h * 0.22), Paint()..color = const Color(0xFFE2E8F0));
    canvas.drawRect(Rect.fromLTWH(w * 0.67, h * 0.78, w * 0.18, h * 0.22), Paint()..color = const Color(0xFFE2E8F0));
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// 2. The Expanse: Rocinante mag-boots spacesuit with glowing cyan HUD visor
class _ExpanseRocinantePainter extends CustomPainter {
  const _ExpanseRocinantePainter();
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;

    // Armored Space Helmet Outer Shell (Gunmetal)
    final helmet = Path()..moveTo(w * 0.20, h * 0.76)..lineTo(w * 0.22, h * 0.32)..quadraticBezierTo(w * 0.5, h * 0.14, w * 0.78, h * 0.32)..lineTo(w * 0.80, h * 0.76)..close();
    canvas.drawPath(helmet, Paint()..color = const Color(0xFF1E293B));

    // Curved Glowing Cyan HUD Visor
    final visor = Path()..moveTo(w * 0.26, h * 0.38)..quadraticBezierTo(w * 0.5, h * 0.28, w * 0.74, h * 0.38)..lineTo(w * 0.72, h * 0.64)..quadraticBezierTo(w * 0.5, h * 0.72, w * 0.28, h * 0.64)..close();
    canvas.drawPath(visor, Paint()..color = const Color(0xFF0284C7));

    // Visor Cyan Telemetry HUD overlay
    final hud = Paint()..color = const Color(0xFF38BDF8)..strokeWidth = 1.2..style = PaintingStyle.stroke;
    canvas.drawCircle(Offset(w * 0.5, h * 0.48), w * 0.08, hud);
    canvas.drawLine(Offset(w * 0.36, h * 0.48), Offset(w * 0.42, h * 0.48), hud);
    canvas.drawLine(Offset(w * 0.58, h * 0.48), Offset(w * 0.64, h * 0.48), hud);

    // Rocinante chestplate & mag-lock collar
    final chest = Path()..moveTo(w * 0.12, h)..lineTo(w * 0.32, h * 0.78)..lineTo(w * 0.50, h * 0.86)..lineTo(w * 0.68, h * 0.78)..lineTo(w * 0.88, h)..close();
    canvas.drawPath(chest, Paint()..color = const Color(0xFF334155));

    // Orange MCRN / Roci insignia stripe
    canvas.drawRect(Rect.fromLTWH(w * 0.46, h * 0.84, w * 0.08, h * 0.16), Paint()..color = const Color(0xFFF97316));
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// 3. Dune (Paul Atreides): Fremen Stillsuit, nose clip, luminous blue Eyes of Ibad
class _DuneAtreidesPainter extends CustomPainter {
  const _DuneAtreidesPainter();
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;

    // Dark wavy windblown hair
    final hair = Path()..moveTo(w * 0.20, h * 0.44)..lineTo(w * 0.22, h * 0.20)..quadraticBezierTo(w * 0.5, h * 0.10, w * 0.78, h * 0.20)..lineTo(w * 0.80, h * 0.44)..close();
    canvas.drawPath(hair, Paint()..color = const Color(0xFF1C1917));

    // Face
    canvas.drawOval(Rect.fromCenter(center: Offset(w * 0.5, h * 0.50), width: w * 0.38, height: h * 0.44), Paint()..color = const Color(0xFFD7BAA0));

    // Piercing Glowing Blue-Within-Blue Eyes of Ibad
    final spiceEye = Paint()..color = const Color(0xFF0284C7);
    final innerPupil = Paint()..color = const Color(0xFF38BDF8);
    // Left eye
    canvas.drawCircle(Offset(w * 0.41, h * 0.46), w * 0.045, spiceEye);
    canvas.drawCircle(Offset(w * 0.41, h * 0.46), w * 0.02, innerPupil);
    // Right eye
    canvas.drawCircle(Offset(w * 0.59, h * 0.46), w * 0.045, spiceEye);
    canvas.drawCircle(Offset(w * 0.59, h * 0.46), w * 0.02, innerPupil);

    // Fremen Stillsuit Filtration Tube & Nose Plug
    final tube = Paint()..color = const Color(0xFF292524)..strokeWidth = 2.5..style = PaintingStyle.stroke;
    canvas.drawCircle(Offset(w * 0.48, h * 0.54), 2.0, Paint()..color = const Color(0xFF09090B));
    final tubePath = Path()..moveTo(w * 0.48, h * 0.54)..quadraticBezierTo(w * 0.42, h * 0.66, w * 0.34, h * 0.74);
    canvas.drawPath(tubePath, tube);

    // Stillsuit Cowl & Desert Robes
    final stillsuit = Path()..moveTo(w * 0.16, h)..lineTo(w * 0.32, h * 0.74)..lineTo(w * 0.50, h * 0.82)..lineTo(w * 0.68, h * 0.74)..lineTo(w * 0.84, h)..close();
    canvas.drawPath(stillsuit, Paint()..color = const Color(0xFF44403C));
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// 4. Blade Runner 2049 (Officer K): Fur shearling trench coat, neon rain mist
class _BladeRunnerKPainter extends CustomPainter {
  const _BladeRunnerKPainter();
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;

    // Short dark hair
    canvas.drawOval(Rect.fromCenter(center: Offset(w * 0.5, h * 0.38), width: w * 0.44, height: h * 0.34), Paint()..color = const Color(0xFF262626));

    // Chiseled face
    canvas.drawOval(Rect.fromCenter(center: Offset(w * 0.5, h * 0.52), width: w * 0.36, height: h * 0.42), Paint()..color = const Color(0xFFDFC0A7));

    // Melancholy eyes
    canvas.drawCircle(Offset(w * 0.43, h * 0.48), w * 0.03, Paint()..color = const Color(0xFF1E293B));
    canvas.drawCircle(Offset(w * 0.57, h * 0.48), w * 0.03, Paint()..color = const Color(0xFF1E293B));

    // High Fur Shearling Lapel Collar (signature heavy shearling)
    final fur = Paint()..color = const Color(0xFFD6D3D1);
    canvas.drawOval(Rect.fromCenter(center: Offset(w * 0.34, h * 0.72), width: w * 0.16, height: h * 0.22), fur);
    canvas.drawOval(Rect.fromCenter(center: Offset(w * 0.66, h * 0.72), width: w * 0.16, height: h * 0.22), fur);

    // Heavy Green-Grey Trench
    final trench = Path()..moveTo(w * 0.18, h)..lineTo(w * 0.36, h * 0.76)..lineTo(w * 0.50, h * 0.84)..lineTo(w * 0.64, h * 0.76)..lineTo(w * 0.82, h)..close();
    canvas.drawPath(trench, Paint()..color = const Color(0xFF1C1917));
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// 5. Drive (The Driver): Quilted satin jacket with golden embroidered scorpion
class _DriveScorpionPainter extends CustomPainter {
  const _DriveScorpionPainter();
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;

    // Clean-cut blonde hair
    canvas.drawOval(Rect.fromCenter(center: Offset(w * 0.5, h * 0.36), width: w * 0.42, height: h * 0.32), Paint()..color = const Color(0xFFD97706));

    // Face
    canvas.drawOval(Rect.fromCenter(center: Offset(w * 0.5, h * 0.48), width: w * 0.36, height: h * 0.40), Paint()..color = const Color(0xFFE2C9A5));

    // Aviator sunglasses
    final aviator = Paint()..color = const Color(0xFF09090B);
    canvas.drawOval(Rect.fromCenter(center: Offset(w * 0.42, h * 0.46), width: w * 0.12, height: h * 0.09), aviator);
    canvas.drawOval(Rect.fromCenter(center: Offset(w * 0.58, h * 0.46), width: w * 0.12, height: h * 0.09), aviator);

    // Quilted White/Ivory Satin Jacket Back
    final jacket = Path()..moveTo(w * 0.15, h)..lineTo(w * 0.32, h * 0.70)..lineTo(w * 0.50, h * 0.78)..lineTo(w * 0.68, h * 0.70)..lineTo(w * 0.85, h)..close();
    canvas.drawPath(jacket, Paint()..color = const Color(0xFFF8FAFC));

    // Golden Embroidered Scorpion on Jacket
    final scorp = Paint()..color = const Color(0xFFF59E0B)..strokeWidth = 2.5..style = PaintingStyle.stroke;
    // Tail arc
    final tail = Path()..moveTo(w * 0.50, h * 0.80)..quadraticBezierTo(w * 0.58, h * 0.86, w * 0.54, h * 0.94);
    canvas.drawPath(tail, scorp);
    // Body & pincers
    canvas.drawCircle(Offset(w * 0.50, h * 0.84), 3.0, Paint()..color = const Color(0xFFF59E0B));
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// 6. Heisenberg (Breaking Bad)
class _HeisenbergPainter extends CustomPainter {
  const _HeisenbergPainter();
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    canvas.drawOval(Rect.fromCenter(center: Offset(w * 0.5, h * 0.55), width: w * 0.44, height: h * 0.52), Paint()..color = const Color(0xFFE2C9A5));
    final hat = Path()..moveTo(w * 0.30, h * 0.42)..lineTo(w * 0.32, h * 0.22)..quadraticBezierTo(w * 0.5, h * 0.20, w * 0.68, h * 0.22)..lineTo(w * 0.70, h * 0.42)..close();
    canvas.drawPath(hat, Paint()..color = const Color(0xFF18181B));
    canvas.drawRect(Rect.fromLTRB(w * 0.305, h * 0.38, w * 0.695, h * 0.42), Paint()..color = const Color(0xFF047857));
    final brim = Path()..moveTo(w * 0.16, h * 0.43)..quadraticBezierTo(w * 0.5, h * 0.41, w * 0.84, h * 0.43)..quadraticBezierTo(w * 0.5, h * 0.48, w * 0.16, h * 0.43)..close();
    canvas.drawPath(brim, Paint()..color = const Color(0xFF18181B));
    final glasses = Paint()..color = const Color(0xFF09090B);
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(w * 0.32, h * 0.49, w * 0.15, h * 0.10), const Radius.circular(3)), glasses);
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(w * 0.53, h * 0.49, w * 0.15, h * 0.10), const Radius.circular(3)), glasses);
    canvas.drawRect(Rect.fromLTWH(w * 0.46, h * 0.52, w * 0.08, h * 0.03), glasses);
    final goatee = Paint()..color = const Color(0xFF5A3D28);
    canvas.drawArc(Rect.fromCenter(center: Offset(w * 0.5, h * 0.66), width: w * 0.22, height: h * 0.06), 0, math.pi, true, goatee);
    final beard = Path()..moveTo(w * 0.40, h * 0.68)..quadraticBezierTo(w * 0.5, h * 0.80, w * 0.60, h * 0.68)..quadraticBezierTo(w * 0.5, h * 0.72, w * 0.40, h * 0.68)..close();
    canvas.drawPath(beard, goatee);
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// 7. Tommy Shelby (Peaky Blinders)
class _ShelbyPainter extends CustomPainter {
  const _ShelbyPainter();
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final face = Path()..moveTo(w * 0.34, h * 0.42)..lineTo(w * 0.66, h * 0.42)..lineTo(w * 0.62, h * 0.68)..lineTo(w * 0.50, h * 0.78)..lineTo(w * 0.38, h * 0.68)..close();
    canvas.drawPath(face, Paint()..color = const Color(0xFFD7BAA0));
    final cap = Path()..moveTo(w * 0.18, h * 0.40)..quadraticBezierTo(w * 0.50, h * 0.14, w * 0.82, h * 0.40)..close();
    canvas.drawPath(cap, Paint()..color = const Color(0xFF3F3F46));
    final peak = Path()..moveTo(w * 0.26, h * 0.43)..quadraticBezierTo(w * 0.50, h * 0.41, w * 0.74, h * 0.43)..quadraticBezierTo(w * 0.50, h * 0.47, w * 0.26, h * 0.43)..close();
    canvas.drawPath(peak, Paint()..color = const Color(0xFF18181B));
    canvas.drawCircle(Offset(w * 0.43, h * 0.50), w * 0.03, Paint()..color = const Color(0xFF38BDF8));
    canvas.drawCircle(Offset(w * 0.57, h * 0.50), w * 0.03, Paint()..color = const Color(0xFF38BDF8));
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// 8. John Wick: Tailored black suit, tie, Continental gold coin
class _JohnWickPainter extends CustomPainter {
  const _JohnWickPainter();
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    // Dark shoulder-length hair parted in middle
    final hair = Path()..moveTo(w * 0.20, h * 0.75)..lineTo(w * 0.24, h * 0.28)..quadraticBezierTo(w * 0.50, h * 0.15, w * 0.76, h * 0.28)..lineTo(w * 0.80, h * 0.75)..close();
    canvas.drawPath(hair, Paint()..color = const Color(0xFF09090B));
    // Face & Neat beard
    canvas.drawOval(Rect.fromCenter(center: Offset(w * 0.5, h * 0.50), width: w * 0.36, height: h * 0.42), Paint()..color = const Color(0xFFD2B48C));
    canvas.drawArc(Rect.fromCenter(center: Offset(w * 0.5, h * 0.60), width: w * 0.26, height: h * 0.18), 0, math.pi, true, Paint()..color = const Color(0xFF18181B));
    // Black Suit & Tie
    final suit = Path()..moveTo(w * 0.16, h)..lineTo(w * 0.35, h * 0.75)..lineTo(w * 0.50, h * 0.85)..lineTo(w * 0.65, h * 0.75)..lineTo(w * 0.84, h)..close();
    canvas.drawPath(suit, Paint()..color = Colors.black);
    // White shirt collar peak
    final collar = Path()..moveTo(w * 0.45, h * 0.75)..lineTo(w * 0.50, h * 0.82)..lineTo(w * 0.55, h * 0.75)..close();
    canvas.drawPath(collar, Paint()..color = Colors.white);
    // Black Tie
    canvas.drawRect(Rect.fromLTWH(w * 0.485, h * 0.80, w * 0.03, h * 0.20), Paint()..color = Colors.black);
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// 9. Interstellar (Cooper): NASA Astronaut helmet reflecting cosmic wormhole
class _InterstellarCooperPainter extends CustomPainter {
  const _InterstellarCooperPainter();
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    // Astronaut Helmet (White composite)
    canvas.drawCircle(Offset(w * 0.5, h * 0.48), w * 0.38, Paint()..color = const Color(0xFFF1F5F9));
    // Gold Visor reflecting space
    final visor = Paint()..color = const Color(0xFFF59E0B);
    canvas.drawOval(Rect.fromCenter(center: Offset(w * 0.5, h * 0.48), width: w * 0.56, height: h * 0.46), visor);
    // Black wormhole circle reflected in center
    canvas.drawCircle(Offset(w * 0.5, h * 0.48), w * 0.14, Paint()..color = const Color(0xFF09090B));
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// 10. Severance (Mark Scout): Lumon Industries blue lanyard & keycard
class _SeveranceMarkPainter extends CustomPainter {
  const _SeveranceMarkPainter();
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    // Neat 70s office parted hair
    canvas.drawOval(Rect.fromCenter(center: Offset(w * 0.5, h * 0.38), width: w * 0.44, height: h * 0.34), Paint()..color = const Color(0xFF3B2F2F));
    // Face
    canvas.drawOval(Rect.fromCenter(center: Offset(w * 0.5, h * 0.50), width: w * 0.36, height: h * 0.42), Paint()..color = const Color(0xFFE5C4A8));
    // Lumon Blue Lanyard (ribbon around neck)
    final lanyard = Paint()..color = const Color(0xFF0284C7)..strokeWidth = 3.0..style = PaintingStyle.stroke;
    canvas.drawArc(Rect.fromCenter(center: Offset(w * 0.5, h * 0.72), width: w * 0.28, height: h * 0.30), 0, math.pi, false, lanyard);
    // Keycard badge hanging
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(w * 0.5, h * 0.90), width: w * 0.20, height: h * 0.16), const Radius.circular(2)), Paint()..color = Colors.white);
    canvas.drawRect(Rect.fromLTWH(w * 0.42, h * 0.84, w * 0.16, h * 0.03), Paint()..color = const Color(0xFF0284C7));
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// 11. Succession (Logan Roy): Cashmere sweater, Waystar baseball cap
class _SuccessionLoganPainter extends CustomPainter {
  const _SuccessionLoganPainter();
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    // Minimalist Navy Cap
    final cap = Path()..moveTo(w * 0.22, h * 0.42)..quadraticBezierTo(w * 0.5, h * 0.18, w * 0.78, h * 0.42)..close();
    canvas.drawPath(cap, Paint()..color = const Color(0xFF0F172A));
    // Cap Brim
    final brim = Path()..moveTo(w * 0.26, h * 0.44)..quadraticBezierTo(w * 0.5, h * 0.42, w * 0.74, h * 0.44)..quadraticBezierTo(w * 0.5, h * 0.48, w * 0.26, h * 0.44)..close();
    canvas.drawPath(brim, Paint()..color = const Color(0xFF0F172A));
    // Stern aged face & trimmed white beard
    canvas.drawOval(Rect.fromCenter(center: Offset(w * 0.5, h * 0.55), width: w * 0.38, height: h * 0.42), Paint()..color = const Color(0xFFDCC8B4));
    canvas.drawArc(Rect.fromCenter(center: Offset(w * 0.5, h * 0.65), width: w * 0.28, height: h * 0.18), 0, math.pi, true, Paint()..color = const Color(0xFFE2E8F0));
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// 12. Better Call Saul (Saul Goodman): Flashy colored tie & scales of justice lapel
class _SaulGoodmanPainter extends CustomPainter {
  const _SaulGoodmanPainter();
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    // Combover hair
    canvas.drawOval(Rect.fromCenter(center: Offset(w * 0.5, h * 0.38), width: w * 0.44, height: h * 0.34), Paint()..color = const Color(0xFF9A3412));
    // Face
    canvas.drawOval(Rect.fromCenter(center: Offset(w * 0.5, h * 0.50), width: w * 0.36, height: h * 0.42), Paint()..color = const Color(0xFFE8CBB3));
    // Bold Blue Suit
    final suit = Path()..moveTo(w * 0.16, h)..lineTo(w * 0.35, h * 0.75)..lineTo(w * 0.50, h * 0.85)..lineTo(w * 0.65, h * 0.75)..lineTo(w * 0.84, h)..close();
    canvas.drawPath(suit, Paint()..color = const Color(0xFF1D4ED8));
    // Flamboyant Yellow & Red Striped Tie
    canvas.drawRect(Rect.fromLTWH(w * 0.48, h * 0.80, w * 0.04, h * 0.20), Paint()..color = const Color(0xFFFBBF24));
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// 13. True Detective (Rust Cohle): Weathered brown jacket, mustache, cold stare
class _RustCohlePainter extends CustomPainter {
  const _RustCohlePainter();
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    // Longish messy brown hair
    canvas.drawOval(Rect.fromCenter(center: Offset(w * 0.5, h * 0.40), width: w * 0.46, height: h * 0.38), Paint()..color = const Color(0xFF451A03));
    // Gaunt hollow face
    canvas.drawOval(Rect.fromCenter(center: Offset(w * 0.5, h * 0.52), width: w * 0.34, height: h * 0.44), Paint()..color = const Color(0xFFD7BAA0));
    // Drooping mustache
    canvas.drawArc(Rect.fromCenter(center: Offset(w * 0.5, h * 0.64), width: w * 0.20, height: h * 0.06), 0, math.pi, true, Paint()..color = const Color(0xFF451A03));
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// 14. The Witcher (Geralt of Rivia - Henry Cavill)
class _WitcherPainter extends CustomPainter {
  const _WitcherPainter();
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final hair = Path()..moveTo(w * 0.20, h * 0.80)..lineTo(w * 0.22, h * 0.35)..quadraticBezierTo(w * 0.5, h * 0.15, w * 0.78, h * 0.35)..lineTo(w * 0.80, h * 0.80)..close();
    canvas.drawPath(hair, Paint()..color = const Color(0xFFE2E8F0));
    final face = Path()..moveTo(w * 0.30, h * 0.38)..lineTo(w * 0.70, h * 0.38)..lineTo(w * 0.65, h * 0.68)..lineTo(w * 0.50, h * 0.78)..lineTo(w * 0.35, h * 0.68)..close();
    canvas.drawPath(face, Paint()..color = const Color(0xFFDFC0A7));
    // Golden Eyes & Scar
    canvas.drawCircle(Offset(w * 0.42, h * 0.50), w * 0.03, Paint()..color = const Color(0xFFFBBF24));
    canvas.drawCircle(Offset(w * 0.58, h * 0.50), w * 0.03, Paint()..color = const Color(0xFFFBBF24));
    canvas.drawLine(Offset(w * 0.42, h * 0.42), Offset(w * 0.40, h * 0.62), Paint()..color = const Color(0xFFDC2626)..strokeWidth = 2.0);
    // Wolf medallion
    canvas.drawCircle(Offset(w * 0.5, h * 0.88), w * 0.07, Paint()..color = const Color(0xFFCBD5E1));
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// 15. Wednesday Addams
class _WednesdayPainter extends CustomPainter {
  const _WednesdayPainter();
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final hair = Paint()..color = const Color(0xFF09090B);
    canvas.drawOval(Rect.fromLTWH(w * 0.15, h * 0.35, w * 0.14, h * 0.55), hair);
    canvas.drawOval(Rect.fromLTWH(w * 0.71, h * 0.35, w * 0.14, h * 0.55), hair);
    canvas.drawOval(Rect.fromCenter(center: Offset(w * 0.5, h * 0.52), width: w * 0.40, height: h * 0.45), Paint()..color = const Color(0xFFF1E3D3));
    canvas.drawCircle(Offset(w * 0.42, h * 0.50), w * 0.03, Paint()..color = const Color(0xFF18181B));
    canvas.drawCircle(Offset(w * 0.58, h * 0.50), w * 0.03, Paint()..color = const Color(0xFF18181B));
    final collar = Paint()..color = Colors.white;
    final lCollar = Path()..moveTo(w * 0.50, h * 0.75)..lineTo(w * 0.36, h * 0.74)..lineTo(w * 0.42, h * 0.86)..close();
    final rCollar = Path()..moveTo(w * 0.50, h * 0.75)..lineTo(w * 0.64, h * 0.74)..lineTo(w * 0.58, h * 0.86)..close();
    canvas.drawPath(lCollar, collar);
    canvas.drawPath(rCollar, collar);
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// 16. Neo (The Matrix)
class _NeoPainter extends CustomPainter {
  const _NeoPainter();
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    canvas.drawOval(Rect.fromCenter(center: Offset(w * 0.5, h * 0.38), width: w * 0.46, height: h * 0.35), Paint()..color = const Color(0xFF09090B));
    final face = Path()..moveTo(w * 0.32, h * 0.38)..lineTo(w * 0.68, h * 0.38)..lineTo(w * 0.62, h * 0.70)..lineTo(w * 0.50, h * 0.80)..lineTo(w * 0.38, h * 0.70)..close();
    canvas.drawPath(face, Paint()..color = const Color(0xFFDCC8B4));
    final shades = Paint()..color = Colors.black;
    canvas.drawOval(Rect.fromCenter(center: Offset(w * 0.41, h * 0.48), width: w * 0.13, height: h * 0.06), shades);
    canvas.drawOval(Rect.fromCenter(center: Offset(w * 0.59, h * 0.48), width: w * 0.13, height: h * 0.06), shades);
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// 17. Joel Miller (The Last of Us - Pedro Pascal)
class _JoelMillerPainter extends CustomPainter {
  const _JoelMillerPainter();
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    canvas.drawOval(Rect.fromCenter(center: Offset(w * 0.5, h * 0.42), width: w * 0.48, height: h * 0.40), Paint()..color = const Color(0xFF334155));
    canvas.drawOval(Rect.fromCenter(center: Offset(w * 0.5, h * 0.54), width: w * 0.38, height: h * 0.42), Paint()..color = const Color(0xFFC7A788));
    canvas.drawArc(Rect.fromCenter(center: Offset(w * 0.5, h * 0.64), width: w * 0.36, height: h * 0.24), 0, math.pi, true, Paint()..color = const Color(0xFF475569));
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// 18. Beth Harmon (The Queen's Gambit - Anya Taylor-Joy)
class _BethHarmonPainter extends CustomPainter {
  const _BethHarmonPainter();
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final hair = Path()..moveTo(w * 0.16, h * 0.70)..lineTo(w * 0.20, h * 0.32)..quadraticBezierTo(w * 0.5, h * 0.14, w * 0.80, h * 0.32)..lineTo(w * 0.84, h * 0.70)..close();
    canvas.drawPath(hair, Paint()..color = const Color(0xFFEA580C));
    canvas.drawOval(Rect.fromCenter(center: Offset(w * 0.5, h * 0.50), width: w * 0.38, height: h * 0.44), Paint()..color = const Color(0xFFFDE8D7));
    canvas.drawCircle(Offset(w * 0.42, h * 0.48), w * 0.035, Paint()..color = const Color(0xFF10B981));
    canvas.drawCircle(Offset(w * 0.58, h * 0.48), w * 0.035, Paint()..color = const Color(0xFF10B981));
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// 19. Daenerys Targaryen (Game of Thrones)
class _DaenerysPainter extends CustomPainter {
  const _DaenerysPainter();
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final hair = Path()..moveTo(w * 0.18, h * 0.85)..lineTo(w * 0.20, h * 0.32)..quadraticBezierTo(w * 0.50, h * 0.15, w * 0.80, h * 0.32)..lineTo(w * 0.82, h * 0.85)..close();
    canvas.drawPath(hair, Paint()..color = const Color(0xFFF1F5F9));
    canvas.drawOval(Rect.fromCenter(center: Offset(w * 0.5, h * 0.50), width: w * 0.38, height: h * 0.44), Paint()..color = const Color(0xFFF3E5D8));
    canvas.drawCircle(Offset(w * 0.42, h * 0.48), w * 0.035, Paint()..color = const Color(0xFF8B5CF6));
    canvas.drawCircle(Offset(w * 0.58, h * 0.48), w * 0.035, Paint()..color = const Color(0xFF8B5CF6));
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// 20. Jon Snow (King in the North)
class _JonSnowPainter extends CustomPainter {
  const _JonSnowPainter();
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    canvas.drawOval(Rect.fromCenter(center: Offset(w * 0.5, h * 0.42), width: w * 0.50, height: h * 0.44), Paint()..color = const Color(0xFF18181B));
    canvas.drawOval(Rect.fromCenter(center: Offset(w * 0.5, h * 0.54), width: w * 0.38, height: h * 0.42), Paint()..color = const Color(0xFFD7BAA0));
    final fur = Path()..moveTo(w * 0.12, h)..lineTo(w * 0.28, h * 0.72)..lineTo(w * 0.50, h * 0.84)..lineTo(w * 0.72, h * 0.72)..lineTo(w * 0.88, h)..close();
    canvas.drawPath(fur, Paint()..color = const Color(0xFF27272A));
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// 21. Tyler Durden (Fight Club): Red leather jacket, aviators, attitude
class _TylerDurdenPainter extends CustomPainter {
  const _TylerDurdenPainter();
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    // Spiky dirty-blonde hair
    canvas.drawOval(Rect.fromCenter(center: Offset(w * 0.5, h * 0.38), width: w * 0.44, height: h * 0.36), Paint()..color = const Color(0xFFB45309));
    // Face & Red Aviators
    canvas.drawOval(Rect.fromCenter(center: Offset(w * 0.5, h * 0.50), width: w * 0.36, height: h * 0.42), Paint()..color = const Color(0xFFDFC0A7));
    final aviator = Paint()..color = const Color(0xFFDC2626);
    canvas.drawOval(Rect.fromCenter(center: Offset(w * 0.42, h * 0.47), width: w * 0.12, height: h * 0.08), aviator);
    canvas.drawOval(Rect.fromCenter(center: Offset(w * 0.58, h * 0.47), width: w * 0.12, height: h * 0.08), aviator);
    // Red Leather Jacket
    final jacket = Path()..moveTo(w * 0.16, h)..lineTo(w * 0.34, h * 0.76)..lineTo(w * 0.50, h * 0.84)..lineTo(w * 0.66, h * 0.76)..lineTo(w * 0.84, h)..close();
    canvas.drawPath(jacket, Paint()..color = const Color(0xFFB91C1C));
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// 22. Patrick Bateman (American Psycho)
class _PatrickBatemanPainter extends CustomPainter {
  const _PatrickBatemanPainter();
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final hair = Path()..moveTo(w * 0.22, h * 0.44)..lineTo(w * 0.26, h * 0.24)..quadraticBezierTo(w * 0.5, h * 0.14, w * 0.74, h * 0.24)..lineTo(w * 0.78, h * 0.44)..close();
    canvas.drawPath(hair, Paint()..color = const Color(0xFF3F2D20));
    canvas.drawOval(Rect.fromCenter(center: Offset(w * 0.5, h * 0.52), width: w * 0.38, height: h * 0.44), Paint()..color = const Color(0xFFDFC0A7));
    final suit = Path()..moveTo(w * 0.18, h)..lineTo(w * 0.36, h * 0.76)..lineTo(w * 0.50, h * 0.84)..lineTo(w * 0.64, h * 0.76)..lineTo(w * 0.82, h)..close();
    canvas.drawPath(suit, Paint()..color = const Color(0xFF0F172A));
    final tie = Path()..moveTo(w * 0.48, h * 0.76)..lineTo(w * 0.52, h * 0.76)..lineTo(w * 0.54, h)..lineTo(w * 0.46, h)..close();
    canvas.drawPath(tie, Paint()..color = const Color(0xFFDC2626));
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ══════════════════════════════════════════════════════════════════════
// ── 8 NATURAL & SCENIC LANDSCAPE VECTOR PAINTERS ──
// ══════════════════════════════════════════════════════════════════════

/// 23. Aurora Borealis
class _AuroraPainter extends CustomPainter {
  const _AuroraPainter();
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final aurora1 = Paint()..color = const Color(0xFF10B981).withValues(alpha: 0.7)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
    final wave1 = Path()..moveTo(0, h * 0.45)..quadraticBezierTo(w * 0.35, h * 0.15, w * 0.65, h * 0.35)..quadraticBezierTo(w * 0.85, h * 0.50, w, h * 0.25)..lineTo(w, h * 0.60)..close();
    canvas.drawPath(wave1, aurora1);
    final mountains = Path()..moveTo(0, h)..lineTo(w * 0.25, h * 0.65)..lineTo(w * 0.50, h * 0.80)..lineTo(w * 0.75, h * 0.60)..lineTo(w, h * 0.85)..lineTo(w, h)..close();
    canvas.drawPath(mountains, Paint()..color = const Color(0xFF042F2E));
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// 24. Deep Orion Nebula
class _NebulaPainter extends CustomPainter {
  const _NebulaPainter();
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    canvas.drawCircle(Offset(w * 0.38, h * 0.45), w * 0.35, Paint()..color = const Color(0xFFEC4899).withValues(alpha: 0.55)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 16));
    canvas.drawCircle(Offset(w * 0.65, h * 0.55), w * 0.32, Paint()..color = const Color(0xFF8B5CF6).withValues(alpha: 0.60)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18));
    canvas.drawCircle(Offset(w * 0.50, h * 0.50), w * 0.10, Paint()..color = Colors.white..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6));
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// 25. Alpine Glacier
class _AlpineGlacierPainter extends CustomPainter {
  const _AlpineGlacierPainter();
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final peak = Path()..moveTo(0, h)..lineTo(w * 0.38, h * 0.28)..lineTo(w * 0.70, h)..close();
    canvas.drawPath(peak, Paint()..color = const Color(0xFF1E3A8A));
    final snow = Path()..moveTo(w * 0.38, h * 0.28)..lineTo(w * 0.25, h * 0.46)..lineTo(w * 0.38, h * 0.42)..lineTo(w * 0.48, h * 0.50)..close();
    canvas.drawPath(snow, Paint()..color = Colors.white);
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// 26. Crimson Solar Eclipse
class _EclipsePainter extends CustomPainter {
  const _EclipsePainter();
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    canvas.drawCircle(Offset(w * 0.5, h * 0.5), w * 0.34, Paint()..color = const Color(0xFFF97316).withValues(alpha: 0.75)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14));
    canvas.drawCircle(Offset(w * 0.5, h * 0.5), w * 0.26, Paint()..color = const Color(0xFF0F172A));
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// 27. Bioluminescent Forest
class _BioluminescentForestPainter extends CustomPainter {
  const _BioluminescentForestPainter();
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final pine = Paint()..color = const Color(0xFF022C22);
    final p1 = Path()..moveTo(w * 0.3, h * 0.3)..lineTo(w * 0.15, h)..lineTo(w * 0.45, h)..close();
    final p2 = Path()..moveTo(w * 0.7, h * 0.25)..lineTo(w * 0.5, h)..lineTo(w * 0.9, h)..close();
    canvas.drawPath(p1, pine);
    canvas.drawPath(p2, pine);
    canvas.drawCircle(Offset(w * 0.45, h * 0.50), 2.5, Paint()..color = const Color(0xFF34D399));
    canvas.drawCircle(Offset(w * 0.65, h * 0.40), 2.0, Paint()..color = const Color(0xFF34D399));
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// 28. Golden Sahara Dunes
class _SaharaDunesPainter extends CustomPainter {
  const _SaharaDunesPainter();
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    canvas.drawCircle(Offset(w * 0.5, h * 0.38), w * 0.16, Paint()..color = const Color(0xFFFDE68A));
    final d1 = Path()..moveTo(0, h * 0.58)..quadraticBezierTo(w * 0.45, h * 0.45, w, h * 0.68)..lineTo(w, h)..lineTo(0, h)..close();
    canvas.drawPath(d1, Paint()..color = const Color(0xFFF59E0B));
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// 29. Abyssal Trench
class _AbyssalTrenchPainter extends CustomPainter {
  const _AbyssalTrenchPainter();
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    canvas.drawCircle(Offset(w * 0.5, h * 0.5), w * 0.20, Paint()..color = const Color(0xFF38BDF8).withValues(alpha: 0.6)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12));
    canvas.drawCircle(Offset(w * 0.5, h * 0.45), w * 0.08, Paint()..color = Colors.white);
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// 30. Cosmic Void
class _CosmicVoidPainter extends CustomPainter {
  const _CosmicVoidPainter();
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    canvas.drawCircle(Offset(w * 0.5, h * 0.5), w * 0.30, Paint()..color = const Color(0xFF6366F1).withValues(alpha: 0.6)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10)..style = PaintingStyle.stroke..strokeWidth = 3.5);
    canvas.drawCircle(Offset(w * 0.5, h * 0.5), w * 0.30, Paint()..color = Colors.white..style = PaintingStyle.stroke..strokeWidth = 1.5);
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
