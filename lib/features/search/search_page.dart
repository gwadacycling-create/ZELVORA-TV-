import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/h_scroller.dart';
import '../../domain/channel.dart';
import '../../domain/vod.dart';
import '../../state/sources_state.dart';
import '../../state/vod_state.dart';
import '../live/live_page.dart' show ChannelTile;
import '../player/playback.dart';
import '../vod/vod_browser.dart' show VodPoster;
import '../vod/vod_details.dart';

/// Ignore accents et majuscules : « eté » trouve « Été ».
String fold(String s) {
  const from = 'àâäáãåçéèêëíìîïñóòôöõúùûüýÿœæ';
  const to = 'aaaaaaceeeeiiiinooooouuuuyyoa';
  final b = StringBuffer();
  for (final ch in s.toLowerCase().split('')) {
    final i = from.indexOf(ch);
    b.write(i < 0 ? ch : to[i]);
  }
  return b.toString();
}

/// Recherche globale : chaînes, films et séries.
class SearchPage extends ConsumerStatefulWidget {
  const SearchPage({super.key});

  @override
  ConsumerState<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends ConsumerState<SearchPage> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final q = fold(_q.trim());
    final channels = ref.watch(channelsProvider).value?.channels ?? const <Channel>[];
    final vodAsync = ref.watch(vodCatalogProvider);
    final vod = vodAsync.value;
    bool match(String name) => q.length >= 2 && fold(name).contains(q);
    final ch = [for (final c in channels) if (match(c.name)) c].take(40).toList();
    final movies = [for (final m in vod?.movies ?? const <VodItem>[]) if (match(m.name)) m].take(40).toList();
    final series = [for (final s in vod?.series ?? const <VodItem>[]) if (match(s.name)) s].take(40).toList();
    final pad = MediaQuery.sizeOf(context).width < 700 ? 16.0 : 40.0;

    Widget section(String title, int count, Widget child) => Padding(
          padding: const EdgeInsets.only(top: 26),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('$title ($count)', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            child,
          ]),
        );

    return ListView(padding: EdgeInsets.fromLTRB(pad, 36, pad, 40), children: [
      const Text('Rechercher', style: TextStyle(fontSize: 32, fontWeight: FontWeight.w800)),
      const SizedBox(height: 18),
      TextField(
        key: const Key('global-search'),
        autofocus: true,
        onChanged: (v) => setState(() => _q = v),
        style: const TextStyle(fontSize: 18),
        decoration: InputDecoration(
          hintText: 'Chaîne, film ou série…',
          prefixIcon: const Icon(Icons.search_rounded),
          filled: true,
          fillColor: AppColors.surface,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
        ),
      ),
      if (q.length < 2)
        const Padding(
          padding: EdgeInsets.only(top: 40),
          child: Center(
            child: Text('Tapez au moins 2 lettres.', style: TextStyle(color: AppColors.textSecondary)),
          ),
        )
      else ...[
        if (ch.isEmpty && movies.isEmpty && series.isEmpty && !vodAsync.isLoading)
          const Padding(
            padding: EdgeInsets.only(top: 40),
            child: Center(child: Text('Aucun résultat.', style: TextStyle(color: AppColors.textSecondary))),
          ),
        if (ch.isNotEmpty)
          section(
            'Chaînes',
            ch.length,
            Column(children: [
              for (var i = 0; i < ch.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: SizedBox(
                    height: 72,
                    child: ChannelTile(
                      channel: ch[i],
                      number: i + 1,
                      playing: false,
                      onTap: () {
                        ref.read(currentChannelProvider.notifier).play(ch[i]);
                        context.push('/player');
                      },
                    ),
                  ),
                ),
            ]),
          ),
        for (final (title, list) in [('Films', movies), ('Séries', series)])
          if (list.isNotEmpty)
            section(
              title,
              list.length,
              HScroller(
                height: 330,
                spacing: 16,
                itemCount: list.length,
                itemBuilder: (_, i) => SizedBox(
                  width: 160,
                  child: VodPoster(item: list[i], onTap: () => showVodDetails(context, list[i])),
                ),
              ),
            ),
        if (vodAsync.isLoading)
          const Padding(
            padding: EdgeInsets.only(top: 24),
            child: Center(child: CircularProgressIndicator(color: AppColors.accent)),
          ),
      ],
    ]);
  }
}
