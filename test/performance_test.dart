import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:zelvora_tv/core/background.dart';
import 'package:zelvora_tv/data/source_repository.dart';
import 'package:zelvora_tv/data/xtream_client.dart';
import 'package:zelvora_tv/domain/iptv_source.dart';
import 'package:zelvora_tv/state/sources_state.dart';

import 'helpers.dart';
import 'live_tv_test.dart' show addPlaylist;

/// Mesures de performance (aucune donnée réelle : chaînes générées).
String _playlist(int n) {
  final b = StringBuffer('#EXTM3U\n');
  for (var i = 0; i < n; i++) {
    b.writeln('#EXTINF:-1 tvg-id="ch$i.fr" tvg-name="FR: Chaine $i" tvg-logo="http://logo.test/$i.png" '
        'group-title="Catégorie ${i % 60}",FR: Chaine $i');
    b.writeln(i % 4 == 0 ? 'http://srv.test/movie/u/p/$i.mkv' : 'http://srv.test/u/p/$i.ts');
  }
  return b.toString();
}

String _xtream(String action, int n) => switch (action) {
      'get_live_categories' => jsonEncode([for (var i = 0; i < 60; i++) {'category_id': '$i', 'category_name': 'Cat $i'}]),
      'get_live_streams' => jsonEncode([
          for (var i = 0; i < n; i++)
            {'name': 'FR: Chaine $i', 'stream_id': i, 'stream_icon': 'http://logo.test/$i.png', 'epg_channel_id': 'ch$i', 'category_id': '${i % 60}'}
        ]),
      _ => jsonEncode({'user_info': {'auth': 1, 'status': 'Active', 'allowed_output_formats': ['ts']}}),
    };

/// Plus long blocage de l'écran (fil principal) pendant [work], en ms.
Future<int> _longestFreeze(Future<void> Function() work) async {
  var longest = 0;
  var last = DateTime.now();
  final t = Timer.periodic(const Duration(milliseconds: 5), (_) {
    final now = DateTime.now();
    final gap = now.difference(last).inMilliseconds;
    if (gap > longest) longest = gap;
    last = now;
  });
  await work();
  t.cancel();
  final gap = DateTime.now().difference(last).inMilliseconds;
  return gap > longest ? gap : longest;
}

void main() {
  widgetChecks();
  for (final n in [100, 1000, 5000, 10000, 50000, 150000]) {
    test('M3U et Xtream $n chaînes : écran jamais figé', () async {
      final body = utf8.encode(_playlist(n));
      final m3u = SourceRepository(
          store: MemorySecureStore(), client: MockClient((_) async => http.Response.bytes(body, 200)));
      final src = IptvSource(id: 's', name: 'n', kind: SourceKind.m3uUrl, location: 'http://h/p.m3u', addedAt: DateTime(2026));
      final replies = {for (final a in ['', 'get_live_categories', 'get_live_streams']) a: utf8.encode(_xtream(a, n))};
      final xt = MockClient((r) async => http.Response.bytes(replies[r.url.queryParameters['action'] ?? '']!, 200));
      final res = <String>[];
      for (final bg in [false, true]) {
        useBackgroundThread = bg;
        var count = 0;
        final f1 = await _longestFreeze(() async => count = (await m3u.fetchChannels(src)).length);
        expect(count, n);
        final f2 = await _longestFreeze(() async {
          final c = XtreamClient(server: 'http://x.test', username: 'u', password: 'p', httpClient: xt, userAgent: 'ua');
          count = (await c.liveChannels()).length;
        });
        expect(count, n);
        res.add('${bg ? 'APRÈS' : 'AVANT'} : M3U ${f1}ms, Xtream ${f2}ms');
      }
      // Changement de catégorie (données déjà en mémoire).
      final all = await m3u.fetchChannels(src);
      final data = ChannelsData(all, const {});
      final sw = Stopwatch()..start();
      for (final cat in data.categories) {
        data.byCategory[cat]!.length;
      }
      final perSwitch = sw.elapsedMicroseconds / data.categories.length;
      // ignore: avoid_print
      print('$n chaînes | plus long blocage de l’écran — ${res.join(' | ')} | changement de catégorie ${perSwitch.toStringAsFixed(1)} µs');
      useBackgroundThread = false;
    }, timeout: const Timeout(Duration(minutes: 5)));
  }
}

/// Clics rapides sur plusieurs catégories avec 10 000 chaînes (logos absents) :
/// seule la dernière catégorie choisie s'affiche.
void widgetChecks() {
  testWidgets('clics rapides : la dernière catégorie gagne', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1600, 1000));
    await pumpApp(tester, client: fakeHttp(_playlist(10000)));
    await addPlaylist(tester, 'https://example.com/playlist.m3u');
    await tester.tap(find.text('TV en direct').first);
    await tester.pumpAndSettle();
    final sw = Stopwatch()..start();
    for (final c in ['Catégorie 1', 'Catégorie 2', 'Catégorie 3']) {
      await tester.tap(find.text(c).first);
      await tester.pump();
    }
    final perClick = sw.elapsedMilliseconds / 3;
    await tester.pumpAndSettle();
    // Catégorie 3 : 167 chaînes (aucun film dans cette catégorie).
    expect(find.text('Chaînes (167)'), findsOneWidget);
    expect(find.text('FR: Chaine 3'), findsWidgets);
    expect(find.text('FR: Chaine 1'), findsNothing);
    // ignore: avoid_print
    print('Clic sur une catégorie (10 000 chaînes, affichage compris) : ${perClick.toStringAsFixed(0)} ms');
    await tester.binding.setSurfaceSize(null);
  });
}
