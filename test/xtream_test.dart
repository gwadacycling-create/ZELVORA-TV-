import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:zelvora_tv/data/source_repository.dart';
import 'package:zelvora_tv/data/xtream_client.dart';
import 'package:zelvora_tv/domain/iptv_source.dart';
import 'package:zelvora_tv/domain/programme.dart';

import 'helpers.dart';

http.Response _json(String body, int code) => http.Response.bytes(utf8.encode(body), code);

/// Faux serveur Xtream (aucune donnée réelle).
http.Client fakeXtream({String auth = '1', String status = 'Active', int? exp, List<String> formats = const ['m3u8', 'ts']}) =>
    MockClient((r) async {
      if (r.url.path != '/player_api.php') return http.Response('', 404);
      final q = r.url.queryParameters;
      if (q['username'] != 'demo' || q['password'] != 'secret') {
        return _json(jsonEncode({'user_info': {'auth': 0}}), 200);
      }
      switch (q['action']) {
        case null:
          return _json(
              jsonEncode({
                'user_info': {
                  'auth': int.parse(auth),
                  'status': status,
                  'exp_date': '${exp ?? DateTime.now().add(const Duration(days: 30)).millisecondsSinceEpoch ~/ 1000}',
                  'max_connections': '1',
                  'allowed_output_formats': formats,
                },
                'server_info': {'url': 'tv.test', 'port': '8080', 'timestamp_now': 1793700000, 'time_now': '2026-11-03 11:00:00'},
              }),
              200);
        case 'get_live_categories':
          return _json(
              jsonEncode([
                {'category_id': '1', 'category_name': 'Infos'},
                {'category_id': '2', 'category_name': 'Sport'},
              ]),
              200);
        case 'get_live_streams':
          return _json(
              jsonEncode([
                {'num': 1, 'name': 'Info Une', 'stream_id': 101, 'stream_icon': 'http://l/1.png', 'epg_channel_id': 'info1', 'category_id': '1', 'tv_archive': 1, 'tv_archive_duration': '3'},
                {'num': 2, 'name': 'Sport Deux', 'stream_id': 202, 'stream_icon': '', 'epg_channel_id': null, 'category_id': '2'},
              ]),
              200);
        case 'get_vod_categories':
          return _json(jsonEncode([{'category_id': '5', 'category_name': 'Action'}, {'category_id': '6', 'category_name': 'Comédie'}]), 200);
        case 'get_vod_streams':
          return _json(
              jsonEncode([
                {'name': 'Film Démo (2024)', 'stream_id': 501, 'stream_icon': '', 'rating': '7.4', 'category_id': '5', 'container_extension': 'mkv'},
                {'name': 'Comédie Test', 'stream_id': 502, 'stream_icon': null, 'rating': '', 'category_id': '6', 'container_extension': 'mp4'},
              ]),
              200);
        case 'get_vod_info':
          return _json(jsonEncode({'info': {'plot': 'Un film de démonstration.', 'genre': 'Action', 'duration': '01:45:00'}}), 200);
        case 'get_series_categories':
          return _json(jsonEncode([{'category_id': '9', 'category_name': 'Drames'}]), 200);
        case 'get_series':
          return _json(jsonEncode([{'name': 'Série Démo', 'series_id': 77, 'cover': '', 'plot': 'Une série.', 'category_id': '9'}]), 200);
        case 'get_series_info':
          return _json(
              jsonEncode({
                'info': {'plot': 'Une série de démonstration.'},
                'episodes': {
                  '1': [
                    {'id': '901', 'episode_num': 1, 'title': 'Le début', 'container_extension': 'mp4', 'season': 1, 'info': {'plot': 'Premier épisode.'}},
                    {'id': '902', 'episode_num': 2, 'title': 'La suite', 'container_extension': 'mp4', 'season': 1, 'info': {}},
                  ],
                  '2': [
                    {'id': '911', 'episode_num': 1, 'title': 'Retour', 'container_extension': 'mkv', 'season': 2, 'info': {}},
                  ],
                },
              }),
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

  test('replay : lien timeshift à l’heure du serveur, seulement si la chaîne le permet', () async {
    final repo = SourceRepository(store: MemorySecureStore(), client: fakeXtream());
    final list = await repo.fetchChannels(src());
    expect(list[0].archiveDays, 3);
    expect(list[0].catchupOffsetMin, 60);
    expect(list[1].archiveDays, 0);
    final now = DateTime.now();
    final p = Programme(
      start: DateTime.utc(2026, 11, 1, 19, 5),
      stop: DateTime.utc(2026, 11, 1, 20, 35),
      title: 'Journal',
    );
    final r = list[0].replay(p);
    expect(r.url, 'http://tv.test:8080/timeshift/demo/secret/90/2026-11-01:20-05/101.ts');
    expect(r.vod, isTrue);
    expect(r.name, 'Journal · Info Une');
    final recent = Programme(start: now.subtract(const Duration(hours: 2)), stop: now.subtract(const Duration(hours: 1)), title: 'a');
    final old = Programme(start: now.subtract(const Duration(days: 4)), stop: now.subtract(const Duration(days: 4)), title: 'b');
    final future = Programme(start: now.add(const Duration(hours: 1)), stop: now.add(const Duration(hours: 2)), title: 'c');
    expect(list[0].canReplay(recent), isTrue);
    expect(list[0].canReplay(old), isFalse);
    expect(list[0].canReplay(future), isFalse);
    expect(list[1].canReplay(recent), isFalse);
  });

  test('fuseau du serveur', () {
    expect(serverUtcOffset({'timestamp_now': 1793700000, 'time_now': '2026-11-03 05:00:00'}), -300);
    expect(serverUtcOffset({'url': 'x'}), isNull);
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
