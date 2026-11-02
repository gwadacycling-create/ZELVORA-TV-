import 'dart:convert';

import 'package:http/http.dart' as http;

import '../domain/channel.dart';
import '../domain/vod.dart';

class XtreamException implements Exception {
  XtreamException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Informations du compte renvoyées par le serveur.
class XtreamAccount {
  const XtreamAccount({required this.status, this.expiresAt, this.maxConnections, this.formats = const []});
  final String status;
  final DateTime? expiresAt;
  final int? maxConnections;
  final List<String> formats;
}

/// Client de l'API Xtream Codes (player_api.php).
class XtreamClient {
  XtreamClient({required String server, required this.username, required this.password, required this.httpClient, required this.userAgent})
      : base = normalizeServer(server);

  final Uri base;
  final String username;
  final String password;
  final String userAgent;
  final http.Client httpClient;

  /// Accepte « exemple.com:8080 », « http://exemple.com:8080/ » ou un lien
  /// complet « .../get.php?username=... » et garde seulement l'adresse du serveur.
  static Uri normalizeServer(String input) {
    var s = input.trim();
    if (!s.contains('://')) s = 'http://$s';
    final u = Uri.tryParse(s);
    if (u == null || u.host.isEmpty || !(u.isScheme('http') || u.isScheme('https'))) {
      throw XtreamException('Adresse du serveur invalide (exemple : http://serveur.com:8080).');
    }
    return Uri(scheme: u.scheme, host: u.host, port: u.hasPort ? u.port : null);
  }

  Uri _api([Map<String, String> extra = const {}]) => base.replace(
        path: '/player_api.php',
        queryParameters: {'username': username, 'password': password, ...extra},
      );

  Future<dynamic> _get(Map<String, String> extra) async {
    final http.Response res;
    try {
      res = await httpClient.get(_api(extra), headers: {'User-Agent': userAgent}).timeout(const Duration(seconds: 45));
    } catch (_) {
      throw XtreamException('Impossible de joindre le serveur Xtream. Vérifiez l’adresse et votre connexion.');
    }
    if (res.statusCode == 401 || res.statusCode == 403) {
      throw XtreamException('Accès refusé par le serveur (${res.statusCode}) : identifiant, mot de passe ou abonnement à vérifier.');
    }
    if (res.statusCode != 200) {
      throw XtreamException('Le serveur Xtream a répondu avec une erreur (${res.statusCode}).');
    }
    try {
      return jsonDecode(utf8.decode(res.bodyBytes, allowMalformed: true));
    } catch (_) {
      throw XtreamException('Réponse inattendue : ce serveur ne semble pas compatible Xtream Codes.');
    }
  }

  Future<XtreamAccount> authenticate() async {
    final j = await _get(const {});
    if (j is! Map || j['user_info'] is! Map) {
      throw XtreamException('Réponse inattendue : ce serveur ne semble pas compatible Xtream Codes.');
    }
    final u = j['user_info'] as Map;
    if ('${u['auth']}' != '1') {
      throw XtreamException('Identifiant ou mot de passe incorrect.');
    }
    final status = '${u['status'] ?? ''}';
    final exp = int.tryParse('${u['exp_date'] ?? ''}');
    final expiresAt = exp == null ? null : DateTime.fromMillisecondsSinceEpoch(exp * 1000);
    if (status.isNotEmpty && status.toLowerCase() != 'active') {
      throw XtreamException('Abonnement inactif ($status). Contactez votre fournisseur.');
    }
    if (expiresAt != null && expiresAt.isBefore(DateTime.now())) {
      throw XtreamException('Abonnement expiré depuis le ${expiresAt.day}/${expiresAt.month}/${expiresAt.year}.');
    }
    return XtreamAccount(
      status: status,
      expiresAt: expiresAt,
      maxConnections: int.tryParse('${u['max_connections'] ?? ''}'),
      formats: [for (final f in (u['allowed_output_formats'] as List? ?? const [])) '$f'],
    );
  }

  /// Chaînes en direct avec leurs catégories.
  Future<List<Channel>> liveChannels({XtreamAccount? account}) async {
    final acc = account ?? await authenticate();
    final cats = await _get(const {'action': 'get_live_categories'});
    final names = <String, String>{
      if (cats is List)
        for (final c in cats.whereType<Map>()) '${c['category_id']}': '${c['category_name'] ?? ''}'.trim(),
    };
    final streams = await _get(const {'action': 'get_live_streams'});
    if (streams is! List) return const [];
    // .ts est le format le plus compatible ; m3u8 si le serveur n'autorise que lui.
    final ext = acc.formats.isEmpty || acc.formats.contains('ts') ? 'ts' : 'm3u8';
    final out = <Channel>[];
    for (final s in streams.whereType<Map>()) {
      final id = '${s['stream_id'] ?? ''}';
      if (id.isEmpty) continue;
      final icon = '${s['stream_icon'] ?? ''}'.trim();
      final epg = '${s['epg_channel_id'] ?? ''}'.trim();
      out.add(Channel(
        name: '${s['name'] ?? 'Chaîne $id'}'.trim(),
        url: streamUrl(id, ext),
        group: names['${s['category_id']}'] ?? '',
        logo: icon.isEmpty || icon == 'null' ? null : icon,
        tvgId: epg.isEmpty || epg == 'null' ? null : epg,
      ));
    }
    return out;
  }

