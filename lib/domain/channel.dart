import 'programme.dart';

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
    this.archiveDays = 0,
    this.catchup,
    this.catchupOffsetMin,
  });

  /// Replay : nombre de jours d'émissions passées que le serveur garde (0 = aucun).
  final int archiveDays;

  /// Modèle du lien de replay, avec [kCatchupStart] et [kCatchupDuration] à remplacer.
  final String? catchup;

  /// Décalage horaire du serveur par rapport à UTC, en minutes (null = heure de l'appareil).
  final int? catchupOffsetMin;

  /// L'émission peut-elle être revue (déjà commencée et encore gardée par le serveur) ?
  bool canReplay(Programme p, [DateTime? now]) {
    if (catchup == null || archiveDays <= 0) return false;
    final t = now ?? DateTime.now();
    return !p.start.isAfter(t) && p.start.isAfter(t.subtract(Duration(days: archiveDays)));
  }

  /// Flux de replay de l'émission, lu comme une vidéo (avec barre de progression).
  Channel replay(Programme p) {
    final s = catchupOffsetMin == null ? p.start.toLocal() : p.start.toUtc().add(Duration(minutes: catchupOffsetMin!));
    String two(int v) => v.toString().padLeft(2, '0');
    final start = '${s.year}-${two(s.month)}-${two(s.day)}:${two(s.hour)}-${two(s.minute)}';
    final minutes = p.stop.difference(p.start).inMinutes.clamp(1, 24 * 60);
    return Channel(
      name: p.title.isEmpty ? name : '${p.title} · $name',
      url: catchup!.replaceAll(kCatchupStart, start).replaceAll(kCatchupDuration, '$minutes'),
      group: group,
      logo: logo,
      tvgId: tvgId,
      headers: headers,
      sourceId: sourceId,
      vod: true,
    );
  }

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
        archiveDays: archiveDays,
        catchup: catchup,
        catchupOffsetMin: catchupOffsetMin,
      );
}

const kCatchupStart = '__ZSTART__';
const kCatchupDuration = '__ZDUR__';
