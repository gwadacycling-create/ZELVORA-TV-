import 'dart:convert';

import 'package:http/http.dart' as http;

import '../domain/channel.dart';

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
}
