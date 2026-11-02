import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:zelvora_tv/data/m3u_parser.dart';
import 'package:zelvora_tv/data/xmltv.dart';
import 'package:zelvora_tv/domain/channel.dart';

import 'helpers.dart';
import 'live_tv_test.dart' show addPlaylist;

String _d(DateTime t) {
  final u = t.toUtc();
  String two(int v) => v.toString().padLeft(2, '0');
  return '${u.year}${two(u.month)}${two(u.day)}${two(u.hour)}${two(u.minute)}00 +0000';
}

String sampleXmltv(DateTime now) {
  final h = DateTime(now.year, now.month, now.day, now.hour);
  return '''<?xml version="1.0" encoding="UTF-8"?>
<tv>
<channel id="Demo1.fr"><display-name>Chaîne Démo 1</display-name></channel>
<channel id="info.fr"><display-name>FR: Info Test HD</display-name></channel>
<programme start="${_d(h.subtract(const Duration(hours: 1)))}" stop="${_d(h.add(const Duration(hours: 1)))}" channel="demo1.fr"><title lang="fr">Journal &amp; Météo</title><desc>Les infos du jour.</desc></programme>
<programme start="${_d(h.add(const Duration(hours: 1)))}" stop="${_d(h.add(const Duration(hours: 2)))}" channel="demo1.fr"><title>Film du soir</title></programme>
<programme start="${_d(h)}" stop="${_d(h.add(const Duration(hours: 2)))}" channel="info.fr"><title><![CDATA[Info en continu]]></title></programme>
<programme start="${_d(h.add(const Duration(days: 10)))}" stop="${_d(h.add(const Duration(days: 10, hours: 1)))}" channel="info.fr"><title>Trop loin</title></programme>
</tv>''';
}

void main() {
  test('date XMLTV avec fuseau horaire', () {
    expect(parseXmltvDate('20261102043000 +0100'), DateTime.utc(2026, 11, 2, 3, 30).toLocal());
    expect(parseXmltvDate('20261102043000'), DateTime.utc(2026, 11, 2, 4, 30).toLocal());
    expect(parseXmltvDate('n/a'), isNull);
  });

  test('url-tvg lu dans l\'en-tête M3U', () {
    expect(M3uParser.epgUrl('#EXTM3U url-tvg="http://epg.example.com/guide.xml.gz,http://autre"\n#EXTINF:-1,A\nhttp://a'),
        'http://epg.example.com/guide.xml.gz');
    expect(M3uParser.epgUrl('#EXTM3U\n#EXTINF:-1,A\nhttp://a'), isNull);
  });

  for (final gz in [false, true]) {
    test('lecture XMLTV ${gz ? 'compressé' : 'simple'}, découpé en petits morceaux', () async {
      final now = DateTime.now();
      List<int> bytes = utf8.encode(sampleXmltv(now));
      if (gz) bytes = gzip.encode(bytes);
      // Morceaux de 7 octets pour vérifier les coupures au milieu des balises.
      final chunks = [for (var i = 0; i < bytes.length; i += 7) bytes.sublist(i, (i + 7).clamp(0, bytes.length))];
      final idx = await parseXmltv(Stream.fromIterable(chunks),
          from: now.subtract(const Duration(hours: 3)), to: now.add(const Duration(days: 3)));
      final demo = idx.forChannel(const Channel(name: 'x', url: 'u', tvgId: 'Demo1.FR'));
      expect(demo.map((p) => p.title), ['Journal & Météo', 'Film du soir']);
      expect(demo.first.description, 'Les infos du jour.');
      // Rapprochement par le nom quand la playlist n'a pas de tvg-id.
      final info = idx.forChannel(const Channel(name: 'Info Test', url: 'u'));
      expect(info.map((p) => p.title), ['Info en continu'], reason: 'émission hors fenêtre ignorée');
    });
  }

  testWidgets('Guide TV : programmes affichés depuis le guide de la playlist', (tester) async {
    final now = DateTime.now();
    final client = MockClient((req) async {
      if (req.url.path == '/playlist.m3u') {
        return http.Response.bytes(
            utf8.encode(samplePlaylist.replaceFirst('#EXTM3U', '#EXTM3U url-tvg="https://example.com/epg.xml"')), 200);
      }
      if (req.url.path == '/epg.xml') return http.Response.bytes(utf8.encode(sampleXmltv(now)), 200);
      return http.Response('', 404);
    });
    await pumpApp(tester, client: client);
    await addPlaylist(tester, 'https://example.com/playlist.m3u');
    await tester.tap(find.text('Guide TV').first);
    await tester.pumpAndSettle();
    expect(find.text('Journal & Météo'), findsWidgets);
    expect(find.text('Info en continu'), findsOneWidget);
    await tester.tap(find.text('Info en continu'));
    await tester.pumpAndSettle();
    expect(find.text('Info en continu'), findsNWidgets(2), reason: 'détail de l\'émission');
  });
}
