import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/source_repository.dart';
import '../data/xtream_client.dart';
import '../domain/channel.dart';
import '../domain/iptv_source.dart';
import '../domain/vod.dart';
import 'parental_state.dart';
import 'profile_state.dart';
import 'sources_state.dart';

class VodCatalog {
  const VodCatalog({this.movies = const [], this.series = const [], this.errors = const {}});
  final List<VodItem> movies;
  final List<VodItem> series;
  final Map<String, String> errors;

  static List<String> categoriesOf(List<VodItem> items) {
    final seen = <String>{};
    for (final i in items) {
      seen.add(i.category.isEmpty ? 'Sans catégorie' : i.category);
    }
    return seen.toList();
  }
}

XtreamClient? xtreamFor(IptvSource s, SourceRepository repo) {
  if (s.kind != SourceKind.xtream) return null;
  return XtreamClient(
    server: s.location,
    username: s.username ?? '',
    password: s.password ?? '',
    httpClient: repo.httpClient,
    userAgent: kIptvUserAgent,
  );
}

/// Catalogue des films et séries de toutes les sources (gardé en mémoire).
final vodCatalogProvider = FutureProvider<VodCatalog>((ref) async {
  final parental = ref.watch(hideAdultProvider);
  final sources = await ref.watch(sourcesProvider.future);
  final data = await ref.watch(channelsProvider.future);
  final repo = ref.read(sourceRepositoryProvider);
  final movies = <VodItem>[];
  final series = <VodItem>[];
  final errors = <String, String>{};
  await Future.wait(sources.map((s) async {
    final x = xtreamFor(s, repo);
    if (x == null) return;
    try {
      final r = await Future.wait([x.movies(s.id), x.series(s.id)]);
      movies.addAll(r[0]);
      series.addAll(r[1]);
    } on XtreamException catch (e) {
      errors[s.name] = e.message;
    } catch (_) {
      errors[s.name] = 'Films et séries indisponibles pour le moment.';
    }
  }));
  // Films présents dans une playlist M3U (liens /movie/ ou /series/).
  for (final c in data.vod) {
    movies.add(VodItem(
      kind: VodKind.movie,
      id: c.url,
      name: c.name,
      sourceId: c.sourceId,
      poster: c.logo,
      category: c.group,
      url: c.url,
    ));
  }
  if (parental) {
    movies.removeWhere((m) => isAdultContent(m.category, m.name));
    series.removeWhere((m) => isAdultContent(m.category, m.name));
  }
  return VodCatalog(movies: movies, series: series, errors: errors);
});

final movieDetailsProvider = FutureProvider.family<VodDetails, VodItem>((ref, item) async {
  if (item.url != null) return const VodDetails();
  final sources = await ref.watch(sourcesProvider.future);
  final s = sources.where((e) => e.id == item.sourceId).firstOrNull;
  final x = s == null ? null : xtreamFor(s, ref.read(sourceRepositoryProvider));
  if (x == null) return const VodDetails();
  try {
    return await x.movieDetails(item.id);
  } catch (_) {
    return const VodDetails();
  }
});

final seriesDetailsProvider = FutureProvider.family<SeriesDetails, VodItem>((ref, item) async {
  final sources = await ref.watch(sourcesProvider.future);
  final s = sources.where((e) => e.id == item.sourceId).firstOrNull;
  final x = s == null ? null : xtreamFor(s, ref.read(sourceRepositoryProvider));
  if (x == null) throw XtreamException('Source introuvable.');
  return x.seriesDetails(item.id);
});

/// Lecture d'un film ou d'un épisode : transformé en « chaîne » pour le lecteur.
Channel? vodPlayable(SourceRepository repo, IptvSource? s, VodItem item, {Episode? episode}) {
  if (item.url != null) {
    return Channel(name: item.name, url: item.url!, logo: item.poster, group: item.category, sourceId: item.sourceId, vod: true);
  }
  if (s == null) return null;
  final x = xtreamFor(s, repo);
  if (x == null) return null;
  if (episode != null) {
    final label = 'S${episode.season.toString().padLeft(2, '0')}E${episode.number.toString().padLeft(2, '0')}';
    return Channel(
      name: '${item.name} · $label${episode.title.isEmpty || episode.title == item.name ? '' : ' · ${episode.title}'}',
      url: x.episodeUrl(episode.id, episode.ext),
      logo: item.poster,
      group: 'Série',
      sourceId: s.id,
      vod: true,
    );
  }
  return Channel(
    name: item.name,
    url: x.movieUrl(item.id, item.ext),
    logo: item.poster,
    group: item.category,
    sourceId: s.id,
    vod: true,
  );
}

