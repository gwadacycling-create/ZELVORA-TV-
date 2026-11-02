import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/channel_tiles.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/visuals.dart';
import '../../domain/channel.dart';
import '../../state/sources_state.dart';
import '../player/playback.dart';
import '../player/player_page.dart';
import '../player/volume_control.dart';

/// TV en direct : bannière, catégories, chaînes et lecteur.
class LivePage extends ConsumerWidget {
  const LivePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(channelsProvider);
    final narrow = MediaQuery.sizeOf(context).width < 700;
    return Stack(children: [
      HeroHeader(
        height: narrow ? 170 : 230,
        sunX: 0.8,
        child: Padding(
          padding: EdgeInsets.fromLTRB(narrow ? 20 : 40, narrow ? 16 : 24, 32, 0),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const LiveBadge(),
                const SizedBox(height: 8),
                Text('TV en direct', style: TextStyle(fontSize: narrow ? 32 : 46, fontWeight: FontWeight.w900, height: 1.1)),
                if (!narrow) ...[
                  const SizedBox(height: 6),
                  const Text(
                    'Regardez vos chaînes en direct et profitez d’une expérience TV premium sur ZELVORA TV.',
                    style: TextStyle(fontSize: 16, color: Color(0xFFE4E4E7)),
                  ),
                ],
              ]),
            ),
            if (!narrow) const TopBar(),
          ]),
        ),
      ),
      Padding(
        padding: EdgeInsets.fromLTRB(narrow ? 12 : 32, narrow ? 150 : 200, narrow ? 12 : 32, 24),
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
            final banners = [for (final e in data.errors.entries) _ErrorBanner(source: e.key, message: e.value)];
            if (data.channels.isEmpty) {
              return SingleChildScrollView(
                child: Column(children: [
                  ...banners,
                  const EmptyState(
                    icon: Icons.live_tv_rounded,
                    title: 'Aucune chaîne pour le moment',
                    message:
                        'Ajoutez une playlist M3U ou un compte Xtream Codes dans les réglages pour afficher vos chaînes ici.',
                  ),
                ]),
              );
            }
            return Column(children: [...banners, Expanded(child: _LiveLayout(data: data))]);
          },
        ),
      ),
    ]);
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
        color: const Color(0xEE1A120C),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.accent.withValues(alpha: 0.5)),
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
    return LayoutBuilder(builder: (context, box) {
      final showPreview = box.maxWidth > 1050;
      final showCats = box.maxWidth > 640;
      return Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (showCats) ...[
            SizedBox(width: box.maxWidth > 1250 ? 270 : 220, child: _Categories(data: data)),
            const SizedBox(width: 22),
          ],
          SizedBox(
            width: showPreview ? 390 : null,
            child: showPreview ? const _ChannelList() : null,
          ),
          if (!showPreview) const Expanded(child: _ChannelList()),
          if (showPreview) ...[
            const SizedBox(width: 22),
            const Expanded(child: _Preview()),
          ],
        ],
      );
    });
  }
}

class _Categories extends ConsumerWidget {
  const _Categories({required this.data});
  final ChannelsData data;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(liveFilterProvider).category;
    final cats = data.categories;
    final counts = <String, int>{};
    for (final c in data.channels) {
      final g = c.group.isEmpty ? 'Sans catégorie' : c.group;
      counts[g] = (counts[g] ?? 0) + 1;
    }
    return Material(
      type: MaterialType.transparency,
      child: ListView.separated(
        padding: const EdgeInsets.only(top: 6, bottom: 6, left: 2, right: 2),
        itemCount: cats.length + 1,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (context, i) {
          final cat = i == 0 ? null : cats[i - 1];
          return _CategoryCard(
            label: cat ?? 'Toutes les chaînes',
            icon: cat == null ? Icons.grid_view_rounded : categoryIcon(cat),
            count: cat == null ? data.channels.length : counts[cat] ?? 0,
            selected: cat == selected,
            onTap: () => ref.read(liveFilterProvider.notifier).setCategory(cat),
          );
        },
      ),
    );
  }
}

