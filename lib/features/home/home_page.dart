import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/common.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(40, 36, 40, 40),
      children: [
        _Hero(),
        const SizedBox(height: 36),
        const PosterRow(title: 'Reprendre la lecture', count: 6, width: 260, aspectRatio: 16 / 9),
        const PosterRow(title: 'Films'),
        const PosterRow(title: 'Séries'),
      ],
    );
  }
}

class _Hero extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 300),
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          colors: [Color(0xFF2A1A12), Color(0xFF141821), Color(0xFF0E1A26)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              gradient: AppColors.accentGradient,
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Text('BIENVENUE',
                style: TextStyle(color: Colors.black, fontWeight: FontWeight.w800, fontSize: 12, letterSpacing: 1.5)),
          ),
          const SizedBox(height: 16),
          const Text('Votre TV, vos sources.', style: TextStyle(fontSize: 38, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          const Text(
            'Ajoutez votre playlist M3U ou votre compte Xtream Codes pour retrouver\nvos chaînes, films et séries au même endroit.',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 16, height: 1.5),
          ),
          const SizedBox(height: 22),
          Row(children: [
            FilledButton.icon(
              autofocus: true,
              onPressed: () => context.go('/settings'),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Ajouter une source'),
            ),
            const SizedBox(width: 12),
            OutlinedButton.icon(
              onPressed: () => context.go('/live'),
              icon: const Icon(Icons.live_tv_rounded),
              label: const Text('TV en direct'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ]),
        ],
      ),
    );
  }
}
