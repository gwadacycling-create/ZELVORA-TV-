import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zelvora_tv/data/source_repository.dart';
import 'package:zelvora_tv/features/search/search_page.dart';
import 'package:zelvora_tv/state/parental_state.dart';

import 'helpers.dart';
import 'live_tv_test.dart' show addPlaylist;
import 'vod_test.dart' show addXtream;
import 'xtream_test.dart' show fakeXtream;

const adultPlaylist = '''#EXTM3U
#EXTINF:-1 group-title="Famille",Dessins animés
https://example.com/live/1.ts
#EXTINF:-1 group-title="XXX Adultes",Chaîne privée
https://example.com/live/2.ts
''';

void main() {
  test('recherche sans accents ni majuscules', () {
    expect(fold('Été À LA Plage'), 'ete a la plage');
  });

  test('détection des contenus adultes', () {
    expect(isAdultContent('XXX Adultes'), isTrue);
    expect(isAdultContent('FR | ADULT +18'), isTrue);
    expect(isAdultContent('Sport', 'beIN Sports 1'), isFalse);
    expect(isAdultContent('Infos', 'France 24'), isFalse);
  });

  testWidgets('Recherche globale : chaînes, films et séries', (tester) async {
    await pumpApp(tester, client: fakeXtream());
    await addXtream(tester);
    await tester.tap(find.text('Accueil').first);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Rechercher').first);
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('global-search')), 'demo');
    await tester.pumpAndSettle();
    expect(find.text('Films (1)'), findsOneWidget);
    expect(find.text('Séries (1)'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('global-search')), 'sport');
    await tester.pumpAndSettle();
    expect(find.text('Chaînes (1)'), findsOneWidget);
    expect(find.text('Sport Deux'), findsOneWidget);
  });

  testWidgets('Contrôle parental avec code PIN', (tester) async {
    final store = MemorySecureStore();
    await pumpApp(tester, store: store, client: fakeHttp(adultPlaylist));
    await addPlaylist(tester, 'https://example.com/playlist.m3u');
    await tester.tap(find.text('TV en direct').first);
    await tester.pumpAndSettle();
    expect(find.text('Chaîne privée'), findsOneWidget);

    await tester.tap(find.text('Réglages').first);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.byKey(const Key('parental-switch')), 200, scrollable: find.byType(Scrollable).first);
    await tester.ensureVisible(find.byKey(const Key('parental-switch')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('parental-switch')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('parental-pin')), '1234');
    await tester.tap(find.text('Valider'));
    await tester.pumpAndSettle();
    expect(store.data[kParentalKey], contains('"e":true'));

    await tester.tap(find.text('TV en direct').first);
    await tester.pumpAndSettle();
    expect(find.text('Chaîne privée'), findsNothing);
    expect(find.text('Dessins animés'), findsOneWidget);

    // Mauvais code : reste activé.
    await tester.tap(find.text('Réglages').first);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.byKey(const Key('parental-switch')), 200, scrollable: find.byType(Scrollable).first);
    await tester.ensureVisible(find.byKey(const Key('parental-switch')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('parental-switch')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('parental-pin')), '0000');
    await tester.tap(find.text('Valider'));
    await tester.pumpAndSettle();
    expect(find.text('Code incorrect.'), findsOneWidget);
    expect(store.data[kParentalKey], contains('"e":true'));
  });

  testWidgets('Choix de la langue audio et des sous-titres', (tester) async {
    final playback = await pumpApp(tester);
    await addPlaylist(tester, 'https://example.com/playlist.m3u');
    await tester.tap(find.text('TV en direct').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Chaîne Démo 1'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Chaîne Démo 1').first);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('tracks-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Anglais'));
    await tester.pumpAndSettle();
    expect(playback.selAudio, '2');
    await tester.tap(find.text('Français').last);
    await tester.pumpAndSettle();
    expect(playback.selSub, '3');
  });
}
