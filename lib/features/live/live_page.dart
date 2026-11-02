import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/common.dart';
import '../../domain/channel.dart';
import '../../state/sources_state.dart';
import '../player/playback.dart';
import '../player/player_page.dart';
import '../player/volume_control.dart';

/// TV en direct : catégories à gauche, chaînes au centre, aperçu à droite.
class LivePage extends ConsumerWidget {
  const LivePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(channelsProvider);
    return Padding(
      padding: const EdgeInsets.fromLTRB(40, 36, 40, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Text('TV en direct', style: TextStyle(fontSize: 32, fontWeight: FontWeight.w800)),
            const Spacer(),
            if (async.hasValue && async.value!.channels.isNotEmpty)
              IconButton(
                tooltip: 'Recharger les sources',
                onPressed: () => ref.read(sourcesProvider.notifier).refresh(),
                icon: const Icon(Icons.refresh_rounded),
              ),
          ]),
          const SizedBox(height: 20),
          Expanded(
            child: async.when(
              loading: () => const Center(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  CircularProgressIndicator(color: AppColors.accent),
                  SizedBox(height: 16),
                  Text('Chargement des chaînes…', style: TextStyle(color: AppColors.textSecondary)),
                ]),
              ),
              error: (e, _) => Center(child: Text('Erreur : $e')),
              data: (data) {
                if (data.channels.isEmpty) {
                  return SingleChildScrollView(
                    child: Column(children: [
                      for (final e in data.errors.entries) _ErrorBanner(source: e.key, message: e.value),
                      const EmptyState(
                        icon: Icons.live_tv_rounded,
                        title: 'Aucune chaîne pour le moment',
                        message:
                            'Ajoutez une playlist M3U ou un compte Xtream Codes dans les réglages pour afficher vos chaînes ici.',
                      ),
                    ]),
                  );
                }
                return Column(children: [
                  for (final e in data.errors.entries) _ErrorBanner(source: e.key, message: e.value),
                  Expanded(child: _LiveLayout(data: data)),
                ]);
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.source, required this.message});
  final String source;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.accent.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.accent.withValues(alpha: 0.4)),
      ),
      child: Text('« $source » : $message'),
    );
  }
}

class _LiveLayout extends ConsumerWidget {
  const _LiveLayout({required this.data});
  final ChannelsData data;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wide = MediaQuery.sizeOf(context).width > 1250;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(width: 230, child: _Categories(data: data)),
        const SizedBox(width: 16),
        const Expanded(flex: 3, child: _ChannelList()),
        if (wide) ...[
          const SizedBox(width: 16),
          const Expanded(flex: 4, child: _Preview()),
        ],
      ],
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({this.title, required this.child});
  final String? title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (title != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
              child: Text(title!.toUpperCase(),
                  style: const TextStyle(
                      color: AppColors.textSecondary, fontSize: 12, letterSpacing: 1.2, fontWeight: FontWeight.w700)),
            ),
          Expanded(child: Material(type: MaterialType.transparency, child: child)),
        ],
      ),
    );
  }
}

class _Categories extends ConsumerWidget {
  const _Categories({required this.data});
  final ChannelsData data;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(liveFilterProvider).category;
    final cats = data.categories;
    return _Panel(
      title: 'Catégories',
      child: ListView.builder(
        itemCount: cats.length + 1,
        itemBuilder: (context, i) {
          final cat = i == 0 ? null : cats[i - 1];
          final label = cat ?? 'Toutes les chaînes';
          final active = cat == selected;
          return ListTile(
            dense: true,
            selected: active,
            selectedColor: AppColors.accent,
            selectedTileColor: AppColors.accent.withValues(alpha: 0.12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            title: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
            trailing: i == 0
                ? Text('${data.channels.length}', style: const TextStyle(color: AppColors.textSecondary, fontSize: 12))
                : null,
            onTap: () => ref.read(liveFilterProvider.notifier).setCategory(cat),
          );
        },
      ),
    );
  }
}