// ----- Reprise de lecture -----

const kProgressKey = 'zelvora.progress.v1';

class WatchProgress {
  const WatchProgress({required this.item, required this.position, required this.duration, required this.at, this.episodeId, this.label});
  final VodItem item;
  final String? episodeId;
  final String? label;
  final Duration position;
  final Duration duration;
  final DateTime at;

  double get ratio => duration.inSeconds <= 0 ? 0 : (position.inSeconds / duration.inSeconds).clamp(0, 1).toDouble();

  /// Presque fini : on ne propose plus la reprise.
  bool get finished => duration.inSeconds > 0 && position.inSeconds > duration.inSeconds - 120 || ratio > 0.95;

  Map<String, dynamic> toJson() => {
        'i': item.toJson(),
        if (episodeId != null) 'e': episodeId,
        if (label != null) 'l': label,
        'p': position.inSeconds,
        'd': duration.inSeconds,
        't': at.toIso8601String(),
      };

  static WatchProgress fromJson(Map<String, dynamic> j) => WatchProgress(
        item: VodItem.fromJson(Map<String, dynamic>.from(j['i'] as Map)),
        episodeId: j['e'] as String?,
        label: j['l'] as String?,
        position: Duration(seconds: (j['p'] as num).toInt()),
        duration: Duration(seconds: (j['d'] as num).toInt()),
        at: DateTime.parse(j['t'] as String),
      );
}

/// Clé de reprise : le film, ou l'épisode d'une série.
String progressKey(VodItem item, [String? episodeId]) => episodeId == null ? item.key : '${item.key}|$episodeId';

final progressProvider = NotifierProvider<ProgressNotifier, Map<String, WatchProgress>>(ProgressNotifier.new);

class ProgressNotifier extends Notifier<Map<String, WatchProgress>> {
  bool _loaded = false;

  @override
  Map<String, WatchProgress> build() {
    final key = _key = profileKey(kProgressKey, ref.watch(currentProfileProvider));
    _loaded = false;
    _load(key);
    return const {};
  }

  String _key = kProgressKey;

  Future<void> _load(String key) async {
    try {
      final raw = await ref.read(secureStoreProvider).read(key);
      if (key != _key) return; // profil changé entre-temps
      if (raw != null && !_loaded) {
        final m = jsonDecode(raw) as Map;
        state = {for (final e in m.entries) '${e.key}': WatchProgress.fromJson(Map<String, dynamic>.from(e.value as Map))};
      }
    } catch (_) {}
    _loaded = true;
  }

  Future<void> save(WatchProgress p) async {
    if (!ref.mounted) return;
    _loaded = true;
    final next = {...state, progressKey(p.item, p.episodeId): p};
    // On garde les 100 plus récents.
    final sorted = next.entries.toList()..sort((a, b) => b.value.at.compareTo(a.value.at));
    state = Map.fromEntries(sorted.take(100));
    await ref.read(secureStoreProvider).write(_key, jsonEncode(state.map((k, v) => MapEntry(k, v.toJson()))));
  }

  /// « Continuer à regarder » : non terminés, du plus récent au plus ancien.
  List<WatchProgress> get inProgress {
    final l = state.values.where((p) => !p.finished && p.position.inSeconds > 30).toList()
      ..sort((a, b) => b.at.compareTo(a.at));
    // Une seule entrée par série (le dernier épisode vu).
    final seen = <String>{};
    return [for (final p in l) if (seen.add(p.item.key)) p];
  }
}

/// Ce qui est en cours de lecture, pour enregistrer la progression.
final currentVodProvider = NotifierProvider<CurrentVodNotifier, WatchProgress?>(CurrentVodNotifier.new);

class CurrentVodNotifier extends Notifier<WatchProgress?> {
  @override
  WatchProgress? build() => null;
  void set(WatchProgress? p) => state = p;
}