  String streamUrl(String streamId, String ext) => base
      .replace(pathSegments: ['live', username, password, '$streamId.$ext'])
      .toString();

  // ----- Films et séries -----

  static String? _img(dynamic v) {
    final s = '${v ?? ''}'.trim();
    return s.isEmpty || s == 'null' || !s.startsWith('http') ? null : s;
  }

  static double? _rating(dynamic v) {
    final r = double.tryParse('${v ?? ''}');
    return r == null || r <= 0 ? null : r;
  }

  static String? _year(dynamic v) {
    final m = RegExp(r'(19|20)\d{2}').firstMatch('${v ?? ''}');
    return m?.group(0);
  }

  Future<Map<String, String>> _categories(String action) async {
    final cats = await _get({'action': action});
    return {
      if (cats is List)
        for (final c in cats.whereType<Map>()) '${c['category_id']}': '${c['category_name'] ?? ''}'.trim(),
    };
  }

  Future<List<VodItem>> movies(String sourceId) async {
    final names = await _categories('get_vod_categories');
    final list = await _get(const {'action': 'get_vod_streams'});
    if (list is! List) return const [];
    return [
      for (final m in list.whereType<Map>())
        if ('${m['stream_id'] ?? ''}'.isNotEmpty)
          VodItem(
            kind: VodKind.movie,
            id: '${m['stream_id']}',
            name: '${m['name'] ?? ''}'.trim(),
            sourceId: sourceId,
            poster: _img(m['stream_icon']),
            category: names['${m['category_id']}'] ?? '',
            rating: _rating(m['rating']),
            year: _year(m['year'] ?? m['releasedate'] ?? m['name']),
            ext: '${m['container_extension'] ?? 'mp4'}'.trim().isEmpty ? 'mp4' : '${m['container_extension']}'.trim(),
          ),
    ];
  }

  Future<List<VodItem>> series(String sourceId) async {
    final names = await _categories('get_series_categories');
    final list = await _get(const {'action': 'get_series'});
    if (list is! List) return const [];
    return [
      for (final m in list.whereType<Map>())
        if ('${m['series_id'] ?? ''}'.isNotEmpty)
          VodItem(
            kind: VodKind.series,
            id: '${m['series_id']}',
            name: '${m['name'] ?? ''}'.trim(),
            sourceId: sourceId,
            poster: _img(m['cover']),
            category: names['${m['category_id']}'] ?? '',
            rating: _rating(m['rating']),
            year: _year(m['releaseDate'] ?? m['release_date'] ?? m['year']),
            plot: '${m['plot'] ?? ''}'.trim(),
          ),
    ];
  }

  static VodDetails _details(Map? i) {
    if (i == null) return const VodDetails();
    String t(String k) {
      final v = '${i[k] ?? ''}'.trim();
      return v == 'null' ? '' : v;
    }

    final bd = i['backdrop_path'];
    return VodDetails(
      plot: t('plot').isNotEmpty ? t('plot') : t('description'),
      genre: t('genre'),
      cast: t('cast').isNotEmpty ? t('cast') : t('actors'),
      director: t('director'),
      release: t('releasedate').isNotEmpty ? t('releasedate') : t('releaseDate'),
      duration: t('duration'),
      backdrop: _img(bd is List && bd.isNotEmpty ? bd.first : bd),
      rating: _rating(i['rating']),
    );
  }

  Future<VodDetails> movieDetails(String id) async {
    final j = await _get({'action': 'get_vod_info', 'vod_id': id});
    return _details(j is Map && j['info'] is Map ? j['info'] as Map : null);
  }

  Future<SeriesDetails> seriesDetails(String id) async {
    final j = await _get({'action': 'get_series_info', 'series_id': id});
    if (j is! Map) return const SeriesDetails(VodDetails(), {});
    final seasons = <int, List<Episode>>{};
    final eps = j['episodes'];
    final entries = eps is Map ? eps.values : (eps is List ? eps : const []);
    for (final group in entries) {
      if (group is! List) continue;
      for (final e in group.whereType<Map>()) {
        final info = e['info'] is Map ? e['info'] as Map : const {};
        final season = int.tryParse('${e['season'] ?? ''}') ?? 1;
        final ep = Episode(
          id: '${e['id']}',
          season: season,
          number: int.tryParse('${e['episode_num'] ?? ''}') ?? 0,
          title: '${e['title'] ?? ''}'.trim(),
          ext: '${e['container_extension'] ?? 'mp4'}',
          plot: '${info['plot'] ?? ''}'.trim(),
          image: _img(info['movie_image']),
          duration: '${info['duration'] ?? ''}'.trim(),
        );
        seasons.putIfAbsent(season, () => []).add(ep);
      }
    }
    for (final l in seasons.values) {
      l.sort((a, b) => a.number.compareTo(b.number));
    }
    return SeriesDetails(_details(j['info'] is Map ? j['info'] as Map : null), Map.fromEntries(seasons.entries.toList()..sort((a, b) => a.key.compareTo(b.key))));
  }

  String movieUrl(String id, String ext) =>
      base.replace(pathSegments: ['movie', username, password, '$id.$ext']).toString();

  String episodeUrl(String id, String ext) =>
      base.replace(pathSegments: ['series', username, password, '$id.$ext']).toString();
}
