import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Rangée horizontale défilante adaptée à la souris :
/// flèches ‹ › sur les côtés, glisser à la souris, et molette quand le
/// pointeur est sur une flèche.
class HScroller extends StatefulWidget {
  const HScroller({
    super.key,
    required this.height,
    required this.itemCount,
    required this.itemBuilder,
    this.spacing = 14,
    this.padding = const EdgeInsets.symmetric(vertical: 6),
  });
  final double height;
  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;
  final double spacing;
  final EdgeInsets padding;

  @override
  State<HScroller> createState() => _HScrollerState();
}

class _HScrollerState extends State<HScroller> {
  final _controller = ScrollController();
  bool _canLeft = false;
  bool _canRight = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_update);
    WidgetsBinding.instance.addPostFrameCallback((_) => _update());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _update() {
    if (!mounted || !_controller.hasClients) return;
    final p = _controller.position;
    final l = p.pixels > 1;
    final r = p.pixels < p.maxScrollExtent - 1;
    if (l != _canLeft || r != _canRight) setState(() { _canLeft = l; _canRight = r; });
  }

  void _page(int dir) {
    if (!_controller.hasClients) return;
    final p = _controller.position;
    final target = (p.pixels + dir * p.viewportDimension * 0.8).clamp(0.0, p.maxScrollExtent);
    _controller.animateTo(target, duration: const Duration(milliseconds: 350), curve: Curves.easeOutCubic);
  }

  void _wheel(PointerSignalEvent e) {
    if (e is PointerScrollEvent && _controller.hasClients) {
      final d = e.scrollDelta.dy != 0 ? e.scrollDelta.dy : e.scrollDelta.dx;
      final p = _controller.position;
      _controller.jumpTo((p.pixels + d).clamp(0.0, p.maxScrollExtent));
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: widget.height,
      child: NotificationListener<ScrollMetricsNotification>(
        onNotification: (_) { WidgetsBinding.instance.addPostFrameCallback((_) => _update()); return false; },
        child: Stack(children: [
          ScrollConfiguration(
            behavior: ScrollConfiguration.of(context).copyWith(
              dragDevices: {PointerDeviceKind.touch, PointerDeviceKind.mouse, PointerDeviceKind.trackpad, PointerDeviceKind.stylus},
            ),
            child: ListView.separated(
              controller: _controller,
              scrollDirection: Axis.horizontal,
              clipBehavior: Clip.hardEdge,
              padding: widget.padding,
              itemCount: widget.itemCount,
              separatorBuilder: (_, _) => SizedBox(width: widget.spacing),
              itemBuilder: widget.itemBuilder,
            ),
          ),
          if (_canLeft) Positioned(left: 0, top: 0, bottom: 0, child: _Arrow(left: true, onTap: () => _page(-1), onWheel: _wheel)),
          if (_canRight) Positioned(right: 0, top: 0, bottom: 0, child: _Arrow(left: false, onTap: () => _page(1), onWheel: _wheel)),
        ]),
      ),
    );
  }
}

class _Arrow extends StatelessWidget {
  const _Arrow({required this.left, required this.onTap, required this.onWheel});
  final bool left;
  final VoidCallback onTap;
  final void Function(PointerSignalEvent) onWheel;

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerSignal: onWheel,
      child: Container(
        width: 64,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: left ? Alignment.centerLeft : Alignment.centerRight,
            end: left ? Alignment.centerRight : Alignment.centerLeft,
            colors: [AppColors.background, AppColors.background.withValues(alpha: 0)],
          ),
        ),
        alignment: left ? Alignment.centerLeft : Alignment.centerRight,
        child: Material(
          color: AppColors.surfaceHigh,
          shape: const CircleBorder(side: BorderSide(color: AppColors.border)),
          child: IconButton(
            key: Key(left ? 'scroll-left' : 'scroll-right'),
            tooltip: left ? 'Précédent' : 'Suivant',
            icon: Icon(left ? Icons.chevron_left_rounded : Icons.chevron_right_rounded, color: AppColors.textPrimary),
            onPressed: onTap,
          ),
        ),
      ),
    );
  }
}
