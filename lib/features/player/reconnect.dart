/// Outils de stabilité du lecteur (sans dépendance au moteur vidéo).
library;

/// Reconnexions limitées avec attente progressive (1, 2, 4, 8, 16 s).
/// Après [stableAfter] de lecture correcte, le compteur repart à zéro :
/// une coupure ponctuelle est réparée, une panne durable n'est pas masquée.
class ReconnectPolicy {
  ReconnectPolicy({this.maxAttempts = 5, this.maxAttemptsBeforeStart = 2, this.stableAfter = const Duration(seconds: 60)});
  final int maxAttempts;
  final int maxAttemptsBeforeStart;
  final Duration stableAfter;

  int attempts = 0;
  int total = 0;
  bool started = false;
  DateTime? _healthySince;

  /// Délai avant le prochain essai, ou null s'il faut abandonner.
  Duration? nextDelay() {
    final limit = started ? maxAttempts : maxAttemptsBeforeStart;
    if (attempts >= limit) return null;
    final d = Duration(seconds: 1 << attempts);
    attempts++;
    total++;
    _healthySince = null;
    return d;
  }

  /// À appeler quand l'image avance normalement.
  void onProgress(DateTime now) {
    started = true;
    _healthySince ??= now;
    if (attempts > 0 && now.difference(_healthySince!) >= stableAfter) attempts = 0;
  }

  /// Nouvelle chaîne : on repart de zéro.
  void reset() {
    attempts = 0;
    total = 0;
    started = false;
    _healthySince = null;
  }
}

final _urlRe = RegExp(r'''([a-zA-Z][a-zA-Z0-9+.-]*)://([^/\s'"?#@]*@)?([^/\s'"?#:]+)(:\d+)?[^\s'"]*''');

/// Masque les URL dans un texte : ne garde que l'hôte, jamais les
/// identifiants, chemins Xtream ou jetons.
String maskUrls(String text) => text.replaceAllMapped(_urlRe, (m) => '${m[1]}://${m[3]}/…');

/// Flux HLS (playlist .m3u8) ou flux continu (MPEG-TS…) ?
bool isHls(String url) => Uri.tryParse(url)?.path.toLowerCase().endsWith('.m3u8') ?? false;
