import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:http/http.dart' as http;
import 'package:zelvora_tv/data/m3u_parser.dart';
import 'package:zelvora_tv/data/source_repository.dart';
import 'package:zelvora_tv/domain/iptv_source.dart';

void main() {
  group('M3uParser', () {
    test('lit les attributs, groupes et noms', () {
      final list = M3uParser.parse('\uFEFF#EXTM3U x-tvg-url="http://e/epg.xml"\r\n'
          '#EXTINF:-1 tvg-id="a.fr" tvg-name="A HD" tvg-logo="http://l/a.png" group-title="Généraliste",A, la chaîne\r\n'
          'http://s/a.m3u8\r\n'
          '#EXTINF:0,Sans attributs\n'
          '#EXTGRP:Sport\n'
          'http://s/b.ts\n');
      expect(list, hasLength(2));
      expect(list[0].name, 'A, la chaîne');
      expect(list[0].tvgId, 'a.fr');
      expect(list[0].logo, 'http://l/a.png');
      expect(list[0].group, 'Généraliste');
      expect(list[0].url, 'http://s/a.m3u8');
      expect(list[1].name, 'Sans attributs');
      expect(list[1].group, 'Sport');
      expect(list[1].logo, isNull);
    });

    test('virgule dans un attribut entre guillemets', () {
      final list = M3uParser.parse('#EXTM3U\n#EXTINF:-1 group-title="Films, Séries",Titre\nhttp://s/x\n');
      expect(list.single.group, 'Films, Séries');
      expect(list.single.name, 'Titre');
    });

    test('options VLC (user-agent, referrer) et lignes ignorées', () {
      final list = M3uParser.parse('#EXTM3U\n#EXTINF:-1,C\n#KODIPROP:inputstream=x\n'
          '#EXTVLCOPT:http-user-agent=Zelvora/1\n#EXTVLCOPT:http-referrer=http://r/\nhttp://s/c\n'
          '#EXTINF:-1,D\nhttp://s/d\n');
      expect(list[0].headers, {'User-Agent': 'Zelvora/1', 'Referer': 'http://r/'});
      expect(list[1].headers, isEmpty, reason: 'les en-têtes ne débordent pas sur la chaîne suivante');
    });

    test('playlist simple sans #EXTINF', () {
      final list = M3uParser.parse('http://s/live/one.m3u8\nhttp://s/two.ts\n');
      expect(list.map((c) => c.name), ['one.m3u8', 'two.ts']);
    });

    test('nom de secours : tvg-name', () {
      final list = M3uParser.parse('#EXTINF:-1 tvg-name="Nom TVG",\nhttp://s/x\n');
      expect(list.single.name, 'Nom TVG');
    });

    test('grande playlist (50 000 chaînes) en moins d’une seconde', () {
      final b = StringBuffer('#EXTM3U\n');
      for (var i = 0; i < 50000; i++) {
        b.writeln('#EXTINF:-1 tvg-id="c$i" tvg-logo="http://l/$i.png" group-title="G${i % 40}",Chaîne $i');
        b.writeln('http://s/live/$i.ts');
      }
      final sw = Stopwatch()..start();
      final list = M3uParser.parse(b.toString());
      sw.stop();
      expect(list, hasLength(50000));
      expect(sw.elapsedMilliseconds, lessThan(1000));
    });
  });

  group('SourceRepository', () {
    test('envoie un User-Agent de lecteur reconnu', () async {
      String? ua;
      final repo = SourceRepository(
        store: MemorySecureStore(),
        client: MockClient((r) async {
          ua = r.headers['User-Agent'];
          return http.Response('#EXTM3U\n#EXTINF:-1,A\nhttp://s/a\n', 200);
        }),
      );
      await repo.fetchChannels(IptvSource(id: 'x', name: 'n', kind: SourceKind.m3uUrl, location: 'http://h/p', addedAt: DateTime(2026)));
      expect(ua, kIptvUserAgent);
    });

    test('un lien direct vers un flux HLS devient une chaîne', () async {
      final repo = SourceRepository(
        store: MemorySecureStore(),
        client: MockClient((r) async => http.Response(
            '#EXTM3U\n#EXT-X-STREAM-INF:BANDWIDTH=1280000\nlow/index.m3u8\n', 200,
            headers: {'content-type': 'application/vnd.apple.mpegurl'})),
      );
      final list = await repo.fetchChannels(IptvSource(
          id: 'x', name: 'Mon flux', kind: SourceKind.m3uUrl, location: 'https://cdn.test/master.m3u8', addedAt: DateTime(2026)));
      expect(list.single.name, 'Mon flux');
      expect(list.single.url, 'https://cdn.test/master.m3u8');
    });

    test('accès refusé : message explicite', () async {
      final repo = SourceRepository(store: MemorySecureStore(), client: MockClient((r) async => http.Response('', 403)));
      await expectLater(
          repo.fetchChannels(IptvSource(id: 'x', name: 'n', kind: SourceKind.m3uUrl, location: 'http://h/p', addedAt: DateTime(2026))),
          throwsA(predicate((e) => e.toString().contains('Accès refusé'))));
    });

    IptvSource src(String loc, [SourceKind k = SourceKind.m3uUrl]) =>
        IptvSource(id: 's1', name: 'Test', kind: k, location: loc, addedAt: DateTime(2026));

    test('enregistre les sources dans le coffre-fort et les relit', () async {
      final store = MemorySecureStore();
      final repo = SourceRepository(store: store);
      await repo.saveSources([src('http://user:pass@h/p.m3u')]);
      expect(store.data.keys.single, 'zelvora.sources.v1');
      final back = await repo.loadSources();
      expect(back.single.location, 'http://user:pass@h/p.m3u');
      expect(back.single.displayLocation, 'h', reason: 'identifiants jamais affichés');
    });

    test('télécharge et lit une playlist (accents en UTF-8 ou Latin-1)', () async {
      final repo = SourceRepository(
        store: MemorySecureStore(),
        client: MockClient((r) async => http.Response.bytes(
            [...'#EXTM3U\n#EXTINF:-1,T'.codeUnits, 0xE9, ...'l\nhttp://s/1\n'.codeUnits], 200)),
      );
      final list = await repo.fetchChannels(src('https://h/p.m3u'));
      expect(list.single.name, 'Tél');
      expect(list.single.sourceId, 's1');
    });

    test('messages d’erreur clairs', () async {
      final repo = SourceRepository(
        store: MemorySecureStore(),
        client: MockClient((r) async => r.url.path == '/404' ? http.Response('', 404) : http.Response('<html>', 200)),
        readFile: (_) async => throw Exception('absent'),
      );
      expect(() => repo.fetchChannels(src('ftp://h/x')), throwsA(isA<SourceException>()));
      await expectLater(repo.fetchChannels(src('https://h/404')),
          throwsA(predicate((e) => e.toString().contains('introuvable'))));
      await expectLater(repo.fetchChannels(src('https://h/page')),
          throwsA(predicate((e) => e.toString().contains('Aucune chaîne'))));
      await expectLater(repo.fetchChannels(src('C:/x.m3u', SourceKind.m3uFile)),
          throwsA(predicate((e) => e.toString().contains('Fichier'))));
    });
  });
}
