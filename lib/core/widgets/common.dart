import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../theme/app_theme.dart';

/// Gabarit commun des pages : titre + contenu défilant.
class PageScaffold extends StatelessWidget {
  const PageScaffold({super.key, required this.title, this.subtitle, required this.children});
  final String title;
  final String? subtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(40, 36, 40, 40),
      children: [
        Text(title, style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w800)),
        if (subtitle != null) ...[
          const SizedBox(height: 6),
          Text(subtitle!, style: const TextStyle(color: AppColors.textSecondary, fontSize: 15)),
        ],
        const SizedBox(height: 28),
        ...children,
      ],
    );
  }
}

/// Écran vide affiché tant qu'aucune source n'est configurée.
class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.icon, required this.title, required this.message, this.showAddSource = true});
  final IconData icon;
  final String title;
  final String message;
  final bool showAddSource;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(48),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 36, color: AppColors.accent),
          ),
          const SizedBox(height: 20),
          Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700), textAlign: TextAlign.center),
          const SizedBox(height: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Text(message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.textSecondary, height: 1.5)),
          ),
          if (showAddSource) ...[
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () => context.go('/settings'),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Ajouter une source'),
            ),
          ],
        ],
      ),
    );
  }
}

/// Carte d'affiche (poster) avec mise en avant au focus/survol.
class PosterCard extends StatefulWidget {
  const PosterCard({super.key, this.title, this.width = 160, this.aspectRatio = 2 / 3, this.onTap});
  final String? title;
  final double width;
  final double aspectRatio;
  final VoidCallback? onTap;

  @override
  State<PosterCard> createState() => _PosterCardState();
}

class _PosterCardState extends State<PosterCard> {
  bool _active = false;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.width,
      child: InkWell(
        onTap: widget.onTap ?? () {},
        onFocusChange: (f) => setState(() => _active = f),
        onHover: (h) => setState(() => _active = h),
        borderRadius: BorderRadius.circular(14),
        child: AnimatedScale(
          scale: _active ? 1.05 : 1,
          duration: const Duration(milliseconds: 160),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AspectRatio(
                aspectRatio: widget.aspectRatio,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceHigh,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: _active ? AppColors.accent : AppColors.border, width: 2),
                  ),
                  child: const Center(
                    child: Icon(Icons.image_outlined, color: AppColors.border, size: 40),
                  ),
                ),
              ),
              if (widget.title != null) ...[
                const SizedBox(height: 8),
                Text(widget.title!, maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: AppColors.textSecondary)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Rangée horizontale d'affiches avec un titre.
class PosterRow extends StatelessWidget {
  const PosterRow({super.key, required this.title, this.count = 8, this.width = 160, this.aspectRatio = 2 / 3});
  final String title;
  final int count;
  final double width;
  final double aspectRatio;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
        const SizedBox(height: 14),
        SizedBox(
          height: width / aspectRatio + 40,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            clipBehavior: Clip.none,
            padding: const EdgeInsets.symmetric(vertical: 6),
            itemCount: count,
            separatorBuilder: (_, _) => const SizedBox(width: 16),
            itemBuilder: (_, _) => PosterCard(width: width, aspectRatio: aspectRatio),
          ),
        ),
        const SizedBox(height: 28),
      ],
    );
  }
}
