import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/app_theme.dart';
import '../domain/channel.dart';
import 'sources_state.dart';

const kFavoritesKey = 'zelvora.favorites.v1';
const kHistoryKey = 'zelvora.history.v1';

/// Chaînes favorites (identifiants), enregistrées de façon chiffrée sur l'appareil.
final favoritesProvider = NotifierProvider<FavoritesNotifier, List<String>>(FavoritesNotifier.new);

class FavoritesNotifier extends Notifier<List<String>> {
  bool _loaded = false;

  @override
  List<String> build() {
    _load();
    return const [];
  }

  Future<void> _load() async {
    try {
      final raw = await ref.read(secureStoreProvider).read(kFavoritesKey);
      if (raw != null && !_loaded) state = List<String>.from(jsonDecode(raw) as List);
    } catch (_) {}
    _loaded = true;
  }

  bool contains(Channel c) => state.contains(c.key);

  /// Ajoute ou retire ; renvoie true si la chaîne est maintenant en favori.
  Future<bool> toggle(Channel c) async {
    _loaded = true;
    final added = !state.contains(c.key);
    state = added ? [c.key, ...state] : state.where((k) => k != c.key).toList();
    await ref.read(secureStoreProvider).write(kFavoritesKey, jsonEncode(state));
    return added;
  }
}

class HistoryEntry {
  const HistoryEntry(this.key, this.at);
  final String key;
  final DateTime at;
  Map<String, dynamic> toJson() => {'k': key, 't': at.toIso8601String()};
  static HistoryEntry fromJson(Map<String, dynamic> j) => HistoryEntry(j['k'] as String, DateTime.parse(j['t'] as String));
}

/// Dernières chaînes regardées (50 au maximum, la plus récente en premier).
final historyProvider = NotifierProvider<HistoryNotifier, List<HistoryEntry>>(HistoryNotifier.new);

class HistoryNotifier extends Notifier<List<HistoryEntry>> {
  static const max = 50;
  bool _loaded = false;

  @override
  List<HistoryEntry> build() {
    _load();
    return const [];
  }

  Future<void> _load() async {
    try {
      final raw = await ref.read(secureStoreProvider).read(kHistoryKey);
      if (raw != null && !_loaded) {
        state = [for (final e in jsonDecode(raw) as List) HistoryEntry.fromJson(Map<String, dynamic>.from(e as Map))];
      }
    } catch (_) {}
    _loaded = true;
  }

  Future<void> add(Channel c, {DateTime? at}) async {
    _loaded = true;
    state = [HistoryEntry(c.key, at ?? DateTime.now()), ...state.where((e) => e.key != c.key)].take(max).toList();
    await _save();
  }

  Future<void> clear() async {
    _loaded = true;
    state = const [];
    await _save();
  }

  Future<void> _save() =>
      ref.read(secureStoreProvider).write(kHistoryKey, jsonEncode([for (final e in state) e.toJson()]));
}

/// Retrouve les chaînes chargées à partir de leurs identifiants (dans l'ordre).
List<Channel> resolveChannels(Iterable<String> keys, List<Channel> all) {
  final byKey = {for (final c in all) c.key: c};
  return [for (final k in keys) ?byKey[k]];
}

/// Bouton cœur : ajoute / retire la chaîne des favoris.
class FavoriteButton extends ConsumerWidget {
  const FavoriteButton({super.key, required this.channel, this.size = 22, this.filled = false});
  final Channel channel;
  final double size;
  final bool filled;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fav = ref.watch(favoritesProvider).contains(channel.key);
    final icon = Icon(fav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
        color: fav ? AppColors.accent : AppColors.textSecondary, size: size);
    final tooltip = fav ? 'Retirer des favoris (F)' : 'Ajouter aux favoris (F)';
    void onPressed() => ref.read(favoritesProvider.notifier).toggle(channel);
    return filled
        ? IconButton.filledTonal(key: const Key('favorite-toggle'), onPressed: onPressed, icon: icon, tooltip: tooltip)
        : IconButton(key: const Key('favorite-toggle'), onPressed: onPressed, icon: icon, tooltip: tooltip);
  }
}
