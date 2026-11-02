/// Une chaîne (ou un flux) issue d'une source IPTV.
class Channel {
  const Channel({
    required this.name,
    required this.url,
    this.group = '',
    this.logo,
    this.tvgId,
    this.headers = const {},
    this.sourceId = '',
    this.vod = false,
  });

  /// Film ou épisode (lecture à la demande, avec barre de progression).
  final bool vod;

  final String name;
  final String url;
  final String group;
  final String? logo;
  final String? tvgId;

  /// En-têtes HTTP demandés par la playlist (User-Agent, Referer...).
  final Map<String, String> headers;
  final String sourceId;

  /// Identifiant stable, utilisé plus tard pour les favoris et l'historique.
  String get key => '$sourceId|$url';

  Channel withSource(String id) => Channel(
        name: name,
        url: url,
        group: group,
        logo: logo,
        tvgId: tvgId,
        headers: headers,
        sourceId: id,
        vod: vod,
      );
}
