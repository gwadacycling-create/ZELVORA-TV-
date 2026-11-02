import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:zelvora_tv/data/source_repository.dart';
import 'package:zelvora_tv/domain/iptv_source.dart';
import 'package:zelvora_tv/state/sources_state.dart';

import 'helpers.dart';

String playlist(List<String> names) =>
    '#EXTM3U\n${[for (final n in names) '#EXTINF:-1 group-title="Test",$n\nhttp://x/$n.ts'].join('\n')}\n';

void main() {
  test('actualisation discrète : nouvelles chaînes, ancienne liste gardée si erreur', () async {
    var body = playlist(['A']);
    var fail = false;
    final store = MemorySecureStore();
    final repo = SourceRepository(
      store: store,
      client: MockClient((r) async => fail ? http.Response('', 500) : http.Response(body, 200)),
    );
    await repo.saveSources([
      IptvSource(id: 's', name: 'S', kind: SourceKind.m3uUrl, location: 'http://p/list.m3u', addedAt: DateTime(2026)),
    ]);
    final c = ProviderContainer(overrides: [sourceRepositoryProvider.overrideWithValue(repo)]);
    addTearDown(c.dispose);
    expect((await c.read(channelsProvider.future)).channels.map((e) => e.name), ['A']);

    body = playlist(['A', 'B']);
    await c.read(silentRefreshProvider)();
    expect((await c.read(channelsProvider.future)).channels.map((e) => e.name), ['A', 'B']);

    fail = true;
    await c.read(silentRefreshProvider)();
    expect((await c.read(channelsProvider.future)).channels.map((e) => e.name), ['A', 'B']);
  });

  testWidgets('touche Retour : revient à l\'Accueil au lieu de quitter', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.text('Réglages').first);
    await tester.pumpAndSettle();
    String path() => GoRouter.of(tester.element(find.byType(Scaffold).first)).routerDelegate.currentConfiguration.uri.path;
    expect(path(), '/settings');
    final handled = await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(handled, isTrue);
    expect(path(), '/');
  });
}
