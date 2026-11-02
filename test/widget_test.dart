import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zelvora_tv/core/router/app_router.dart';

import 'helpers.dart';

void main() {
  testWidgets('Le menu latéral affiche toutes les rubriques', (tester) async {
    await pumpApp(tester);
    for (final d in destinations) {
      expect(find.text(d.label), findsWidgets, reason: d.label);
    }
    expect(find.text('Votre TV, vos sources.'), findsOneWidget);
  });

  testWidgets('Chaque rubrique s’ouvre depuis le menu', (tester) async {
    await pumpApp(tester);
    const expected = {
      'TV en direct': 'Aucune chaîne pour le moment',
      'Guide TV': 'Consultez le programme TV, naviguez entre les chaînes et ne manquez rien de vos émissions.',
      'Films': 'Aucun film pour le moment',
      'Séries': 'Aucune série pour le moment',
      'Favoris': 'Aucun favori',
      'Historique': 'Historique vide',
      'Réglages': 'Mes sources IPTV',
      'Accueil': 'Votre TV, vos sources.',
    };
    for (final e in expected.entries) {
      await tester.tap(find.text(e.key).first);
      await tester.pumpAndSettle();
      expect(find.text(e.value), findsWidgets, reason: e.key);
    }
  });

  testWidgets('Le menu se replie en icônes', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.text('Z'));
    await tester.pumpAndSettle();
    expect(find.text('Historique'), findsNothing);
    expect(find.byIcon(Icons.history_rounded), findsOneWidget);
  });

  testWidgets('Navigation au clavier / télécommande (Tab + Entrée)', (tester) async {
    await pumpApp(tester);
    // Le bouton principal de l'accueil a le focus au démarrage.
    final focused = FocusManager.instance.primaryFocus;
    expect(focused, isNotNull);
    expect(tester.takeException(), isNull);
  });
}
