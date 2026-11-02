import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zelvora_tv/data/source_repository.dart';
import 'package:zelvora_tv/features/player/player_page.dart';

import 'helpers.dart';

Future<void> addPlaylist(WidgetTester tester, String url) async {
  await tester.tap(find.text('Réglages').first);
  await tester.pumpAndSettle();
  await tester.tap(find.text('Playlist M3U / M3U8'));
  await tester.pumpAndSettle();
  await tester.enterText(find.widgetWithText(TextField, 'Nom (ex. : Ma box TV)'), 'Ma playlist test');
  await tester.enterText(find.byKey(const Key('m3u-url')), url);
  await tester.tap(find.byType(Checkbox));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Ajouter'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Ajout d’une playlist par lien, puis TV en direct et lecteur', (tester) async {
    final store = MemorySecureStore();
    final playback = await pumpApp(tester, store: store);

    await addPlaylist(tester, 'https://example.com/playlist.m3u');
    expect(find.text('Playlist ajoutée : 3 chaînes.'), findsOneWidget);
    expect(find.text('Ma playlist test'), findsOneWidget);
    expect(find.textContaining('example.com · 3 chaînes'), findsOneWidget);
    // Le lien est stocké uniquement dans le coffre-fort.
    expect(store.data.values.single, contains('https://example.com/playlist.m3u'));

    await tester.tap(find.text('TV en direct').first);
    await tester.pumpAndSettle();
    expect(find.text('Chaîne Démo 1'), findsOneWidget);
    expect(find.text('Info Test'), findsOneWidget);

    // Filtre par catégorie.
    await tester.tap(find.widgetWithText(ListTile, 'Info').first);
    await tester.pumpAndSettle();
    expect(find.text('Chaîne Démo 1'), findsNothing);
    expect(find.text('Info Test'), findsOneWidget);
    await tester.tap(find.text('Toutes les chaînes'));
    await tester.pumpAndSettle();

    // Recherche.
    await tester.enterText(find.widgetWithText(TextField, 'Rechercher une chaîne'), 'démo 2');
    await tester.pumpAndSettle();
    expect(find.text('Chaîne Démo 1'), findsNothing);
    expect(find.text('Chaîne Démo 2'), findsOneWidget);
    await tester.enterText(find.widgetWithText(TextField, 'Rechercher une chaîne'), '');
    await tester.pumpAndSettle();

    // 1er clic : aperçu.
    await tester.tap(find.text('Chaîne Démo 1'));
    await tester.pumpAndSettle();
    expect(playback.played.single.name, 'Chaîne Démo 1');
    expect(find.text('Plein écran'), findsOneWidget);

    // 2e clic : plein écran.
    await tester.tap(find.text('Chaîne Démo 1').first);
    await tester.pumpAndSettle();
    expect(find.byType(PlayerPage), findsOneWidget);
    expect(find.text('EN DIRECT'), findsOneWidget);

    // Zapping au clavier / télécommande.
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    expect(playback.played.last.name, 'Chaîne Démo 2');
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pumpAndSettle();
    expect(playback.played.last.name, 'Info Test', reason: 'boucle sur la liste');
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    expect(playback.pauses, 1);

    // Volume : touches, muet, mémorisation.
    await tester.sendKeyEvent(LogicalKeyboardKey.minus);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pump();
    expect(playback.volume, 90);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyM);
    await tester.pump();
    expect(playback.volume, 0);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyM);
    await tester.pump();
    expect(playback.volume, 90);
    await tester.tap(find.byKey(const Key('volume-mute')));
    await tester.pump();
    expect(playback.volume, 0);
    await tester.tap(find.byKey(const Key('volume-mute')));
    await tester.pump(const Duration(seconds: 1));
    expect(store.data['zelvora.volume'], '90');

    // Infos techniques (touche I).
    await tester.sendKeyEvent(LogicalKeyboardKey.keyI);
    await tester.pump();
    await tester.pump();
    expect(find.text('Infos techniques'), findsOneWidget);
    expect(find.text('h264'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyI);
    await tester.pump();

    // Échap : retour à la liste.
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.byType(PlayerPage), findsNothing);
    expect(find.text('TV en direct'), findsWidgets);
    await tester.pump(const Duration(seconds: 5)); // minuteur de l'affichage
  });

  testWidgets('Les sources sont rechargées au démarrage suivant', (tester) async {
    final store = MemorySecureStore();
    await pumpApp(tester, store: store);
    await addPlaylist(tester, 'https://example.com/playlist.m3u');

    await pumpApp(tester, store: store); // nouvelle ouverture de l'application
    await tester.tap(find.text('TV en direct').first);
    await tester.pumpAndSettle();
    expect(find.text('Chaîne Démo 2'), findsOneWidget);
  });

  testWidgets('Lien invalide : message d’erreur et rien n’est enregistré', (tester) async {
    final store = MemorySecureStore();
    await pumpApp(tester, store: store);
    await addPlaylist(tester, 'https://example.com/inconnue.m3u');
    expect(find.textContaining('introuvable sur le serveur (404)'), findsOneWidget);
    expect(store.data, isEmpty);
  });

  testWidgets('Mode compatibilité vidéo enregistré', (tester) async {
    final store = MemorySecureStore();
    await pumpApp(tester, store: store);
    await tester.tap(find.text('Réglages').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mode compatibilité vidéo'));
    await tester.pumpAndSettle();
    expect(store.data['zelvora.video.compat'], '1');
    expect(find.textContaining('Redémarrez'), findsOneWidget);
  });

  testWidgets('Le bouton Ajouter exige la case de certification', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.text('Réglages').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Playlist M3U / M3U8'));
    await tester.pumpAndSettle();
    final btn = tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Ajouter'));
    expect(btn.onPressed, isNull);
  });
}
