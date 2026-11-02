import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/widgets/common.dart';
import '../../domain/channel.dart';
import '../../state/library_state.dart';
import '../../state/sources_state.dart';
import '../live/live_page.dart' show ChannelTile;
import '../player/playback.dart';

/// Liste de chaînes cliquables (favoris, historique).
class ChannelListSection extends ConsumerWidget {
  const ChannelListSection({super.key, required this.channels, this.subtitles});
  final List<Channel> channels;
  final List<String>? subtitles;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(currentChannelProvider);
    return Column(children: [
      for (var i = 0; i < channels.length; i++)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: SizedBox(
            height: 72,
            child: ChannelTile(
              channel: channels[i],
              number: i + 1,
              playing: current?.key == channels[i].key,
              subtitle: subtitles?[i],
              onTap: () {
                ref.read(currentChannelProvider.notifier).play(channels[i]);
                context.push('/player');
              },
            ),
          ),
        ),
    ]);
  }
}

class FavoritesPage extends ConsumerWidget {
  const FavoritesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final keys = ref.watch(favoritesProvider);
    final data = ref.watch(channelsProvider);
    final favs = resolveChannels(keys, data.value?.channels ?? const []);
    return PageScaffold(
      title: 'Favoris',
      children: [
        if (keys.isEmpty)
          const EmptyState(
            icon: Icons.favorite_rounded,
            title: 'Aucun favori',
            message: 'Cliquez sur le cœur ♡ d\'une chaîne (ou faites un clic droit sur une tuile, ou touche F pendant la lecture) pour la retrouver ici.',
            showAddSource: false,
          )
        else if (data.isLoading && favs.isEmpty)
          const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator()))
        else
          ChannelListSection(channels: favs),
      ],
    );
  }
}
