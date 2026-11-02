import 'package:flutter/material.dart';

import '../../domain/channel.dart';
import '../theme/app_theme.dart';
import 'visuals.dart';

/// Logo de chaîne (image de la source) ou icône de repli.
class ChannelLogo extends StatelessWidget {
  const ChannelLogo({super.key, required this.url, this.size = 40, this.fallbackIcon = Icons.tv_rounded, this.boxed = true});
  final String? url;
  final double size;
  final IconData fallbackIcon;
  final bool boxed;

  @override
  Widget build(BuildContext context) {
    final fallback = Icon(fallbackIcon, color: Colors.white, size: size * 0.55);
    final img = url == null
        ? fallback
        : Image.network(
            url!,
            fit: BoxFit.contain,
            // Logo décodé à sa taille d'affichage (et non en pleine résolution) :
            // moins de mémoire, défilement plus fluide.
            cacheWidth: (size * MediaQuery.devicePixelRatioOf(context)).ceil(),
            errorBuilder: (_, _, _) => fallback,
          );
    if (!boxed) return SizedBox(width: size, height: size, child: img);
    return Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(size * 0.12),
      decoration: BoxDecoration(
        gradient: tileGradient('${url ?? fallbackIcon.codePoint}'),
        borderRadius: BorderRadius.circular(size * 0.22),
      ),
      child: img,
    );
  }
}

LinearGradient tileGradient(String seed) {
  final c = AppColors.tilePalette[seed.hashCode.abs() % AppColors.tilePalette.length];
  return LinearGradient(colors: c, begin: Alignment.topLeft, end: Alignment.bottomRight);
}

/// Tuile colorée « Chaînes populaires » : logo + nom.
class ChannelBrandTile extends StatefulWidget {
  const ChannelBrandTile({super.key, required this.channel, required this.onTap, this.width = 220});
  final Channel channel;
  final VoidCallback onTap;
  final double width;

  @override
  State<ChannelBrandTile> createState() => _ChannelBrandTileState();
}

class _ChannelBrandTileState extends State<ChannelBrandTile> {
  bool _active = false;

  @override
  Widget build(BuildContext context) {
    final c = widget.channel;
    return SizedBox(
      width: widget.width,
      child: InkWell(
        onTap: widget.onTap,
        onFocusChange: (f) => setState(() => _active = f),
        onHover: (h) => setState(() => _active = h),
        borderRadius: BorderRadius.circular(12),
        child: AnimatedScale(
          scale: _active ? 1.05 : 1,
          duration: const Duration(milliseconds: 150),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            height: 72,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              gradient: tileGradient(c.name),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _active ? AppColors.accent : Colors.white10, width: 2),
              boxShadow: _active ? AppColors.glow(0.4) : null,
            ),
            child: Row(children: [
              ChannelLogo(url: c.logo, size: 36, boxed: false, fallbackIcon: categoryIcon(c.group)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(c.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16, height: 1.15)),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

/// Grande carte horizontale (style « Reprendre la lecture »).
class ChannelWideCard extends StatefulWidget {
  const ChannelWideCard({super.key, required this.channel, required this.onTap, this.subtitle, this.progress});
  final Channel channel;
  final VoidCallback onTap;
  final String? subtitle;
  final double? progress;

  @override
  State<ChannelWideCard> createState() => _ChannelWideCardState();
}

class _ChannelWideCardState extends State<ChannelWideCard> {
  bool _active = false;

  @override
  Widget build(BuildContext context) {
    final c = widget.channel;
    return SizedBox(
      width: 430,
      child: InkWell(
        onTap: widget.onTap,
        onFocusChange: (f) => setState(() => _active = f),
        onHover: (h) => setState(() => _active = h),
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          height: 96,
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _active ? AppColors.accent : AppColors.border, width: 2),
            boxShadow: _active ? AppColors.glow(0.4) : null,
          ),
          clipBehavior: Clip.antiAlias,
          child: Row(children: [
            Container(
              width: 170,
              decoration: BoxDecoration(gradient: tileGradient(c.name)),
              alignment: Alignment.center,
              child: ChannelLogo(url: c.logo, size: 60, boxed: false, fallbackIcon: categoryIcon(c.group)),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(c.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Text(widget.subtitle ?? c.group,
                        maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.textSecondary)),
                    if (widget.progress != null) ...[
                      const SizedBox(height: 10),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(3),
                        child: LinearProgressIndicator(
                          value: widget.progress,
                          minHeight: 4,
                          color: AppColors.accent,
                          backgroundColor: Colors.white12,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}
