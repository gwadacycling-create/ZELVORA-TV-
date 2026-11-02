import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/channel_tiles.dart';
import '../../core/widgets/h_scroller.dart';
import '../../core/widgets/visuals.dart';
import '../../domain/channel.dart';
import '../../state/sources_state.dart';
import '../player/playback.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(channelsProvider).value;
    final channels = data?.channels ?? const <Channel>[];
    final current = ref.watch(currentChannelProvider);

    void play(Channel c) {
      ref.read(currentChannelProvider.notifier).play(c);
      context.push('/player');
    }

    // Une chaîne par catégorie pour la bannière, puis les plus grandes catégories.
    final featured = <Channel>[];
    final byCat = <String, List<Channel>>{};
    for (final c in channels) {
      final g = c.group.isEmpty ? 'Autres chaînes' : c.group;
      (byCat[g] ??= []).add(c);
    }
    for (final list in byCat.values) {
      if (featured.length < 4) featured.add(list.first);
    }
    final topCats = byCat.entries.toList()..sort((a, b) => b.value.length.compareTo(a.value.length));

    return ListView(
      padding: EdgeInsets.zero,
      children: [
        _HeroCarousel(featured: featured, onPlay: play),
        Padding(
          padding: EdgeInsets.fromLTRB(MediaQuery.sizeOf(context).width < 700 ? 16 : 40, 8, 16, 40),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (channels.isEmpty)
              const _Welcome()
            else ...[
              if (current != null) ...[
                const SectionTitle(icon: Icons.play_circle_outline_rounded, title: 'Reprendre la lecture'),
                SizedBox(
                  height: 100,
                  child: ListView(scrollDirection: Axis.horizontal, clipBehavior: Clip.none, children: [
                    ChannelWideCard(channel: current, subtitle: 'En direct · ${current.group}', progress: 1, onTap: () => play(current)),
                  ]),
                ),
                const SizedBox(height: 26),
              ],
              const SectionTitle(icon: Icons.live_tv_rounded, title: 'Chaînes populaires'),
              _TileRow(channels: channels.take(12).toList(), onTap: play),
              for (final e in topCats.take(4)) ...[
                const SizedBox(height: 26),
                SectionTitle(
                  icon: categoryIcon(e.key),
                  title: e.key,
                  trailing: TextButton(
                    onPressed: () {
                      ref.read(liveFilterProvider.notifier).setCategory(e.key);
                      context.go('/live');
                    },
                    child: const Text('Tout voir ›', style: TextStyle(color: AppColors.accent)),
                  ),
                ),
                _TileRow(channels: e.value.take(12).toList(), onTap: play),
              ],
            ],
          ]),
        ),
      ],
    );
  }
}

class _TileRow extends StatelessWidget {
  const _TileRow({required this.channels, required this.onTap});
  final List<Channel> channels;
  final void Function(Channel) onTap;

  @override
  Widget build(BuildContext context) {
    return HScroller(
      height: 84,
      itemCount: channels.length,
      itemBuilder: (_, i) => ChannelBrandTile(channel: channels[i], onTap: () => onTap(channels[i])),
    );
  }
}

class _HeroCarousel extends StatefulWidget {
  const _HeroCarousel({required this.featured, required this.onPlay});
  final List<Channel> featured;
  final void Function(Channel) onPlay;

  @override
  State<_HeroCarousel> createState() => _HeroCarouselState();
}

class _HeroCarouselState extends State<_HeroCarousel> {
  int _i = 0;
  Timer? _t;

