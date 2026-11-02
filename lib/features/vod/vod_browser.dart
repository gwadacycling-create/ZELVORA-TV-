import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/h_scroller.dart';
import '../../domain/vod.dart';
import '../../state/sources_state.dart';
import '../../state/vod_state.dart';
import 'vod_details.dart';

/// Page Films ou Séries : recherche, catégories, reprise et grille d'affiches.
class VodBrowser extends ConsumerStatefulWidget {
  const VodBrowser({super.key, required this.kind});
  final VodKind kind;

  @override
  ConsumerState<VodBrowser> createState() => _VodBrowserState();
}

class _VodBrowserState extends ConsumerState<VodBrowser> {
  String? _category;
  String _query = '';

  bool get _movies => widget.kind == VodKind.movie;

  @override
  Widget build(BuildContext context) {
    final title = _movies ? 'Films' : 'Séries';
    final sources = ref.watch(sourcesProvider).value ?? const [];
    final pad = MediaQuery.sizeOf(context).width < 700 ? 16.0 : 40.0;
    if (sources.isEmpty) {
      return PageScaffold(title: title, children: [
        EmptyState(
          icon: _movies ? Icons.movie_rounded : Icons.video_library_rounded,
          title: _movies ? 'Aucun film pour le moment' : 'Aucune série pour le moment',
          message: 'Ajoutez votre source (Xtream Codes ou M3U) pour afficher ici son catalogue avec les affiches.',
        ),
      ]);
    }
    final async = ref.watch(vodCatalogProvider);
    final catalog = async.value;
    final all = catalog == null ? const <VodItem>[] : (_movies ? catalog.movies : catalog.series);
    final cats = VodCatalog.categoriesOf(all);
    final q = _query.trim().toLowerCase();
    final items = [
      for (final i in all)
        if ((_category == null || (i.category.isEmpty ? 'Sans catégorie' : i.category) == _category) &&
            (q.isEmpty || i.name.toLowerCase().contains(q)))
          i,
    ];
    ref.watch(progressProvider);
    final resume = [
      for (final p in ref.read(progressProvider.notifier).inProgress)
        if (p.item.kind == widget.kind) p,
    ];

    return CustomScrollView(slivers: [
      SliverPadding(
        padding: EdgeInsets.fromLTRB(pad, 36, pad, 0),
        sliver: SliverToBoxAdapter(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Wrap(
              spacing: 24,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(title, style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w800)),
                SizedBox(
                  width: 340,
                  child: TextField(
                    key: Key('vod-search-${widget.kind.name}'),
                    onChanged: (v) => setState(() => _query = v),
                    decoration: InputDecoration(
                      hintText: _movies ? 'Rechercher un film' : 'Rechercher une série',
                      prefixIcon: const Icon(Icons.search_rounded),
                      isDense: true,
                      filled: true,
                      fillColor: AppColors.surface,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    ),
                  ),
                ),
                if (catalog != null)
                  Text('${items.length} ${_movies ? 'films' : 'séries'}', style: const TextStyle(color: AppColors.textSecondary)),
              ],
            ),
            const SizedBox(height: 18),
            for (final e in (catalog?.errors ?? const <String, String>{}).entries)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text('${e.key} : ${e.value}', style: const TextStyle(color: AppColors.live)),
              ),
            if (cats.length > 1)
              HScroller(
                height: 52,
                spacing: 8,
                itemCount: cats.length + 1,
                itemBuilder: (_, i) {
                  final c = i == 0 ? null : cats[i - 1];
                  return ChoiceChip(
                    label: Text(c ?? 'Tout'),
                    selected: _category == c,
                    onSelected: (_) => setState(() => _category = c),
                    selectedColor: AppColors.accent.withValues(alpha: 0.25),
                    side: BorderSide(color: _category == c ? AppColors.accent : AppColors.border),
                  );
                },
              ),
            if (resume.isNotEmpty && q.isEmpty && _category == null) ...[
              const SizedBox(height: 18),
              const Text('Continuer à regarder', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              HScroller(
                height: 330,
                spacing: 16,
                itemCount: resume.length,
                itemBuilder: (_, i) => SizedBox(
                  width: 160,
                  child: VodPoster(
                    item: resume[i].item,
                    subtitle: resume[i].label,
                    progress: resume[i].ratio,
                    onTap: () => showVodDetails(context, resume[i].item),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 18),
          ]),
        ),
      ),
      if (async.isLoading && catalog == null)
        const SliverFillRemaining(
          hasScrollBody: false,
          child: Center(child: CircularProgressIndicator(color: AppColors.accent)),
        )
      else if (items.isEmpty)
        SliverPadding(
          padding: EdgeInsets.symmetric(horizontal: pad),
          sliver: SliverToBoxAdapter(
            child: EmptyState(
              icon: _movies ? Icons.movie_rounded : Icons.video_library_rounded,
              title: q.isNotEmpty ? 'Aucun résultat' : (_movies ? 'Aucun film' : 'Aucune série'),
              message: q.isNotEmpty
                  ? 'Essayez un autre titre.'
                  : 'Votre source ne propose pas de ${_movies ? 'films' : 'séries'}, ou ils ne sont pas inclus dans votre abonnement.',
              showAddSource: false,
            ),
          ),
        )
      else
        SliverPadding(
          padding: EdgeInsets.fromLTRB(pad, 0, pad, 40),
          sliver: SliverGrid.builder(
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 180,
              mainAxisSpacing: 20,
              crossAxisSpacing: 16,
              childAspectRatio: 0.52,
            ),
            itemCount: items.length,
            itemBuilder: (_, i) => VodPoster(item: items[i], onTap: () => showVodDetails(context, items[i])),
          ),
        ),
    ]);
  }
}

