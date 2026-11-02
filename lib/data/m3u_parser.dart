import '../domain/channel.dart';

/// Lecture des playlists M3U / M3U8 « étendues » (format IPTV courant).
///
/// Gère : #EXTINF avec attributs (tvg-id, tvg-name, tvg-logo, group-title),
/// #EXTGRP, #EXTVLCOPT (user-agent, referrer), BOM, fins de ligne Windows,
/// et les playlists simples (une URL par ligne).
class M3uParser {
  static final _attr = RegExp(r'([\w-]+)="([^"]*)"');

  static List<Channel> parse(String content) {
    final channels = <Channel>[];
    var text = content;
    if (text.startsWith('﻿')) text = text.substring(1);

    Map<String, String> attrs = {};
    String? title;
    String? group;
    final headers = <String, String>{};

    void reset() {
      attrs = {};
      title = null;
      group = null;
      headers.clear();
    }

    for (final raw in text.split(RegExp(r'\r?\n|\r'))) {
      final line = raw.trim();
      if (line.isEmpty) continue;

      if (line.startsWith('#EXTINF')) {
        reset();
        final colon = line.indexOf(':');
        final body = colon >= 0 ? line.substring(colon + 1) : '';
        final comma = _titleComma(body);
        final meta = comma >= 0 ? body.substring(0, comma) : body;
        title = comma >= 0 ? body.substring(comma + 1).trim() : null;
        for (final m in _attr.allMatches(meta)) {
          attrs[m.group(1)!.toLowerCase()] = m.group(2)!.trim();
        }
      } else if (line.startsWith('#EXTGRP:')) {
        group = line.substring(8).trim();
      } else if (line.startsWith('#EXTVLCOPT:')) {
        final opt = line.substring(11);
        final eq = opt.indexOf('=');
        if (eq > 0) {
          final k = opt.substring(0, eq).trim().toLowerCase();
          final v = opt.substring(eq + 1).trim();
          if (k == 'http-user-agent') headers['User-Agent'] = v;
          if (k == 'http-referrer' || k == 'http-referer') headers['Referer'] = v;
        }
      } else if (line.startsWith('#')) {
        continue; // #EXTM3U, #KODIPROP, commentaires...
      } else {
        // Une ligne de flux doit suivre un #EXTINF ou ressembler à un lien.
        if (title == null && attrs.isEmpty && !line.contains('://')) continue;
        final name = (title?.isNotEmpty ?? false)
            ? title!
            : (attrs['tvg-name']?.isNotEmpty ?? false)
                ? attrs['tvg-name']!
                : _nameFromUrl(line);
        final g = attrs['group-title']?.isNotEmpty ?? false ? attrs['group-title']! : (group ?? '');
        final logo = attrs['tvg-logo'];
        channels.add(Channel(
          name: name,
          url: line,
          group: g,
          logo: (logo == null || logo.isEmpty) ? null : logo,
          tvgId: (attrs['tvg-id']?.isEmpty ?? true) ? null : attrs['tvg-id'],
          headers: Map.unmodifiable(headers),
        ));
        reset();
      }
    }
    return channels;
  }

  /// Trouve la virgule qui sépare les attributs du nom, en ignorant
  /// les virgules placées entre guillemets.
  static int _titleComma(String s) {
    var inQuotes = false;
    for (var i = 0; i < s.length; i++) {
      final c = s[i];
      if (c == '"') inQuotes = !inQuotes;
      if (c == ',' && !inQuotes) return i;
    }
    return -1;
  }

  static String _nameFromUrl(String url) {
    final uri = Uri.tryParse(url);
    final seg = uri?.pathSegments.where((s) => s.isNotEmpty).toList() ?? const [];
    return seg.isEmpty ? url : seg.last;
  }
}
