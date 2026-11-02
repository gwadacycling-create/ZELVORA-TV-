/// Films et séries (vidéo à la demande).
enum VodKind { movie, series }

class VodItem {
  const VodItem({
    required this.kind,
    required this.id,
    required this.name,
    required this.sourceId,
    this.poster,
    this.category = '',
    this.rating,
    this.year,
    this.ext = 'mp4',
    this.url,
    this.plot,
  });

  final VodKind kind;
  final String id;
  final String name;
  final String sourceId;
  final String? poster;
  final String category;
  final double? rating;
  final String? year;
  final String ext;

  /// Lien direct (films venant d'une playlist M3U).
  final String? url;
  final String? plot;

  String get key => '$sourceId|${kind.name}|$id';

  Map<String, dynamic> toJson() => {
        'k': kind.name,
        'id': id,
        'n': name,
        's': sourceId,
        if (poster != null) 'p': poster,
        'c': category,
        'e': ext,
        if (url != null) 'u': url,
      };

  static VodItem fromJson(Map<String, dynamic> j) => VodItem(
        kind: j['k'] == 'series' ? VodKind.series : VodKind.movie,
        id: '${j['id']}',
        name: '${j['n'] ?? ''}',
        sourceId: '${j['s'] ?? ''}',
        poster: j['p'] as String?,
        category: '${j['c'] ?? ''}',
        ext: '${j['e'] ?? 'mp4'}',
        url: j['u'] as String?,
      );
}

/// Fiche détaillée d'un film ou d'une série.
class VodDetails {
  const VodDetails({
    this.plot = '',
    this.genre = '',
    this.cast = '',
    this.director = '',
    this.release = '',
    this.duration = '',
    this.backdrop,
    this.rating,
  });
  final String plot;
  final String genre;
  final String cast;
  final String director;
  final String release;
  final String duration;
  final String? backdrop;
  final double? rating;
}

class Episode {
  const Episode({
    required this.id,
    required this.season,
    required this.number,
    required this.title,
    this.ext = 'mp4',
    this.plot = '',
    this.image,
    this.duration = '',
  });
  final String id;
  final int season;
  final int number;
  final String title;
  final String ext;
  final String plot;
  final String? image;
  final String duration;
}

class SeriesDetails {
  const SeriesDetails(this.info, this.seasons);
  final VodDetails info;

  /// Numéro de saison → épisodes triés.
  final Map<int, List<Episode>> seasons;
}
