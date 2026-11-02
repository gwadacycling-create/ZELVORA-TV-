import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../domain/channel.dart';
import '../domain/programme.dart';

/// Guide des programmes indexé par chaîne.
class EpgIndex {
  EpgIndex([Map<String, List<Programme>>? byId, Map<String, String>? idByName])
      : byId = byId ?? {},
        idByName = idByName ?? {};

  /// Identifiant de chaîne XMLTV (minuscules) → émissions triées.
  final Map<String, List<Programme>> byId;

  /// Nom de chaîne normalisé → identifiant XMLTV.
  final Map<String, String> idByName;

  bool get isEmpty => byId.isEmpty;

  List<Programme> forChannel(Channel c) {
    final id = c.tvgId?.trim().toLowerCase();
    if (id != null && id.isNotEmpty && byId[id] != null) return byId[id]!;
    final byName = idByName[normalizeName(c.name)];
    return byName == null ? const [] : byId[byName] ?? const [];
  }

  void merge(EpgIndex other) {
    for (final e in other.byId.entries) {
      byId.putIfAbsent(e.key, () => e.value);
    }
    for (final e in other.idByName.entries) {
      idByName.putIfAbsent(e.key, () => e.value);
    }
  }
}

/// Nom simplifié pour rapprocher « FR: TF1 HD » et « TF1 ».
String normalizeName(String name) {
  var s = name.toLowerCase();
  s = s.replaceAll(RegExp(r'^[a-z]{2,3}\s*[:|\-]\s*'), ''); // préfixe pays « fr: »
  s = s.replaceAll(RegExp(r'\b(uhd|fhd|hd|sd|4k|hevc|h265|backup)\b'), '');
  return s.replaceAll(RegExp(r'[^a-z0-9]+'), '');
}

/// Date XMLTV : « 20261102043000 +0100 ».
DateTime? parseXmltvDate(String s) {
  final m = RegExp(r'^(\d{4})(\d{2})(\d{2})(\d{2})(\d{2})(\d{2})?\s*([+-]\d{4})?').firstMatch(s.trim());
  if (m == null) return null;
  int g(int i) => int.parse(m.group(i) ?? '0');
  var t = DateTime.utc(g(1), g(2), g(3), g(4), g(5), g(6));
  final tz = m.group(7);
  if (tz != null) {
    final sign = tz.startsWith('-') ? -1 : 1;
    final off = Duration(hours: int.parse(tz.substring(1, 3)), minutes: int.parse(tz.substring(3, 5)));
    t = sign > 0 ? t.subtract(off) : t.add(off);
  }
  return t.toLocal();
}

String _unescape(String s) => s
    .replaceAll('<![CDATA[', '')
    .replaceAll(']]>', '')
    .replaceAll('&lt;', '<')
    .replaceAll('&gt;', '>')
    .replaceAll('&quot;', '"')
    .replaceAll('&apos;', "'")
    .replaceAll('&#39;', "'")
    .replaceAll('&amp;', '&')
    .trim();

final _attrRe = RegExp(r'''([\w-]+)\s*=\s*("([^"]*)"|'([^']*)')''');
Map<String, String> _attrs(String tag) => {
      for (final m in _attrRe.allMatches(tag)) m.group(1)!.toLowerCase(): m.group(3) ?? m.group(4) ?? '',
    };
String? _child(String block, String name) {
  final m = RegExp('<$name(?:\\s[^>]*)?>([\\s\\S]*?)</$name>').firstMatch(block);
  return m == null ? null : _unescape(m.group(1)!);
}

/// Lecture d'un guide XMLTV (éventuellement compressé .gz) au fil de l'eau :
/// la mémoire reste faible même pour de très gros fichiers. Seules les
/// émissions comprises dans la fenêtre [from, to] sont gardées.
Future<EpgIndex> parseXmltv(Stream<List<int>> bytes, {required DateTime from, required DateTime to}) async {
  final index = EpgIndex();
  var buf = StringBuffer();
  var text = '';

  void consume({bool last = false}) {
    var pos = 0;
    while (true) {
      final p = text.indexOf('<programme', pos);
      final c = text.indexOf('<channel', pos);
      if (p < 0 && c < 0) {
        pos = last ? text.length : (text.length - 20).clamp(pos, text.length);
        break;
      }
      final isProg = p >= 0 && (c < 0 || p < c);
      final start = isProg ? p : c;
      final closeTag = isProg ? '</programme>' : '</channel>';
      final end = text.indexOf(closeTag, start);
      if (end < 0) {
        pos = start;
        break;
      }
      final block = text.substring(start, end + closeTag.length);
      pos = end + closeTag.length;
      final open = block.substring(0, block.indexOf('>') + 1);
      final a = _attrs(open);
      if (isProg) {
        final id = a['channel']?.trim().toLowerCase();
        final s = parseXmltvDate(a['start'] ?? '');
        final e = parseXmltvDate(a['stop'] ?? '');
        if (id == null || s == null || e == null || e.isBefore(from) || s.isAfter(to)) continue;
        index.byId.putIfAbsent(id, () => []).add(Programme(
              start: s,
              stop: e,
              title: _child(block, 'title') ?? '',
              description: _child(block, 'desc') ?? '',
            ));
      } else {
        final id = a['id']?.trim().toLowerCase();
        if (id == null || id.isEmpty) continue;
        for (final m in RegExp(r'<display-name[^>]*>([\s\S]*?)</display-name>').allMatches(block)) {
          final n = normalizeName(_unescape(m.group(1)!));
          if (n.isNotEmpty) index.idByName.putIfAbsent(n, () => id);
        }
      }
    }
    text = text.substring(pos);
  }

  final decoded = await _maybeGunzip(bytes);
  await for (final part in decoded.transform(const Utf8Decoder(allowMalformed: true))) {
    buf.write(part);
    if (buf.length > 256 * 1024) {
      text += buf.toString();
      buf = StringBuffer();
      consume();
    }
  }
  text += buf.toString();
  consume(last: true);
  for (final l in index.byId.values) {
    l.sort((x, y) => x.start.compareTo(y.start));
  }
  return index;
}

/// Détecte un fichier compressé (.gz) sur ses deux premiers octets.
Future<Stream<List<int>>> _maybeGunzip(Stream<List<int>> s) async {
  final it = StreamIterator(s);
  if (!await it.moveNext()) return const Stream.empty();
  final head = it.current;
  Stream<List<int>> all() async* {
    yield head;
    while (await it.moveNext()) {
      yield it.current;
    }
  }

  final gz = head.length > 1 && head[0] == 0x1f && head[1] == 0x8b;
  return gz ? all().transform(gzip.decoder) : all();
}
