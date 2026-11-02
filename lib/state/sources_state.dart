import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/source_repository.dart';
import '../domain/channel.dart';
import 'parental_state.dart';
import '../domain/iptv_source.dart';

final secureStoreProvider = Provider<SecureStore>((ref) => const SystemSecureStore());
final sourceRepositoryProvider = Provider<SourceRepository>((ref) => SourceRepository(store: ref.read(secureStoreProvider)));

/// Liste des sources de l'utilisateur.
final sourcesProvider = AsyncNotifierProvider<SourcesNotifier, List<IptvSource>>(SourcesNotifier.new);

class SourcesNotifier extends AsyncNotifier<List<IptvSource>> {
  @override
  Future<List<IptvSource>> build() => ref.read(sourceRepositoryProvider).loadSources();

  /// Vérifie la source (téléchargement + lecture) avant de l'enregistrer.
  /// Lève [SourceException] avec un message clair en cas de problème.
  Future<int> add({
    required String name,
    required SourceKind kind,
    required String location,
    String? username,
    String? password,
  }) async {
    final repo = ref.read(sourceRepositoryProvider);
    final source = IptvSource(
      id: DateTime.now().microsecondsSinceEpoch.toRadixString(36),
      name: name.trim().isEmpty ? (kind == SourceKind.xtream ? 'Mon compte Xtream' : 'Ma playlist') : name.trim(),
      kind: kind,
      location: location.trim(),
      addedAt: DateTime.now(),
      username: username?.trim(),
      password: password,
    );
    final channels = await repo.fetchChannels(source);
    ref.read(channelCacheProvider)[source.id] = channels;
    final list = [...(state.value ?? await future), source];
    await repo.saveSources(list);
    state = AsyncData(list);
    return channels.length;
  }

  Future<void> remove(String id) async {
    final list = [...(state.value ?? const <IptvSource>[])]..removeWhere((s) => s.id == id);
    await ref.read(sourceRepositoryProvider).saveSources(list);
    ref.read(channelCacheProvider).remove(id);
    state = AsyncData(list);
  }

  /// Recharge les chaînes de toutes les sources.
  void refresh() {
    ref.read(channelCacheProvider).clear();
    ref.invalidate(channelsProvider);
  }
}

/// Chaînes gardées en mémoire uniquement (jamais écrites sur le disque).
final channelCacheProvider = Provider<Map<String, List<Channel>>>((ref) => {});

class ChannelsData {
  ChannelsData(this.channels, this.errors, [this.vod = const []]);
  final List<Channel> channels;

  /// Films / épisodes trouvés dans les playlists M3U (affichés dans Films).
  final List<Channel> vod;

  /// Nom de la source -> message d'erreur.
  final Map<String, String> errors;

  /// Chaînes rangées par catégorie, calculé une seule fois : changer de
  /// catégorie est alors instantané, même avec des milliers de chaînes.
  late final Map<String, List<Channel>> byCategory = () {
    final m = <String, List<Channel>>{};
    for (final c in channels) {
      (m[c.group.isEmpty ? 'Sans catégorie' : c.group] ??= []).add(c);
    }
    return m;
  }();

  late final List<String> categories = byCategory.keys.toList(growable: false);
}

final channelsProvider = FutureProvider<ChannelsData>((ref) async {
  final parental = ref.watch(parentalProvider).enabled;
  final sources = await ref.watch(sourcesProvider.future);
  final repo = ref.read(sourceRepositoryProvider);
  final cache = ref.read(channelCacheProvider);
  final all = <Channel>[];
  final errors = <String, String>{};
  await Future.wait(sources.map((s) async {
    if (cache.containsKey(s.id)) return;
    try {
      cache[s.id] = await repo.fetchChannels(s);
    } on SourceException catch (e) {
      errors[s.name] = e.message;
    }
  }));
  final vod = <Channel>[];
  for (final s in sources) {
    for (final c in cache[s.id] ?? const <Channel>[]) {
      if (parental && isAdultContent(c.group, c.name)) continue;
      (_isVod(c.url) ? vod : all).add(c);
    }
  }
  return ChannelsData(all, errors, vod);
});

/// Filtre de l'écran TV en direct.
class LiveFilter {
  const LiveFilter({this.category, this.query = ''});
  final String? category; // null = toutes
  final String query;
}

final liveFilterProvider = NotifierProvider<LiveFilterNotifier, LiveFilter>(LiveFilterNotifier.new);

class LiveFilterNotifier extends Notifier<LiveFilter> {
  @override
  LiveFilter build() => const LiveFilter();
  void setCategory(String? c) => state = LiveFilter(category: c, query: state.query);
  void setQuery(String q) => state = LiveFilter(category: state.category, query: q);
}

/// Chaînes visibles selon la catégorie et la recherche.
final visibleChannelsProvider = Provider<List<Channel>>((ref) {
  final data = ref.watch(channelsProvider).value;
  if (data == null) return const [];
  final f = ref.watch(liveFilterProvider);
  final q = f.query.trim().toLowerCase();
  final base = f.category == null ? data.channels : data.byCategory[f.category] ?? const <Channel>[];
  if (q.isEmpty) return base;
  return base.where((c) => c.name.toLowerCase().contains(q)).toList(growable: false);
});

bool _isVod(String url) {
  if (!url.contains('/movie/') && !url.contains('/series/')) return false; // cas courant, sans analyse du lien
  final p = Uri.tryParse(url)?.path ?? url;
  return p.contains('/movie/') || p.contains('/series/');
}
