import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../theme/app_theme.dart';

/// Illustration « coucher de soleil sur les montagnes », dessinée par le code
/// (aucune image externe) : utilisée en fond des bannières.
class SunsetPainter extends CustomPainter {
  const SunsetPainter({this.sunX = 0.72});
  final double sunX;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final rect = Offset.zero & size;
    canvas.clipRect(rect);
    // Ciel : nuit en haut, braise à l'horizon.
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF1E1420), Color(0xFF5A2A1C), Color(0xFFC8612A), Color(0xFFFFB25C)],
          stops: [0, 0.32, 0.56, 0.72],
        ).createShader(rect),
    );
    // Soleil et halo.
    final sun = Offset(w * sunX, h * 0.60);
    canvas.drawCircle(
      sun,
      h * 1.1,
      Paint()
        ..shader = RadialGradient(colors: [
          const Color(0xFFFFE3B0),
          const Color(0xFFFFA040).withValues(alpha: 0.55),
          const Color(0xFFFF7A00).withValues(alpha: 0.0),
        ], stops: const [0, 0.18, 1]).createShader(Rect.fromCircle(center: sun, radius: h * 1.1)),
    );
    // Nuages étirés éclairés par le soleil.
    final rnd = math.Random(7);
    for (var i = 0; i < 14; i++) {
      final cy = h * (0.08 + rnd.nextDouble() * 0.32);
      final cx = w * rnd.nextDouble();
      final cw = w * (0.15 + rnd.nextDouble() * 0.25);
      canvas.drawOval(
        Rect.fromCenter(center: Offset(cx, cy), width: cw, height: h * 0.035),
        Paint()
          ..color = const Color(0xFFFFB070).withValues(alpha: 0.10 + rnd.nextDouble() * 0.12)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
      );
    }

    double ridgeY(double t, double base, double amp, double freq, double seed) =>
        h * base -
        h *
            amp *
            (0.62 * (1 - (math.sin(t * freq + seed)).abs()) +
                0.26 * (1 - (math.sin(t * freq * 2.13 + seed * 1.7)).abs()) +
                0.12 * (1 - (math.sin(t * freq * 5.37 + seed * 0.3)).abs()));

    void ridge(double base, double amp, double freq, double seed, Color top, Color bottom, {Color? rim, double haze = 0}) {
      final path = Path()..moveTo(0, h);
      final pts = <Offset>[];
      for (var i = 0; i <= 240; i++) {
        final x = w * i / 240;
        final p = Offset(x, ridgeY(i / 240, base, amp, freq, seed));
        pts.add(p);
        path.lineTo(p.dx, p.dy);
      }
      path
        ..lineTo(w, h)
        ..close();
      final bounds = Rect.fromLTWH(0, h * (base - amp), w, h);
      canvas.drawPath(
        path,
        Paint()..shader = LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [top, bottom]).createShader(bounds),
      );
      if (rim != null) {
        // Liseré lumineux côté soleil.
        final rimPaint = Paint()
          ..strokeWidth = 2.2
          ..style = PaintingStyle.stroke
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.5);
        for (var i = 1; i < pts.length; i++) {
          final d = (pts[i].dx - sun.dx).abs() / w;
          rimPaint.color = rim.withValues(alpha: (0.9 - d * 1.6).clamp(0.08, 0.9));
          canvas.drawLine(pts[i - 1], pts[i], rimPaint);
        }
      }
      if (haze > 0) {
        canvas.drawRect(
          Rect.fromLTWH(0, h * base - h * 0.05, w, h * 0.12),
          Paint()
            ..shader = LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.transparent, const Color(0xFFFFC890).withValues(alpha: haze), Colors.transparent],
            ).createShader(Rect.fromLTWH(0, h * base - h * 0.05, w, h * 0.12)),
        );
      }
    }

    ridge(0.66, 0.42, 3.4, 1.2, const Color(0xFF8E5A52), const Color(0xFF3A2026), rim: const Color(0xFFFFE6C8), haze: 0.18);
    ridge(0.80, 0.26, 4.6, 2.6, const Color(0xFF3E2426), const Color(0xFF1A1114), rim: const Color(0xFFFFB066));
    ridge(0.96, 0.18, 2.8, 4.1, const Color(0xFF1C1316), const Color(0xFF0A0A0D));
  }

  @override
  bool shouldRepaint(SunsetPainter old) => old.sunX != sunX;
}

