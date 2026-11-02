import 'package:flutter/material.dart';

import '../../core/widgets/common.dart';

class HistoryPage extends StatelessWidget {
  const HistoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const PageScaffold(
      title: 'Historique',
      children: [
        EmptyState(
          icon: Icons.history_rounded,
          title: 'Historique vide',
          message: 'Ce que vous regardez apparaîtra ici pour reprendre la lecture facilement.',
          showAddSource: false,
        ),
      ],
    );
  }
}
