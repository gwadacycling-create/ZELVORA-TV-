import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/widgets/common.dart';
import '../../state/library_state.dart';
import '../../state/sources_state.dart';
import '../favorites/favorites_page.dart' show ChannelListSection;

String historyLabel(DateTime at, DateTime now) {
  String two(int v) => v.toString().padLeft(2, '0');
  final time = '${two(at.hour)}:${two(at.minute)}';
  final day = DateTime(at.year, at.month, at.day);
  final today = DateTime(now.year, now.month, now.day);
  final diff = today.difference(day).inDays;
  if (diff == 0) return 'Regardée aujourd\'hui à $time';
  if (diff == 1) return 'Regardée hier à $time';
  return 'Regardée le ${two(at.day)}/${two(at.month)} à $time';
}

class HistoryPage extends ConsumerWidget {
  const HistoryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entries = ref.watch(historyProvider);
    final all = ref.watch(channelsProvider).value?.channels ?? const [];
    final byKey = {for (final c in all) c.key: c};
    final visible = [for (final e in entries) if (byKey[e.key] != null) e];
    final now = DateTime.now();
    return PageScaffold(
      title: 'Historique',
      children: [
        if (visible.isEmpty)
          const EmptyState(
            icon: Icons.history_rounded,
            title: 'Historique vide',
            message: 'Ce que vous regardez apparaîtra ici pour reprendre la lecture facilement.',
            showAddSource: false,
          )
        else ...[
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              key: const Key('history-clear'),
              onPressed: () => ref.read(historyProvider.notifier).clear(),
              icon: const Icon(Icons.delete_sweep_rounded),
              label: const Text('Effacer l\'historique'),
            ),
          ),
          const SizedBox(height: 8),
          ChannelListSection(
            channels: [for (final e in visible) byKey[e.key]!],
            subtitles: [for (final e in visible) historyLabel(e.at, now)],
          ),
        ],
      ],
    );
  }
}
