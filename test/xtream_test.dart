import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:zelvora_tv/data/source_repository.dart';
import 'package:zelvora_tv/data/xtream_client.dart';
import 'package:zelvora_tv/domain/iptv_source.dart';

import 'helpers.dart';

/// Faux serveur Xtream (aucune donnée réelle).
http.Client fakeXtream({String auth = '1', String status = 'Active', int? exp, List<String> formats = const ['m3u8', 'ts']}) =>
    MockClient((r) async {
      if (r.url.path != '/player_api.php') return http.Response('', 404);
      final q = r.url.queryParameters;
      if (q['username'] != 'demo' || q['password'] != 'secret') {
        return http.Response(jsonEncode({'user_info': {'auth': 0}}), 200);
      }
      switch (q['action']) {
        case null:
          return http.Response(
              jsonEncode({
                'user_info': {
                  'auth': int.parse(auth),
                  'status': status,
                  'exp_date': '${exp ?? DateTime.now().add(const Duration(days: 30)).millisecondsSinceEpoch ~/ 1000}',
                  'max_connections': '1',
                  'allowed_output_formats': formats,
                },
                'server_info': {'url': 'tv.test', 'port': '8080'},
              }),
              200);
        case 'get_live_categories':
          return http.Response(
              jsonEncode([
                {'category_id': '1', 'category_name': 'Infos'},
                {'category_id': '2', 'category_name': 'Sport'},
              ]),
              200);
        case 'get_live_streams':
          return http.Response(
              jsonEncode([
                {'num': 1, 'name': 'Info Une', 'stream_id': 101, 'stream_icon': 'http://l/1.png', 'epg_channel_id': 'info1', 'category_id': '1'},
                {'num': 2, 'name': 'Sport Deux', 'stream_id': 202, 'stream_icon': '', 'epg_channel_id': null, 'category_id': '2'},
              ]),
              200);
      }
      return http.Response('[]', 200);
    });

void main() {
  test('normalisation de l’adresse du serveur', () {
    expect(XtreamClient.normalizeServer('tv.test:8080').toString(), 'http://tv.test:8080');
    expect(XtreamClient.normalizeServer('https://tv.test/').toString(), 'https://tv.test');
    expect(XtreamClient.normalizeServer('http://tv.test:8080/get.php?username=a&password=b').toString(), 'http://tv.test:8080');
    expect(() => XtreamClient.normalizeServer('ftp://x'), throwsA(isA<XtreamException>()));
  });

  IptvSource src({String user = 'demo', String pass = 'secret'}) => IptvSource(
      id: 'x1', name: 'Xt', kind: SourceKind.xtream, location: 'tv.test:8080', addedAt: DateTime(2026), username: user, password: pass);

  test('chaînes, catégories, logos et liens de lecture', () async {
    final repo = SourceRepository(store: MemorySecureStore(), client: fakeXtream());
    final list = await repo.fetchChannels(src());
    expect(list, hasLength(2));
    expect(list[0].name, 'Info Une');
    expect(list[0].group, 'Infos');
    expect(list[0].logo, 'http://l/1.png');
    expect(list[0].tvgId, 'info1');
    expect(list[0].url, 'http://tv.test:8080/live/demo/secret/101.ts');
    expect(list[1].logo, isNull);
    expect(list[1].sourceId, 'x1');
  });

  test('format m3u8 si le serveur n’autorise pas ts', () async {
    final repo = SourceRepository(store: MemorySecureStore(), client: fakeXtream(formats: ['m3u8']));
    final list = await repo.fetchChannels(src());
    expect(list[0].url, endsWith('/101.m3u8'));
  });

  test('erreurs claires : mauvais mot de passe, expiré, inactif', () async {
    Future<String> err(http.Client c, [IptvSource? s]) async {
      try {
        await SourceRepository(store: MemorySecureStore(), client: c).fetchChannels(s ?? src());
        return '';
      } catch (e) {
        return e.toString();
      }
    }

    expect(await err(fakeXtream(), src(pass: 'faux')), contains('incorrect'));
    expect(await err(fakeXtream(exp: 1000000)), contains('expiré'));
    expect(await err(fakeXtream(status: 'Banned')), contains('inactif'));
    expect(await err(MockClient((_) async => http.Response('<html>', 200))), contains('compatible'));
  });

  test('identifiants enregistrés uniquement dans le coffre-fort', () async {
    final store = MemorySecureStore();
    await SourceRepository(store: store).saveSources([src()]);
    final back = await SourceRepository(store: store).loadSources();
    expect(back.single.username, 'demo');
    expect(back.single.password, 'secret');
    expect(back.single.displayLocation, 'tv.test');
  });

  testWidgets('Ajout d’un compte Xtream depuis les réglages', (tester) async {
    final store = MemorySecureStore();
    await pumpApp(tester, store: store, client: fakeXtream());
    await tester.tap(find.text('Réglages').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Compte Xtream Codes'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('xt-server')), 'http://tv.test:8080');
    await tester.enterText(find.byKey(const Key('xt-user')), 'demo');
    await tester.enterText(find.byKey(const Key('xt-pass')), 'secret');
    await tester.tap(find.byType(Checkbox));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Se connecter'));
    await tester.pumpAndSettle();
    expect(find.text('Compte Xtream ajouté : 2 chaînes.'), findsOneWidget);
    expect(find.textContaining('Xtream Codes · tv.test · 2 chaînes'), findsOneWidget);
    expect(find.textContaining('secret'), findsNothing, reason: 'mot de passe jamais affiché');

    await tester.tap(find.text('TV en direct').first);
    await tester.pumpAndSettle();
    expect(find.text('Info Une'), findsOneWidget);
    expect(find.text('Sport'), findsWidgets);
  });
}
