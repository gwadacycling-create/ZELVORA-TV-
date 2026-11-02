import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../domain/vod.dart';
import '../../state/sources_state.dart';
import '../../state/vod_state.dart';
import '../player/playback.dart';

String fmtDuration(Duration d) {
  String two(int v) => v.toString().padLeft(2, '0');
  final h = d.inHours;
  final m = d.inMinutes % 60;
  final s = d.inSeconds % 60;
  return h > 0 ? '$h:${two(m)}:${two(s)}' : '${two(m)}:${two(s)}';
}

String episodeLabel(Episode e) => 'S${e.season.toString().padLeft(2, '0')}E${e.number.toString().padLeft(2, '0')}';

/// Lance un film ou un épisode en plein écran.
void playVod(BuildContext context, WidgetRef ref, VodItem item, {Episode? episode, Duration? start}) {
  final sources = ref.read(sourcesProvider).value ?? const [];
  final s = sources.where((e) => e.id == item.sourceId).firstOrNull;
  final ch = vodPlayable(ref.read(sourceRepositoryProvider), s, item, episode: episode);
  if (ch == null) {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Lecture impossible : source introuvable.')));
    return;
  }
  ref.read(currentVodProvider.notifier).set(WatchProgress(
        item: item,
        episodeId: episode?.id,
        label: episode == null ? null : '${episodeLabel(episode)}${episode.title.isEmpty ? '' : ' · ${episode.title}'}',
        position: start ?? Duration.zero,
        duration: Duration.zero,
        at: DateTime.now(),
      ));
  ref.read(currentChannelProvider.notifier).play(ch, start: start);
  Navigator.of(context).pop();
  context.push('/player');
}

Future<void> showVodDetails(BuildContext context, VodItem item) => showDialog<void>(
      context: context,
      barrierColor: Colors.black87,
      builder: (_) => _VodDetailsDialog(item: item),
    );

class _VodDetailsDialog extends ConsumerStatefulWidget {
  const _VodDetailsDialog({required this.item});
  final VodItem item;

  @override
  ConsumerState<_VodDetailsDialog> createState() => _VodDetailsDialogState();
}

class _VodDetailsDialogState extends ConsumerState<_VodDetailsDialog> {
  int? _season;

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final isMovie = item.kind == VodKind.movie;
    final progress = ref.watch(progressProvider);
    final VodDetails? info;
    SeriesDetails? series;
    Object? error;
    bool loading;
    if (isMovie) {
      final a = ref.watch(movieDetailsProvider(item));
      info = a.value;
      loading = a.isLoading;
    } else {
      final a = ref.watch(seriesDetailsProvider(item));
      series = a.value;
      info = series?.info;
      loading = a.isLoading;
      error = a.error;
    }
    final size = MediaQuery.sizeOf(context);
    final narrow = size.width < 760;
    final backdrop = info?.backdrop ?? item.poster;
    final plot = (info?.plot.isNotEmpty ?? false) ? info!.plot : (item.plot ?? '');
    final meta = [
      if (item.year != null) item.year!,
      if (info?.genre.isNotEmpty ?? false) info!.genre,
      if (info?.duration.isNotEmpty ?? false) info!.duration,
      if ((info?.rating ?? item.rating) != null) '★ ${(info?.rating ?? item.rating)!.toStringAsFixed(1)}',
    ].join('  ·  ');

    // Reprise : film, ou dernier épisode commencé de la série.
    WatchProgress? resume;
    if (isMovie) {
      final p = progress[item.key];
      if (p != null && !p.finished && p.position.inSeconds > 30) resume = p;
    } else {
      final mine = progress.values.where((p) => p.item.key == item.key).toList()..sort((a, b) => b.at.compareTo(a.at));
      if (mine.isNotEmpty) resume = mine.first;
    }
    Episode? resumeEpisode;
    if (resume?.episodeId != null && series != null) {
      for (final l in series.seasons.values) {
        for (final e in l) {
          if (e.id == resume!.episodeId) resumeEpisode = e;
        }
      }
    }

    final seasons = series?.seasons ?? const <int, List<Episode>>{};
    final season = _season ?? resumeEpisode?.season ?? (seasons.isEmpty ? null : seasons.keys.first);

