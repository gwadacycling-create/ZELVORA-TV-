import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'sources_state.dart';

const kParentalKey = 'zelvora.parental.v1';

final _adultRe = RegExp(r'(adult|adulte|xxx|porn|\+ ?18|18 ?\+|érotique|erotic|hot ?club|playboy|brazzers|hustler)', caseSensitive: false);

/// Catégorie ou titre réservé aux adultes.
bool isAdultContent(String category, [String name = '']) => _adultRe.hasMatch(category) || _adultRe.hasMatch(name);

class ParentalSettings {
  const ParentalSettings({this.enabled = false, this.pin});
  final bool enabled;
  final String? pin;

  String encode() => jsonEncode({'e': enabled, if (pin != null) 'p': pin});
  static ParentalSettings decode(String? raw) {
    if (raw == null) return const ParentalSettings();
    try {
      final j = jsonDecode(raw) as Map;
      return ParentalSettings(enabled: j['e'] == true, pin: j['p'] as String?);
    } catch (_) {
      return const ParentalSettings();
    }
  }
}

/// Réglage lu au démarrage (avant l'affichage, pour ne rien laisser apparaître).
final initialParentalProvider = Provider<ParentalSettings>((ref) => const ParentalSettings());

/// Contrôle parental : masque les contenus adultes, code PIN pour le désactiver.
final parentalProvider = NotifierProvider<ParentalNotifier, ParentalSettings>(ParentalNotifier.new);

class ParentalNotifier extends Notifier<ParentalSettings> {
  @override
  ParentalSettings build() => ref.read(initialParentalProvider);

  Future<void> enable(String pin) => _set(ParentalSettings(enabled: true, pin: pin));

  /// Renvoie false si le code est faux.
  Future<bool> disable(String pin) async {
    if (state.pin != null && pin != state.pin) return false;
    await _set(ParentalSettings(enabled: false, pin: state.pin));
    return true;
  }

  Future<void> _set(ParentalSettings s) async {
    state = s;
    await ref.read(secureStoreProvider).write(kParentalKey, s.encode());
  }
}
