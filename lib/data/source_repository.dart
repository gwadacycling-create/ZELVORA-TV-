import 'dart:convert';
import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import '../domain/channel.dart';
import '../domain/iptv_source.dart';
import 'm3u_parser.dart';

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
class SourceRepository {
  SourceRepository({SecureStore? store, http.Client? client, Future<String> Function(String path)? readFile})
      : _store = store ?? const SystemSecureStore(),
        _client = client ?? http.Client(),
        _readFile = readFile ?? ((p) => File(p).readAsBytes().then(_decode));

  static const _key = 'zelvora.sources.v1';
  final SecureStore _store;
  final http.Client _client;
  final Future<String> Function(String path) _readFile;

  Future<List<IptvSource>> loadSources() async => IptvSource.decodeList(await _store.read(_key));

  Future<void> saveSources(List<IptvSource> sources) => _store.write(_key, IptvSource.encodeList(sources));

  Future<List<Channel>> fetchChannels(IptvSource source) async {
    final String content;
    switch (source.kind) {
      case SourceKind.m3uUrl:
        final uri = Uri.tryParse(source.location);
        if (uri == null || !(uri.isScheme('http') || uri.isScheme('https'))) {
          throw SourceException('Le lien doit commencer par http:// ou https://');
        }
        final http.Response res;
        try {
          res = await _client.get(uri).timeout(const Duration(seconds: 45));
        } catch (_) {
          throw SourceException('Impossible de joindre le serveur de la playlist.');
        }
        if (res.statusCode != 200) {
          throw SourceException('Le serveur a répondu avec une erreur (${res.statusCode}).');
        }
        content = _decode(res.bodyBytes);
      case SourceKind.m3uFile:
        try {
          content = await _readFile(source.location);
        } catch (_) {
          throw SourceException('Fichier introuvable ou illisible.');
        }
    }
    final channels = M3uParser.parse(content);
    if (channels.isEmpty) {
      throw SourceException('Aucune chaîne trouvée : ce n’est pas une playlist M3U valide.');
    }
    return [for (final c in channels) c.withSource(source.id)];
  }

  static String _decode(List<int> bytes) {
    try {
      return utf8.decode(bytes);
    } on FormatException {
      return latin1.decode(bytes);
    }
  }
}