    return Dialog(
      insetPadding: EdgeInsets.all(narrow ? 12 : 40),
      backgroundColor: AppColors.surface,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1000),
        child: CustomScrollView(shrinkWrap: true, slivers: [
          SliverToBoxAdapter(
            child: Stack(children: [
              if (backdrop != null)
                Positioned.fill(
                  child: Opacity(
                    opacity: 0.35,
                    child: Image.network(backdrop, fit: BoxFit.cover, errorBuilder: (_, _, _) => const SizedBox()),
                  ),
                ),
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.transparent, AppColors.surface.withValues(alpha: 0.95), AppColors.surface],
                      stops: const [0, 0.75, 1],
                    ),
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.all(narrow ? 18 : 32),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  if (!narrow) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: SizedBox(
                        width: 200,
                        height: 300,
                        child: item.poster == null
                            ? const ColoredBox(color: AppColors.surfaceHigh, child: Icon(Icons.movie_rounded, size: 48))
                            : Image.network(item.poster!, fit: BoxFit.cover,
                                errorBuilder: (_, _, _) =>
                                    const ColoredBox(color: AppColors.surfaceHigh, child: Icon(Icons.movie_rounded, size: 48))),
                      ),
                    ),
                    const SizedBox(width: 28),
                  ],
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        Expanded(
                          child: Text(item.name, style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w900)),
                        ),
                        IconButton(
                          tooltip: 'Fermer',
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(Icons.close_rounded),
                        ),
                      ]),
                      if (meta.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(meta, style: const TextStyle(color: AppColors.textSecondary)),
                      ],
                      const SizedBox(height: 18),
                      Wrap(spacing: 12, runSpacing: 10, children: [
                        if (isMovie) ...[
                          FilledButton.icon(
                            key: const Key('vod-play'),
                            onPressed: () => playVod(context, ref, item, start: resume?.position),
                            icon: const Icon(Icons.play_arrow_rounded),
                            label: Text(resume == null ? 'Lecture' : 'Reprendre à ${fmtDuration(resume.position)}'),
                          ),
                          if (resume != null)
                            OutlinedButton.icon(
                              onPressed: () => playVod(context, ref, item),
                              icon: const Icon(Icons.replay_rounded),
                              label: const Text('Depuis le début'),
                            ),
                        ] else if (resumeEpisode != null)
                          FilledButton.icon(
                            key: const Key('vod-resume-episode'),
                            onPressed: () => playVod(context, ref, item,
                                episode: resumeEpisode,
                                start: resume!.finished ? null : resume.position),
                            icon: const Icon(Icons.play_arrow_rounded),
                            label: Text('${resume!.finished ? 'Revoir' : 'Reprendre'} ${episodeLabel(resumeEpisode)}'),
                          ),
                      ]),
                      if (plot.isNotEmpty) ...[
                        const SizedBox(height: 18),
                        Text(plot, style: const TextStyle(height: 1.4)),
                      ],
                      if (info?.cast.isNotEmpty ?? false) ...[
                        const SizedBox(height: 10),
                        Text('Avec : ${info!.cast}',
                            maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.textSecondary)),
                      ],
                      if (info?.director.isNotEmpty ?? false)
                        Text('Réalisation : ${info!.director}', style: const TextStyle(color: AppColors.textSecondary)),
                      if (loading) ...[
                        const SizedBox(height: 16),
                        const LinearProgressIndicator(color: AppColors.accent),
                      ],
                      if (error != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 16),
                          child: Text('Épisodes indisponibles : $error', style: const TextStyle(color: AppColors.live)),
                        ),
                    ]),
                  ),
                ]),
              ),
            ]),
          ),
          if (!isMovie && seasons.isNotEmpty) ...[
            SliverPadding(
              padding: EdgeInsets.symmetric(horizontal: narrow ? 18 : 32),
              sliver: SliverToBoxAdapter(
                child: Wrap(spacing: 8, runSpacing: 8, children: [
                  for (final s in seasons.keys)
                    ChoiceChip(
                      label: Text('Saison $s'),
                      selected: s == season,
                      onSelected: (_) => setState(() => _season = s),
                      selectedColor: AppColors.accent.withValues(alpha: 0.25),
                      side: BorderSide(color: s == season ? AppColors.accent : AppColors.border),
                    ),
                ]),
              ),
            ),
            SliverPadding(
              padding: EdgeInsets.fromLTRB(narrow ? 18 : 32, 14, narrow ? 18 : 32, 28),
              sliver: SliverList.builder(
                itemCount: seasons[season]?.length ?? 0,
                itemBuilder: (_, i) {
                  final e = seasons[season]![i];
                  final p = progress[progressKey(item, e.id)];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Material(
                      color: AppColors.surfaceHigh,
                      borderRadius: BorderRadius.circular(12),
                      child: ListTile(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        onTap: () => playVod(context, ref, item,
                            episode: e, start: p != null && !p.finished ? p.position : null),
                        leading: CircleAvatar(
                          backgroundColor: AppColors.accent.withValues(alpha: 0.18),
                          child: Text('${e.number}', style: const TextStyle(color: AppColors.accent, fontWeight: FontWeight.w800)),
                        ),
                        title: Text(e.title.isEmpty ? 'Épisode ${e.number}' : e.title,
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                        subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          if (e.plot.isNotEmpty)
                            Text(e.plot, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.textSecondary)),
                          if (p != null) ...[
                            const SizedBox(height: 6),
                            LinearProgressIndicator(value: p.finished ? 1 : p.ratio, color: AppColors.accent, minHeight: 3),
                          ],
                        ]),
                        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                          if (e.duration.isNotEmpty) Text(e.duration, style: const TextStyle(color: AppColors.textSecondary)),
                          const SizedBox(width: 8),
                          const Icon(Icons.play_circle_fill_rounded, color: AppColors.accent),
                        ]),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ]),
      ),
    );
  }
}
