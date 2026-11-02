import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:zelvora_tv/data/source_repository.dart';
import 'package:zelvora_tv/domain/iptv_source.dart';

import 'helpers.dart';
import 'xtream_test.dart' show fakeXtream;

String _d(DateTime t) {
  final u = t.toUtc();
  String two(int v) => v.toString().padLeft(2, '0');
  return '${u.year}${two(u.month)}${two(u.day)}${two(u.hour)}${two(u.minute)}00 +0000';
}

void main() {
  testWidgets('Guide TV : « Revoir » lance le replay d’une émission passée', (tester) async {
    final now = DateTime.now();
    final midnight = DateTime(now.year, now.month, now.day);
    var start = now.subtract(const Duration(hours: 2));
    if (start.isBefore(midnight)) start = midnight;
    final stop = now.subtract(const Duration(minutes: 5));
    final xtream = fakeXtream();
    final client = MockClient((r) async {
      if (r.url.path == '/xmltv.php') {
        return http.Response.bytes(
            utf8.encode('<tv><programme start="${_d(start)}" stop="${_d(stop)}" channel="info1"><title>Journal passé</title></programme></tv>'),
            200);
      }
      return xtream.get(r.url);
    });
    final store = MemorySecureStore();
    await SourceRepository(store: store).saveSources([
      IptvSource(
          id: 'x1', name: 'X', kind: SourceKind.xtream, location: 'http://tv.test:8080', addedAt: now, username: 'demo', password: 'secret'),
    ]);
    final playback = await pumpApp(tester, store: store, client: client);
    await tester.tap(find.text('Guide TV').first);
    await tester.pumpAndSettle();
    expect(find.text('Hier'), findsOneWidget, reason: 'jours passés disponibles avec le replay');
    await tester.ensureVisible(find.text('Journal passé'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Journal passé'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Revoir'));
    await tester.pumpAndSettle();
    expect(playback.played.last.url, contains('/timeshift/demo/secret/'));
    expect(playback.played.last.url, endsWith('/101.ts'));
    expect(playback.played.last.vod, isTrue);
  });
}
