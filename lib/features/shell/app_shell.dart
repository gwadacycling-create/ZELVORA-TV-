import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_router.dart';
import '../../core/theme/app_theme.dart';
import '../update/update_banner.dart';

/// Structure principale : menu latéral (ordinateur, TV) ou barre du bas (téléphone).
class AppShell extends StatefulWidget {
  const AppShell({super.key, required this.location, required this.child});
  final String location;
  final Widget child;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  bool _expanded = true;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    if (width < 700) return _MobileShell(location: widget.location, child: widget.child);
    final expanded = _expanded && width > 1000;
    return Scaffold(
      body: Row(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            width: expanded ? 280 : 92,
            child: Stack(children: [
              const Positioned.fill(child: _SidebarBackground()),
              FocusTraversalGroup(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _Logo(expanded: expanded, onToggle: () => setState(() => _expanded = !_expanded)),
                    const SizedBox(height: 28),
                    for (final d in destinations)
                      if (d.path != '/settings')
                        _NavItem(destination: d, selected: widget.location == d.path, expanded: expanded),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 18),
                      child: Container(height: 1, color: AppColors.border),
                    ),
                    _NavItem(
                      destination: destinations.last,
                      selected: widget.location == '/settings',
                      expanded: expanded,
                    ),
                    const Spacer(),
                  ],
                ),
              ),
            ]),
          ),
          Expanded(
            child: Column(children: [
              const UpdateBanner(),
              Expanded(child: FocusTraversalGroup(child: widget.child)),
            ]),
          ),
        ],
      ),
    );
  }
}

/// Fond du menu : dégradé sombre et vague lumineuse orange en bas.
class _SidebarBackground extends StatelessWidget {
  const _SidebarBackground();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _SwooshPainter());
  }
}

class _SwooshPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF141417), Color(0xFF0E0E11)],
        ).createShader(rect),
    );
    final h = size.height, w = size.width;
    // Halo diffus en bas à gauche.
    final glowRect = Rect.fromLTWH(0, h * 0.62, w, h * 0.38);
    canvas.drawRect(
      glowRect,
      Paint()
        ..shader = RadialGradient(
          center: Alignment.bottomLeft,
          radius: 1.2,
          colors: [const Color(0xFFFF7A00).withValues(alpha: 0.22), Colors.transparent],
        ).createShader(glowRect),
    );
    // Deux courbes lumineuses fines (vague orange).
    for (final (dy, alpha, width) in [(0.0, 0.95, 2.4), (0.035, 0.45, 1.4)]) {
      final path = Path()
        ..moveTo(-10, h * (0.99 - dy))
        ..cubicTo(w * 0.25, h * (0.90 - dy), w * 0.65, h * (0.86 - dy), w * 1.1, h * (0.70 - dy));
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = width * 4
          ..color = const Color(0xFFFF7A00).withValues(alpha: alpha * 0.35)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
      );
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = width
          ..shader = LinearGradient(colors: [
            const Color(0xFFFFA940).withValues(alpha: alpha),
            const Color(0xFFFF7A00).withValues(alpha: alpha * 0.2),
          ]).createShader(Rect.fromLTWH(0, h * 0.6, w, h * 0.4)),
      );
    }
    canvas.drawLine(Offset(w - 0.5, 0), Offset(w - 0.5, h), Paint()..color = AppColors.border.withValues(alpha: 0.6));
  }

  @override
  bool shouldRepaint(_SwooshPainter old) => false;
}

class _Logo extends StatelessWidget {
  const _Logo({required this.expanded, required this.onToggle});
  final bool expanded;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 36, 12, 8),
      child: Row(
        children: [
          InkWell(
            onTap: onToggle,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFFF7A00), Color(0xFFFFA940)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: AppColors.glow(0.35),
              ),
              alignment: Alignment.center,
              child: const Text('Z', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: Colors.black)),
            ),
          ),
          if (expanded) ...[
            const SizedBox(width: 14),
            const Expanded(
              child: Text.rich(
                TextSpan(children: [
                  TextSpan(text: 'ZELVORA', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 0.5)),
                  TextSpan(text: ' TV', style: TextStyle(color: AppColors.accent, fontWeight: FontWeight.w900)),
                ]),
                style: TextStyle(fontSize: 22),
                overflow: TextOverflow.fade,
                softWrap: false,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _NavItem extends StatefulWidget {
  const _NavItem({required this.destination, required this.selected, required this.expanded});
  final NavDestination destination;
  final bool selected;
  final bool expanded;

  @override
  State<_NavItem> createState() => _NavItemState();
}

class _NavItemState extends State<_NavItem> {
  bool _focused = false;
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final d = widget.destination;
    final active = widget.selected;
    final highlight = _focused || _hovered;
    final color = active ? Colors.white : (highlight ? AppColors.textPrimary : const Color(0xFFD4D4D8));
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      child: Tooltip(
        message: widget.expanded ? '' : d.label,
        child: InkWell(
          onTap: () => context.go(d.path),
          onFocusChange: (f) => setState(() => _focused = f),
          onHover: (h) => setState(() => _hovered = h),
          borderRadius: BorderRadius.circular(14),
          focusColor: Colors.transparent,
          hoverColor: Colors.transparent,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            height: 58,
            padding: EdgeInsets.symmetric(horizontal: widget.expanded ? 18 : 0),
            decoration: BoxDecoration(
              gradient: active ? AppColors.accentGradient : null,
              color: active ? null : (highlight ? AppColors.surfaceHigh : Colors.transparent),
              borderRadius: BorderRadius.circular(14),
              boxShadow: active ? AppColors.glow() : null,
              border: Border.all(
                color: _focused ? (active ? Colors.white : AppColors.accent) : Colors.transparent,
                width: 2,
              ),
            ),
            child: Row(
              mainAxisAlignment: widget.expanded ? MainAxisAlignment.start : MainAxisAlignment.center,
              children: [
                Icon(d.icon, color: color, size: 27),
                if (widget.expanded) ...[
                  const SizedBox(width: 18),
                  Expanded(
                    child: Text(d.label,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            color: color, fontWeight: active ? FontWeight.w700 : FontWeight.w500, fontSize: 18)),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Téléphone : barre de navigation en bas (Accueil, Direct, Guide, Favoris, Réglages).
class _MobileShell extends StatelessWidget {
  const _MobileShell({required this.location, required this.child});
  final String location;
  final Widget child;

  static const _items = [
    ('/', 'Accueil', Icons.home_rounded),
    ('/live', 'Direct', Icons.live_tv_rounded),
    ('/guide', 'Guide', Icons.calendar_view_week_rounded),
    ('/favorites', 'Favoris', Icons.favorite_rounded),
    ('/settings', 'Réglages', Icons.settings_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    final index = _items.indexWhere((e) => e.$1 == location);
    return Scaffold(
      body: SafeArea(bottom: false, child: Column(children: [const UpdateBanner(), Expanded(child: child)])),
      bottomNavigationBar: NavigationBar(
        backgroundColor: AppColors.surface,
        indicatorColor: Colors.transparent,
        selectedIndex: index < 0 ? 0 : index,
        onDestinationSelected: (i) => context.go(_items[i].$1),
        destinations: [
          for (final e in _items)
            NavigationDestination(
              icon: Icon(e.$3, color: AppColors.textSecondary),
              selectedIcon: Icon(e.$3, color: AppColors.accent),
              label: e.$2,
            ),
        ],
      ),
    );
  }
}
