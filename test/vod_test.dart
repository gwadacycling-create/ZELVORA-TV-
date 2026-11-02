import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zelvora_tv/data/source_repository.dart';
import 'package:zelvora_tv/features/player/player_page.dart';
import 'package:zelvora_tv/state/vod_state.dart';

import 'helpers.dart';
import 'xtream_test.dart' show fakeXtream;

Future<void> addXtream(WidgetTester tester) async {
  await tester.tap(find.text('Réglages').first);
  await tester.pumpAndSettle();
  await tester.tap(find.text('Compte Xtream Codes'));
  await tester.pumpAndSettle();
  await tester.enterText(find.byKey(const Key('xt-server')), 'http://tv.test:8080');
  await tester.enterText(find.byKey(const Key('xt-user')), 'demo');
  await tester.enterText(find.byKey(const Key('xt-pass')), 'secret');
  await tester.tap(find.byType(Checkbox));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Se connecter'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Films : catalogue, fiche, lecture et reprise', (tester) async {
    final store = MemorySecureStore();
    final playback = await pumpApp(tester, store: store, client: fakeXtream());
    await addXtream(tester);

    await tester.tap(find.text('Films').first);
    await tester.pumpAndSettle();
    expect(find.text('Film Démo (2024)'), findsWidgets);
    expect(find.text('Comédie Test'), findsWidgets);
    expect(find.text('7.4'), findsOneWidget);

    // Filtre par catégorie, puis recherche.
    await tester.tap(find.text('Comédie'));
    await tester.pumpAndSettle();
    expect(find.text('Film Démo (2024)'), findsNothing);
    await tester.tap(find.text('Tout'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('vod-search-movie')), 'démo');
    await tester.pumpAndSettle();
    expect(find.text('Comédie Test'), findsNothing);

    await tester.tap(find.text('Film Démo (2024)').last);
    await tester.pumpAndSettle();
    expect(find.text('Un film de démonstration.'), findsOneWidget);
    await tester.tap(find.byKey(const Key('vod-play')));
    await tester.pumpAndSettle();
    expect(find.byType(PlayerPage), findsOneWidget);
    expect(playback.played.last.url, 'http://tv.test:8080/movie/demo/secret/501.mkv');
    expect(playback.played.last.vod, isTrue);
    expect(find.byKey(const Key('vod-seek')), findsOneWidget);
    expect(find.text('EN DIRECT'), findsNothing);

    // Avance rapide au clavier puis sortie : la position est mémorisée.
    playback.dur = const Duration(minutes: 100);
    playback.pos = const Duration(minutes: 20);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    expect(playback.pos, const Duration(minutes: 20, seconds: 10));
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(store.data[kProgressKey], contains('"p":1210'));
    await tester.enterText(find.byKey(const Key('vod-search-movie')), '');
    await tester.pumpAndSettle();
    expect(find.text('Continuer à regarder'), findsOneWidget);

    // Reprise depuis la fiche.
    await tester.tap(find.text('Film Démo (2024)').last);
    await tester.pumpAndSettle();
    expect(find.text('Reprendre à 20:10'), findsOneWidget);
    await tester.tap(find.byKey(const Key('vod-play')));
    await tester.pumpAndSettle();
    expect(playback.lastStart, const Duration(minutes: 20, seconds: 10));
  });

  testWidgets('Séries : saisons et épisodes', (tester) async {
    final playback = await pumpApp(tester, client: fakeXtream());
    await addXtream(tester);
    await tester.tap(find.text('Séries').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Série Démo').last);
    await tester.pumpAndSettle();
    expect(find.text('Une série de démonstration.'), findsOneWidget);
    expect(find.text('Saison 1'), findsOneWidget);
    expect(find.text('Le début'), findsOneWidget);
    await tester.tap(find.text('Saison 2'));
    await tester.pumpAndSettle();
    expect(find.text('Retour'), findsOneWidget);
    await tester.tap(find.text('Retour'));
    await tester.pumpAndSettle();
    expect(playback.played.last.url, 'http://tv.test:8080/series/demo/secret/911.mkv');
    expect(playback.played.last.name, contains('S02E01'));
  });
}