  @override
  void initState() {
    super.initState();
    _t = Timer.periodic(const Duration(seconds: 8), (_) {
      if (mounted && widget.featured.length > 1) setState(() => _i = (_i + 1) % widget.featured.length);
    });
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final list = widget.featured;
    final c = list.isEmpty ? null : list[_i % list.length];
    final narrow = MediaQuery.sizeOf(context).width < 700;
    return HeroHeader(
      height: narrow ? 420 : 400,
      sunX: 0.62 + 0.08 * (_i % 3),
      child: Padding(
        padding: EdgeInsets.fromLTRB(narrow ? 20 : 40, narrow ? 16 : 28, narrow ? 16 : 32, 24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            if (c != null) const LiveBadge() else const SizedBox.shrink(),
            const Spacer(),
            if (!narrow) const TopBar(),
          ]),
          const Spacer(),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 400),
            child: Column(
              key: ValueKey(c?.key),
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (c != null && c.logo != null) ...[
                  ChannelLogo(url: c.logo, size: 64, boxed: false),
                  const SizedBox(height: 10),
                ],
                Text(
                  c?.name ?? 'Votre TV, vos sources.',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: narrow ? 34 : 52, fontWeight: FontWeight.w900, height: 1.05, letterSpacing: -0.5),
                ),
                const SizedBox(height: 10),
                Text(
                  c != null
                      ? 'En direct maintenant${c.group.isNotEmpty ? ' · ${c.group}' : ''}.\nRegardez en plein écran en un clic.'
                      : 'Ajoutez votre playlist M3U ou votre compte Xtream Codes\npour retrouver vos chaînes au même endroit.',
                  style: const TextStyle(fontSize: 17, color: Color(0xFFE4E4E7), height: 1.4),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          Wrap(spacing: 14, runSpacing: 10, children: [
            if (c != null)
              FilledButton.icon(
                autofocus: true,
                onPressed: () => widget.onPlay(c),
                icon: const Icon(Icons.play_arrow_rounded),
                label: const Text('Regarder maintenant', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
              ),
            OutlinedButton.icon(
              autofocus: c == null,
              onPressed: () => context.go('/settings'),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Ajouter une source', style: TextStyle(fontSize: 16)),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: const BorderSide(color: Colors.white70),
                padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ]),
          if (list.length > 1) ...[
            const SizedBox(height: 18),
            Row(children: [
              for (var k = 0; k < list.length; k++)
                GestureDetector(
                  onTap: () => setState(() => _i = k),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    margin: const EdgeInsets.only(right: 8),
                    width: k == _i ? 22 : 9,
                    height: 9,
                    decoration: BoxDecoration(
                      color: k == _i ? AppColors.accent : Colors.white38,
                      borderRadius: BorderRadius.circular(5),
                    ),
                  ),
                ),
            ]),
          ],
        ]),
      ),
    );
  }
}

class _Welcome extends StatelessWidget {
  const _Welcome();

  @override
  Widget build(BuildContext context) {
    final vertical = MediaQuery.sizeOf(context).width < 700;
    Widget step(IconData i, String t, String d) => Flexible(
          fit: vertical ? FlexFit.loose : FlexFit.tight,
          child: Container(
            width: vertical ? double.infinity : null,
            margin: EdgeInsets.only(bottom: vertical ? 12 : 0),
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(i, color: AppColors.accent, size: 30),
              const SizedBox(height: 12),
              Text(t, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              Text(d, style: const TextStyle(color: AppColors.textSecondary, height: 1.4)),
            ]),
          ),
        );
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const SectionTitle(icon: Icons.rocket_launch_outlined, title: 'Pour commencer'),
      Flex(direction: vertical ? Axis.vertical : Axis.horizontal, mainAxisSize: MainAxisSize.min, children: [
        step(Icons.playlist_add_rounded, '1. Ajoutez une source', 'Playlist M3U ou compte Xtream Codes, dans Réglages.'),
        const SizedBox(width: 16),
        step(Icons.live_tv_rounded, '2. Choisissez une chaîne', 'Vos chaînes apparaissent par catégories dans TV en direct.'),
        const SizedBox(width: 16),
        step(Icons.fullscreen_rounded, '3. Profitez', 'Plein écran, zapping avec ↑ ↓ et volume avec ← →.'),
      ]),
    ]);
  }
}
