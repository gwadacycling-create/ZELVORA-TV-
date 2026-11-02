import 'package:flutter/material.dart';

import '../../core/widgets/common.dart';

class MoviesPage extends StatelessWidget {
  const MoviesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const PageScaffold(
      title: 'Films',
      children: [
        EmptyState(
          icon: Icons.movie_rounded,
          title: 'Aucun film pour le moment',
          message: 'Les films de votre source (Xtream Codes ou M3U) s’afficheront ici avec leurs affiches.',
          showAddSource: true,
        ),
      ],
    );
  }
}
