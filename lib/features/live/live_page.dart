import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/common.dart';

/// TV en direct : catégories à gauche, chaînes au centre, aperçu à droite.
class LivePage extends StatelessWidget {
  const LivePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(40, 36, 40, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('TV en direct', style: TextStyle(fontSize: 32, fontWeight: FontWeight.w800)),
          const SizedBox(height: 24),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  width: 220,
                  child: _Panel(
                    title: 'Catégories',
                    child: ListView(children: [
                      for (final c in const ['Toutes les chaînes', 'Favoris', 'Récentes'])
                        ListTile(
                          title: Text(c),
                          dense: true,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          onTap: () {},
                        ),
                    ]),
                  ),
                ),
                const SizedBox(width: 20),
                const Expanded(
                  child: SingleChildScrollView(
                    child: EmptyState(
                      icon: Icons.live_tv_rounded,
                      title: 'Aucune chaîne pour le moment',
                      message: 'Ajoutez une playlist M3U ou un compte Xtream Codes dans les réglages pour afficher vos chaînes ici.',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
            child: Text(title.toUpperCase(),
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 12, letterSpacing: 1.2, fontWeight: FontWeight.w700)),
          ),
          Expanded(child: Material(type: MaterialType.transparency, child: child)),
        ],
      ),
    );
  }
}
