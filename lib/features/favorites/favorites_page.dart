import 'package:flutter/material.dart';

import '../../core/widgets/common.dart';

class FavoritesPage extends StatelessWidget {
  const FavoritesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const PageScaffold(
      title: 'Favoris',
      children: [
        EmptyState(
          icon: Icons.favorite_rounded,
          title: 'Aucun favori',
          message: 'Ajoutez des chaînes, films ou séries à vos favoris pour les retrouver ici en un clic.',
          showAddSource: false,
        ),
      ],
    );
  }
}
