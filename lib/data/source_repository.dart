import 'dart:convert';
import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import '../domain/channel.dart';
import '../domain/iptv_source.dart';
import 'm3u_parser.dart';
import 'xtream_client.dart';

/// Coffre-fort clé/valeur (chiffré par le système en production).
abstract class SecureStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
}

class SystemSecureStore implements SecureStore {
  const SystemSecureStore();
  static const _storage = FlutterSecureStorage();
  @override
  Future<String?> read(String key) => _storage.read(key: key);
  @override
  Future<void> write(String key, String value) => _storage.write(key: key, value: value);
}

class MemorySecureStore implements SecureStore {
  final Map<String, String> data = {};
  @override
  Future<String?> read(String key) async => data[key];
  @override
  Future<void> write(String key, String value) async => data[key] = value;
}

class SourceException implements Exception {
  SourceException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Gère la liste des sources et le chargement de leurs chaînes.
///
/// Les sources (liens pouvant contenir identifiants et mots de passe) sont
/// stockées uniquement dans le coffre-fort du système. Les chaînes ne sont pas
/// écrites sur le disque : elles sont rechargées depuis la source au démarrage.
/// Identifiant envoyé aux serveurs : beaucoup de fournisseurs IPTV refusent
/// les clients inconnus et n'acceptent que les lecteurs courants.
const kIptvUserAgent = 'VLC/3.0.21 LibVLC/3.0.21';

class SourceRepository {
  SourceRepository({SecureStore? store, http.Client? client, Future<String> Function(String path)? readFile})
      : _store = store ?? const SystemSecureStore(),
        _client = client ?? http.Client(),
        _readFile = readFile ?? ((p) => File(p).readAsBytes().then(_decode));

  static const _key = 'zelvora.sources.v1';
  final SecureStore _store;
  final http.Client _client;
  http.Client get httpClient => _client;
  final Future<String> Function(String path) _readFile;

  final _epgUrls = <String, String>{};

  /// Adresse du guide TV (XMLTV) de la source, si elle en propose un.
  String? epgUrlFor(IptvSource source) {
    if (source.kind == SourceKind.xtream) {
      try {
        final base = XtreamClient.normalizeServer(source.location);
        return base.replace(
          path: '/xmltv.php',
          queryParameters: {'username': source.username ?? '', 'password': source.password ?? ''},
        ).toString();
      } catch (_) {
        return null;
      }
    }
    return _epgUrls[source.id];
  }

  Future<List<IptvSource>> loadSources() async => IptvSource.decodeList(await _store.read(_key));

  Future<void> saveSources(List<IptvSource> sources) => _store.write(_key, IptvSource.encodeList(sources));

  Future<List<Channel>> fetchChannels(IptvSource source) async {
    final String content;
    switch (source.kind) {
      case SourceKind.xtream:
        final client = XtreamClient(
          server: source.location,
          username: source.username ?? '',
          password: source.password ?? '',
          httpClient: _client,
          userAgent: kIptvUserAgent,
        );
        try {
          final list = await client.liveChannels();
          if (list.isEmpty) throw SourceException('Ce compte ne contient aucune chaîne en direct.');
          return [for (final c in list) c.withSource(source.id)];
        } on XtreamException catch (e) {
          throw SourceException(e.message);
        }
      case SourceKind.m3uUrl:
        final uri = Uri.tryParse(source.location);
        if (uri == null || !(uri.isScheme('http') || uri.isScheme('https'))) {
          throw SourceException('Le lien doit commencer par http:// ou https://');
        }
        final http.Response res;
        try {
          res = await _client.get(uri, headers: const {'User-Agent': kIptvUserAgent}).timeout(const Duration(seconds: 45));
        } catch (_) {
          throw SourceException('Impossible de joindre le serveur de la playlist.');
        }
        if (res.statusCode < 200 || res.statusCode >= 300) {
          throw SourceException(_httpError(res.statusCode));
        }
        final type = res.headers['content-type'] ?? '';
        if (type.startsWith('video/') || type.contains('mpegurl') && _isHlsStream(res.bodyBytes)) {
          return [_singleStream(source)];
        }
        content = _decode(res.bodyBytes);
        if (_isHlsStream(res.bodyBytes)) return [_singleStream(source)];
      case SourceKind.m3uFile:
        try {
          content = await _readFile(source.location);
        } catch (_) {
          throw SourceException('Fichier introuvable ou illisible.');
        }
    }
    final epg = M3uParser.epgUrl(content);
    if (epg != null) _epgUrls[source.id] = epg;
    final channels = M3uParser.parse(content);
    if (channels.isEmpty) {
      throw SourceException('Aucune chaîne trouvée : ce n’est pas une playlist M3U valide.');
    }
    return [for (final c in channels) c.withSource(source.id)];
  }

  /// Lien direct vers un flux HLS (et non une liste de chaînes).
  static bool _isHlsStream(List<int> bytes) {
    final head = String.fromCharCodes(bytes.take(4096));
    return head.contains('#EXT-X-') && !head.contains('#EXTINF:-1') && !head.contains('tvg-');
  }

  static Channel _singleStream(IptvSource s) {
    final uri = Uri.parse(s.location);
    return Channel(name: s.name, url: s.location, group: uri.host, sourceId: s.id);
  }

  static String _httpError(int code) => switch (code) {
        401 || 403 => 'Accès refusé par le serveur ($code) : vérifiez le lien, l’identifiant et le mot de passe, '
            'ou que votre abonnement est actif.',
        404 || 410 => 'Playlist introuvable sur le serveur ($code) : le lien est peut-être incorrect ou expiré.',
        429 => 'Le serveur reçoit trop de demandes ($code). Réessayez dans quelques minutes.',
        >= 500 => 'Le serveur de la playlist rencontre un problème ($code). Réessayez plus tard.',
        _ => 'Le serveur a répondu avec une erreur ($code).',
      };

  static String _decode(List<int> bytes) {
    try {
      return utf8.decode(bytes);
    } on FormatException {
      return latin1.decode(bytes);
    }
  }
}