/// Bannière d'en-tête de page avec illustration et fondu vers le fond.
class HeroHeader extends StatelessWidget {
  const HeroHeader({super.key, required this.height, required this.child, this.sunX = 0.72});
  final double height;
  final Widget child;
  final double sunX;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: Stack(fit: StackFit.expand, children: [
        CustomPaint(painter: SunsetPainter(sunX: sunX)),
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [Color(0xF00A0A0D), Color(0x990A0A0D), Color(0x000A0A0D)],
              stops: [0, 0.38, 0.75],
            ),
          ),
        ),
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0x000A0A0D), Color(0x000A0A0D), AppColors.background],
              stops: [0, 0.55, 1],
            ),
          ),
        ),
        child,
      ]),
    );
  }
}

/// Badge « EN DIRECT » (contour orange).
class LiveBadge extends StatelessWidget {
  const LiveBadge({super.key, this.small = false});
  final bool small;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: small ? 6 : 10, vertical: small ? 2 : 4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.accent, width: 1.2),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (!small) ...[
          const Icon(Icons.live_tv_rounded, size: 15, color: AppColors.accent),
          const SizedBox(width: 6),
        ],
        Text('EN DIRECT',
            style: TextStyle(
                color: AppColors.accent, fontWeight: FontWeight.w800, fontSize: small ? 10 : 13, letterSpacing: 0.6)),
      ]),
    );
  }
}

/// Barre en haut à droite : recherche, notifications, heure.
class TopBar extends StatelessWidget {
  const TopBar({super.key, this.onSearch});
  final VoidCallback? onSearch;

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      IconButton(
        tooltip: 'Rechercher',
        onPressed: onSearch ?? () => GoRouter.of(context).go('/search'),
        icon: const Icon(Icons.search_rounded, size: 28),
      ),
      const SizedBox(width: 8),
      const Icon(Icons.notifications_none_rounded, size: 28),
      const SizedBox(width: 24),
      const Clock(),
    ]);
  }
}

class Clock extends StatefulWidget {
  const Clock({super.key});

  @override
  State<Clock> createState() => _ClockState();
}

class _ClockState extends State<Clock> {
  late Timer _t;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    _t = Timer.periodic(const Duration(seconds: 15), (_) => setState(() => _now = DateTime.now()));
  }

  @override
  void dispose() {
    _t.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = '${_now.hour.toString().padLeft(2, '0')}:${_now.minute.toString().padLeft(2, '0')}';
    return Text(s, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700));
  }
}

/// Titre de section avec icône (« Chaînes populaires », etc.).
class SectionTitle extends StatelessWidget {
  const SectionTitle({super.key, required this.icon, required this.title, this.trailing});
  final IconData icon;
  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(children: [
        Icon(icon, size: 22, color: icon == Icons.local_fire_department_rounded ? AppColors.accent : AppColors.textPrimary),
        const SizedBox(width: 10),
        Text(title, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700)),
        const Spacer(),
        ?trailing,
      ]),
    );
  }
}

/// Icône de catégorie devinée à partir de son nom.
IconData categoryIcon(String name) {
  final n = name.toLowerCase();
  bool has(List<String> k) => k.any(n.contains);
  if (has(['sport', 'foot', 'soccer', 'bein', 'rmc sport', 'canal+ sport'])) return Icons.sports_soccer_rounded;
  if (has(['info', 'news', 'actu'])) return Icons.article_outlined;
  if (has(['enfant', 'kid', 'jeunesse', 'dessin', 'cartoon'])) return Icons.child_care_rounded;
  if (has(['film', 'cinema', 'ciné', 'movie'])) return Icons.movie_creation_outlined;
  if (has(['série', 'serie', 'series'])) return Icons.layers_outlined;
  if (has(['musi', 'music', 'radio'])) return Icons.music_note_rounded;
  if (has(['doc', 'découverte', 'decouverte', 'nature'])) return Icons.eco_outlined;
  if (has(['divert', 'entertain', 'variét'])) return Icons.theater_comedy_outlined;
  if (has(['religi'])) return Icons.church_outlined;
  return Icons.tv_rounded;
}
