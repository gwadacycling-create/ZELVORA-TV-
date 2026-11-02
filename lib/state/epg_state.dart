import 'dart:async';
import 'dart:isolate';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../data/source_repository.dart' show kIptvUserAgent;
import '../data/xmltv.dart';
import '../domain/channel.dart';
import '../domain/programme.dart';
import 'sources_state.dart';

/// Télécharge et lit un guide XMLTV. En dehors des tests, le travail se fait
/// dans un fil séparé pour ne jamais ralentir l'interface.
typedef EpgLoader = Future<EpgIndex> Function(String url, DateTime from, DateTime to);

Future<EpgIndex> downloadXmltv(String url, DateTime from, DateTime to, {http.Client? client}) async {
  final c = client ?? http.Client();
  try {
    final req = http.Request('GET', Uri.parse(url))..headers['User-Agent'] = kIptvUserAgent;
    final res = await c.send(req).timeout(const Duration(seconds: 60));
    if (res.statusCode != 200) return EpgIndex();
    return await parseXmltv(res.stream, from: from, to: to).timeout(const Duration(minutes: 5));
  } catch (_) {
    return EpgIndex();
  } finally {
    if (client == null) c.close();
  }
}

final epgLoaderProvider = Provider<EpgLoader>(
  (ref) => (url, from, to) => Isolate.run(() => downloadXmltv(url, from, to)),
);

/// Guide TV de toutes les sources, rechargé toutes les 6 heures.
final epgProvider = FutureProvider<EpgIndex>((ref) async {
  final sources = await ref.watch(sourcesProvider.future);
  final data = await ref.watch(channelsProvider.future); // les adresses M3U sont connues après le chargement
  final repo = ref.read(sourceRepositoryProvider);
  final load = ref.read(epgLoaderProvider);
  final now = DateTime.now();
  // Avec le replay, on garde aussi les émissions des jours passés.
  final past = replayDays(data.channels);
  final from = past == 0
      ? now.subtract(const Duration(hours: 3))
      : DateTime(now.year, now.month, now.day - past);
  final to = now.add(const Duration(days: 3));
  final timer = Timer(const Duration(hours: 6), ref.invalidateSelf);
  ref.onDispose(timer.cancel);

  final index = EpgIndex();
  final urls = {for (final s in sources) ?repo.epgUrlFor(s)};
  final parts = await Future.wait(urls.map((u) => load(u, from, to)));
  for (final p in parts) {
    index.merge(p);
  }
  return index;
});

/// Nombre de jours passés consultables dans le guide (replay), au plus [kMaxReplayDays].
const kMaxReplayDays = 2;
int replayDays(List<Channel> channels) {
  var m = 0;
  for (final c in channels) {
    if (c.catchup != null && c.archiveDays > m) {
      m = c.archiveDays;
      if (m >= kMaxReplayDays) return kMaxReplayDays;
    }
  }
  return m;
}

/// Émissions d'une chaîne (liste vide si pas de guide).
List<Programme> programmesOf(EpgIndex? epg, Channel c) => epg?.forChannel(c) ?? const [];

/// Émission en cours et suivante.
(Programme?, Programme?) nowNext(List<Programme> list, DateTime now) {
  for (var i = 0; i < list.length; i++) {
    if (list[i].isOnAt(now)) return (list[i], i + 1 < list.length ? list[i + 1] : null);
    if (list[i].start.isAfter(now)) return (null, list[i]);
  }
  return (null, null);
}
