import 'dart:convert';

enum SourceKind { m3uUrl, m3uFile, xtream }

/// Une source ajoutée par l'utilisateur. Stockée chiffrée (voir SourceRepository).
class IptvSource {
  const IptvSource({
    required this.id,
    required this.name,
    required this.kind,
    required this.location,
    required this.addedAt,
    this.username,
    this.password,
  });

  final String id;
  final String name;
  final SourceKind kind;

  /// Lien de la playlist ou chemin du fichier. Peut contenir des identifiants :
  /// ne jamais l'afficher en clair ni l'écrire dans les journaux.
  final String location;
  final DateTime addedAt;

  /// Compte Xtream Codes (null pour les playlists M3U).
  final String? username;
  final String? password;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'kind': kind.name,
        'location': location,
        'addedAt': addedAt.toIso8601String(),
        if (username != null) 'username': username,
        if (password != null) 'password': password,
      };

  factory IptvSource.fromJson(Map<String, dynamic> j) => IptvSource(
        id: j['id'] as String,
        name: j['name'] as String,
        kind: SourceKind.values.byName(j['kind'] as String),
        location: j['location'] as String,
        addedAt: DateTime.parse(j['addedAt'] as String),
        username: j['username'] as String?,
        password: j['password'] as String?,
      );

  static String encodeList(List<IptvSource> list) => jsonEncode([for (final s in list) s.toJson()]);

  static List<IptvSource> decodeList(String? raw) {
    if (raw == null || raw.isEmpty) return [];
    return [for (final e in jsonDecode(raw) as List) IptvSource.fromJson(e as Map<String, dynamic>)];
  }

  /// Version masquée pour l'affichage : domaine seulement, sans identifiants.
  String get displayLocation {
    if (kind == SourceKind.m3uFile) {
      final parts = location.split(RegExp(r'[\\/]'));
      return parts.isEmpty ? location : parts.last;
    }
    final uri = Uri.tryParse(location.contains('://') ? location : 'http://$location');
    return uri == null || uri.host.isEmpty ? 'Lien' : uri.host;
  }
}