class _CategoryCard extends StatefulWidget {
  const _CategoryCard({required this.label, required this.icon, required this.count, required this.selected, required this.onTap});
  final String label;
  final IconData icon;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_CategoryCard> createState() => _CategoryCardState();
}

class _CategoryCardState extends State<_CategoryCard> {
  bool _active = false;

  @override
  Widget build(BuildContext context) {
    final sel = widget.selected;
    return InkWell(
      onTap: widget.onTap,
      onFocusChange: (f) => setState(() => _active = f),
      onHover: (h) => setState(() => _active = h),
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        height: 60,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          gradient: sel
              ? LinearGradient(colors: [AppColors.accent.withValues(alpha: 0.95), const Color(0xFFFFA940).withValues(alpha: 0.85)])
              : null,
          color: sel ? null : (_active ? AppColors.surfaceHigh : const Color(0xE616161B)),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: sel || _active ? AppColors.accent : AppColors.border, width: sel || _active ? 2 : 1),
          boxShadow: sel ? AppColors.glow(0.35) : null,
        ),
        child: Row(children: [
          Icon(widget.icon, color: Colors.white, size: 24),
          const SizedBox(width: 14),
          Expanded(
            child: Text(widget.label,
                maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
          ),
          Text('${widget.count}', style: const TextStyle(fontWeight: FontWeight.w600)),
        ]),
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
    final wide = MediaQuery.sizeOf(context).width > 1330;
    return Material(
      type: MaterialType.transparency,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            Text('Chaînes (${list.length})', style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700)),
          ]),
          const SizedBox(height: 10),
          TextField(
            decoration: InputDecoration(
              hintText: 'Rechercher une chaîne',
              prefixIcon: const Icon(Icons.search_rounded),
              filled: true,
              fillColor: const Color(0xE616161B),
              isDense: true,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border)),
              enabledBorder:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border)),
            ),
            onChanged: ref.read(liveFilterProvider.notifier).setQuery,
          ),
          const SizedBox(height: 10),
          Expanded(
            child: list.isEmpty
                ? const Center(child: Text('Aucune chaîne trouvée', style: TextStyle(color: AppColors.textSecondary)))
                : ListView.builder(
                    itemCount: list.length,
                    itemExtent: 82,
                    padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
                    itemBuilder: (context, i) {
                      final c = list[i];
                      final playing = current?.key == c.key;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: ChannelTile(
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
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

/// Carte de chaîne : numéro, logo, nom, badge EN DIRECT.
class ChannelTile extends StatefulWidget {
  const ChannelTile({super.key, required this.channel, required this.number, required this.playing, required this.onTap});
  final Channel channel;
  final int number;
  final bool playing;
  final VoidCallback onTap;

  @override
  State<ChannelTile> createState() => _ChannelTileState();
}

class _ChannelTileState extends State<ChannelTile> {
  bool _active = false;

  @override
  Widget build(BuildContext context) {
    final c = widget.channel;
    final hl = widget.playing || _active;
    return InkWell(
      onTap: widget.onTap,
      onFocusChange: (f) => setState(() => _active = f),
      onHover: (h) => setState(() => _active = h),
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: widget.playing ? const Color(0xFF1E1812) : const Color(0xE616161B),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: hl ? AppColors.accent : AppColors.border, width: hl ? 2 : 1),
          boxShadow: widget.playing ? AppColors.glow(0.35) : null,
        ),
        child: Row(children: [
          SizedBox(
            width: 38,
            child: Text(widget.number.toString().padLeft(3, '0'),
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
          ),
          ChannelLogo(url: c.logo, size: 50, fallbackIcon: categoryIcon(c.group)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(c.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              if (c.group.isNotEmpty)
                Text(c.group,
                    maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
            ]),
          ),
          const SizedBox(width: 6),
          widget.playing ? const Icon(Icons.graphic_eq_rounded, color: AppColors.accent) : const LiveBadge(small: true),
        ]),
      ),
    );
  }
}

class _Preview extends ConsumerWidget {
  const _Preview();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(currentChannelProvider);
    final playback = ref.watch(playbackProvider);
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white24, width: 1.5),
              boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 24)],
            ),
            clipBehavior: Clip.antiAlias,
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: current == null
                  ? Container(
                      color: Colors.black,
                      alignment: Alignment.center,
                      child: const Column(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.live_tv_rounded, size: 42, color: AppColors.textSecondary),
                        SizedBox(height: 10),
                        Text('Choisissez une chaîne', style: TextStyle(color: AppColors.textSecondary)),
                      ]),
                    )
                  : GestureDetector(
                      onDoubleTap: () => context.push('/player'),
                      child: Stack(fit: StackFit.expand, children: [
                        playback.view(),
                        PlaybackStatus(playback: playback, channelKey: current.key),
                        // Bandeau haut : logo, nom, EN DIRECT, plein écran.
                        Positioned(
                          left: 0,
                          right: 0,
                          top: 0,
                          child: Container(
                            padding: const EdgeInsets.fromLTRB(14, 12, 8, 24),
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                  begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xCC000000), Colors.transparent]),
                            ),
                            child: Row(children: [
                              ChannelLogo(url: current.logo, size: 40, fallbackIcon: categoryIcon(current.group)),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  Text(current.name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                                  const Row(children: [
                                    Icon(Icons.circle, size: 9, color: AppColors.live),
                                    SizedBox(width: 6),
                                    Text('EN DIRECT', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                                  ]),
                                ]),
                              ),
                              IconButton(
                                tooltip: 'Plein écran',
                                onPressed: () => context.push('/player'),
                                icon: const Icon(Icons.fullscreen_rounded, size: 30),
                              ),
                            ]),
                          ),
                        ),
                        // Bandeau bas : pause et volume.
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: 0,
                          child: Container(
                            padding: const EdgeInsets.fromLTRB(6, 18, 10, 4),
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                  begin: Alignment.bottomCenter, end: Alignment.topCenter, colors: [Color(0xCC000000), Colors.transparent]),
                            ),
                            child: Row(children: [
                              IconButton(
                                tooltip: 'Pause / lecture',
                                onPressed: playback.togglePause,
                                icon: const Icon(Icons.pause_rounded, size: 30),
                              ),
                              const Spacer(),
                              const Flexible(child: VolumeControl(width: 110)),
                            ]),
                          ),
                        ),
                      ]),
                    ),
            ),
          ),
          const SizedBox(height: 18),
          if (current != null) ...[
            Text(current.name,
                maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w900)),
            const SizedBox(height: 6),
            Wrap(spacing: 10, crossAxisAlignment: WrapCrossAlignment.center, children: [
              Text(current.group.isEmpty ? 'Chaîne en direct' : current.group,
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 16)),
              const _Tag('LIVE'),
            ]),
            const SizedBox(height: 18),
            Wrap(spacing: 12, runSpacing: 10, children: [
              FilledButton.icon(
                onPressed: () => context.push('/player'),
                icon: const Icon(Icons.play_arrow_rounded),
                label: const Text('Regarder', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
              ),
              _OutlineAction(icon: Icons.list_rounded, label: 'Voir le guide', onPressed: () => context.go('/guide')),
              _OutlineAction(
                  icon: Icons.stop_rounded, label: 'Arrêter', onPressed: () => ref.read(currentChannelProvider.notifier).stop()),
            ]),
          ] else
            const Text('Cliquez sur une chaîne pour l’aperçu, puis à nouveau pour le plein écran.',
                style: TextStyle(color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(5), border: Border.all(color: Colors.white54)),
      child: Text(text, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
    );
  }
}

class _OutlineAction extends StatelessWidget {
  const _OutlineAction({required this.icon, required this.label, required this.onPressed});
  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon),
      label: Text(label, style: const TextStyle(fontSize: 16)),
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.white,
        side: const BorderSide(color: Colors.white38),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
