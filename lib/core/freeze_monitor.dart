import 'dart:async';

/// Détecte les moments où l'écran ne répond plus (fil principal bloqué),
/// pour les afficher dans le panneau de diagnostic du lecteur (touche I).
class FreezeMonitor {
  FreezeMonitor._();
  static final instance = FreezeMonitor._();

  static const _tick = Duration(milliseconds: 100);
  static const threshold = Duration(milliseconds: 700);

  final _events = <String>[];
  Timer? _timer;
  DateTime _last = DateTime.now();

  /// Ce que l'application faisait (page, ouverture d'une chaîne...).
  String context = '';

  List<String> get events => List.unmodifiable(_events);

  void start() {
    _timer ??= Timer.periodic(_tick, (_) {
      final now = DateTime.now();
      final gap = now.difference(_last) - _tick;
      _last = now;
      if (gap >= threshold) {
        String two(int v) => v.toString().padLeft(2, '0');
        _events.add('${two(now.hour)}:${two(now.minute)}:${two(now.second)} bloqué ${(gap.inMilliseconds / 1000).toStringAsFixed(1)} s'
            '${context.isEmpty ? '' : ' ($context)'}');
        if (_events.length > 10) _events.removeAt(0);
      }
    });
  }
}
