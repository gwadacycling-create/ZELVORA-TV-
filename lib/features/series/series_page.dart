import 'package:flutter/material.dart';

import '../../core/widgets/common.dart';

class SeriesPage extends StatelessWidget {
  const SeriesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const PageScaffold(
      title: 'Séries',
      children: [
        EmptyState(
          icon: Icons.video_library_rounded,
          title: 'Aucune série pour le moment',
          message: 'Les séries de votre source s’afficheront ici, avec leurs saisons et épisodes.',
          showAddSource: true,
        ),
      ],
    );
  }
}