class _ChannelList extends ConsumerWidget {
  const _ChannelList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final list = ref.watch(visibleChannelsProvider);
    final current = ref.watch(currentChannelProvider);
    final wide = MediaQuery.sizeOf(context).width > 1250;
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            decoration: InputDecoration(
              hintText: 'Rechercher une chaîne',
              prefixIcon: const Icon(Icons.search_rounded),
              filled: true,
              fillColor: AppColors.surfaceHigh,
              isDense: true,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            ),
            onChanged: ref.read(liveFilterProvider.notifier).setQuery,
          ),
          const SizedBox(height: 8),
          Expanded(
            child: list.isEmpty
                ? const Center(child: Text('Aucune chaîne trouvée', style: TextStyle(color: AppColors.textSecondary)))
                : ListView.builder(
                    itemCount: list.length,
                    itemExtent: 60,
                    itemBuilder: (context, i) {
                      final c = list[i];
                      final playing = current?.key == c.key;
                      return ChannelTile(
                        channel: c,
                        number: i + 1,
                        playing: playing,
                        onTap: () {
                          final n = ref.read(currentChannelProvider.notifier);
                          if (playing || !wide) {
                            if (!playing) n.play(c);
                            context.push('/player');
                          } else {
                            n.play(c);
                          }
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class ChannelTile extends StatelessWidget {
  const ChannelTile({super.key, required this.channel, required this.number, required this.playing, required this.onTap});
  final Channel channel;
  final int number;
  final bool playing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      selected: playing,
      selectedColor: AppColors.accent,
      selectedTileColor: AppColors.accent.withValues(alpha: 0.12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      leading: SizedBox(
        width: 72,
        child: Row(children: [
          SizedBox(
            width: 28,
            child: Text('$number', style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
          ),
          ChannelLogo(url: channel.logo, size: 40),
        ]),
      ),
      title: Text(channel.name, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: channel.group.isEmpty
          ? null
          : Text(channel.group,
              maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
      trailing: playing ? const Icon(Icons.graphic_eq_rounded, color: AppColors.accent) : null,
    );
  }
}

class ChannelLogo extends StatelessWidget {
  const ChannelLogo({super.key, required this.url, this.size = 40});
  final String? url;
  final double size;

  @override
  Widget build(BuildContext context) {
    final fallback = Icon(Icons.tv_rounded, color: AppColors.textSecondary, size: size * 0.55);
    return Container(
      width: size,
      height: size,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: AppColors.surfaceHigh, borderRadius: BorderRadius.circular(8)),
      child: url == null
          ? fallback
          : Image.network(url!, fit: BoxFit.contain, errorBuilder: (_, _, _) => fallback),
    );
  }
}

class _Preview extends ConsumerWidget {
  const _Preview();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(currentChannelProvider);
    return _Panel(
      title: 'Aperçu',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AspectRatio(
            aspectRatio: 16 / 9,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: current == null
                  ? Container(
                      color: Colors.black,
                      alignment: Alignment.center,
                      child: const Text('Choisissez une chaîne', style: TextStyle(color: AppColors.textSecondary)),
                    )
                  : GestureDetector(
                      onDoubleTap: () => context.push('/player'),
                      child: Stack(fit: StackFit.expand, children: [
                        ref.watch(playbackProvider).view(),
                        PlaybackStatus(playback: ref.watch(playbackProvider), channelKey: current.key),
                      ]),
                    ),
            ),
          ),
          const SizedBox(height: 14),
          if (current != null) ...[
            Row(children: [
              ChannelLogo(url: current.logo, size: 48),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(current.name,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700), overflow: TextOverflow.ellipsis),
                  if (current.group.isNotEmpty)
                    Text(current.group, style: const TextStyle(color: AppColors.textSecondary)),
                ]),
              ),
            ]),
            const SizedBox(height: 14),
            Row(children: [
              FilledButton.icon(
                onPressed: () => context.push('/player'),
                icon: const Icon(Icons.fullscreen_rounded),
                label: const Text('Plein écran'),
              ),
              const SizedBox(width: 10),
              OutlinedButton.icon(
                onPressed: () => ref.read(currentChannelProvider.notifier).stop(),
                icon: const Icon(Icons.stop_rounded),
                label: const Text('Arrêter'),
              ),
            ]),
            const SizedBox(height: 8),
            const Align(alignment: Alignment.centerLeft, child: VolumeControl(width: 140)),
          ] else
            const Text('Cliquez sur une chaîne pour l’aperçu, puis à nouveau pour le plein écran.',
                style: TextStyle(color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}