/// Affiche d'un film ou d'une série.
class VodPoster extends StatefulWidget {
  const VodPoster({super.key, required this.item, required this.onTap, this.progress, this.subtitle});
  final VodItem item;
  final VoidCallback onTap;
  final double? progress;
  final String? subtitle;

  @override
  State<VodPoster> createState() => _VodPosterState();
}

class _VodPosterState extends State<VodPoster> {
  bool _active = false;

  @override
  Widget build(BuildContext context) {
    final i = widget.item;
    final fallback = Center(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(i.kind == VodKind.movie ? Icons.movie_rounded : Icons.video_library_rounded, color: AppColors.textSecondary, size: 36),
          const SizedBox(height: 8),
          Text(i.name, textAlign: TextAlign.center, maxLines: 3, overflow: TextOverflow.ellipsis),
        ]),
      ),
    );
    return InkWell(
      onTap: widget.onTap,
      onHover: (h) => setState(() => _active = h),
      onFocusChange: (f) => setState(() => _active = f),
      borderRadius: BorderRadius.circular(14),
      child: AnimatedScale(
        scale: _active ? 1.04 : 1,
        duration: const Duration(milliseconds: 150),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          AspectRatio(
            aspectRatio: 2 / 3,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: AppColors.surfaceHigh,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _active ? AppColors.accent : AppColors.border, width: 2),
                boxShadow: _active ? AppColors.glow(0.35) : null,
              ),
              child: Stack(fit: StackFit.expand, children: [
                if (i.poster == null)
                  fallback
                else
                  Image.network(i.poster!, fit: BoxFit.cover, errorBuilder: (_, _, _) => fallback),
                if (i.rating != null)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(color: const Color(0xCC000000), borderRadius: BorderRadius.circular(6)),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        const Icon(Icons.star_rounded, color: AppColors.accent, size: 14),
                        const SizedBox(width: 2),
                        Text(i.rating!.toStringAsFixed(1), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                      ]),
                    ),
                  ),
                if (widget.progress != null)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: LinearProgressIndicator(
                      value: widget.progress,
                      minHeight: 4,
                      color: AppColors.accent,
                      backgroundColor: Colors.black54,
                    ),
                  ),
              ]),
            ),
          ),
          const SizedBox(height: 8),
          Text(i.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600)),
          if ((widget.subtitle ?? i.year) != null)
            Text(widget.subtitle ?? i.year!,
                maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
        ]),
      ),
    );
  }
}
