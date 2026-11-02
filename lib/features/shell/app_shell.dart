import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_router.dart';
import '../../core/theme/app_theme.dart';

/// Structure principale : menu latéral + contenu.
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
    final expanded = _expanded && width > 900;
    return Scaffold(
      body: Row(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            width: expanded ? 240 : 84,
            decoration: const BoxDecoration(
              color: AppColors.surface,
              border: Border(right: BorderSide(color: AppColors.border)),
            ),
            child: FocusTraversalGroup(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _Logo(expanded: expanded, onToggle: () => setState(() => _expanded = !_expanded)),
                  const SizedBox(height: 12),
                  for (final d in destinations)
                    if (d.path != '/settings')
                      _NavItem(
                        destination: d,
                        selected: widget.location == d.path,
                        expanded: expanded,
                      ),
                  const Spacer(),
                  _NavItem(
                    destination: destinations.last,
                    selected: widget.location == '/settings',
                    expanded: expanded,
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
          Expanded(child: FocusTraversalGroup(child: widget.child)),
        ],
      ),
    );
  }
}

class _Logo extends StatelessWidget {
  const _Logo({required this.expanded, required this.onToggle});
  final bool expanded;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 24, 12, 8),
      child: Row(
        children: [
          InkWell(
            onTap: onToggle,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                gradient: AppColors.accentGradient,
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: Alignment.center,
              child: const Text('Z',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Colors.black)),
            ),
          ),
          if (expanded) ...[
            const SizedBox(width: 12),
            const Expanded(
              child: Text.rich(
                TextSpan(children: [
                  TextSpan(text: 'ZELVORA', style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: 2)),
                  TextSpan(text: ' TV', style: TextStyle(color: AppColors.accent, fontWeight: FontWeight.w800)),
                ]),
                style: TextStyle(fontSize: 18),
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
    final color = active ? AppColors.accent : (highlight ? AppColors.textPrimary : AppColors.textSecondary);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      child: Tooltip(
        message: widget.expanded ? '' : d.label,
        child: InkWell(
          onTap: () => context.go(d.path),
          onFocusChange: (f) => setState(() => _focused = f),
          onHover: (h) => setState(() => _hovered = h),
          borderRadius: BorderRadius.circular(12),
          focusColor: Colors.transparent,
          hoverColor: Colors.transparent,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: active
                  ? AppColors.accent.withValues(alpha: 0.12)
                  : (highlight ? AppColors.surfaceHigh : Colors.transparent),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _focused ? AppColors.accent : Colors.transparent,
                width: 2,
              ),
            ),
            child: Row(
              children: [
                Icon(d.icon, color: color, size: 24),
                if (widget.expanded) ...[
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(d.label,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            color: color,
                            fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                            fontSize: 15)),
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
