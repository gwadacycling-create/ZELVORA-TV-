import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zelvora_tv/data/source_repository.dart';
import 'package:zelvora_tv/features/history/history_page.dart';
import 'package:zelvora_tv/state/library_state.dart';

import 'helpers.dart';
import 'live_tv_test.dart' show addPlaylist;

void main() {
  testWidgets('Favoris et historique des chaînes', (tester) async {
    final store = MemorySecureStore();
    final playback = await pumpApp(tester, store: store);
    await addPlaylist(tester, 'https://example.com/playlist.m3u');

    // Cœur sur une chaîne de la TV en direct.
    await tester.tap(find.text('TV en direct').first);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('favorite-toggle')).first);
    await tester.pumpAndSettle();
    expect(store.data[kFavoritesKey], contains('example.com/live/1.m3u8'));

    await tester.tap(find.text('Favoris').first);
    await tester.pumpAndSettle();
    expect(find.text('Aucun favori'), findsNothing);
    expect(find.text('Chaîne Démo 1'), findsOneWidget);
    expect(find.text('Chaîne Démo 2'), findsNothing);

    // Lecture depuis les favoris → historique.
    await tester.tap(find.text('Chaîne Démo 1'));
    await tester.pumpAndSettle();
    expect(playback.played.last.name, 'Chaîne Démo 1');
    // Touche F pendant la lecture : retire des favoris.
    await tester.sendKeyEvent(LogicalKeyboardKey.keyF);
    await tester.pumpAndSettle();
    expect(store.data[kFavoritesKey], '[]');
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Historique').first);
    await tester.pumpAndSettle();
    expect(find.text('Chaîne Démo 1'), findsOneWidget);
    expect(find.textContaining('Regardée aujourd\'hui'), findsOneWidget);
    await tester.tap(find.byKey(const Key('history-clear')));
    await tester.pumpAndSettle();
    expect(find.text('Historique vide'), findsOneWidget);
  });

  test('libellé de l\'historique', () {
    final now = DateTime(2026, 11, 2, 20);
    expect(historyLabel(DateTime(2026, 11, 2, 9, 5), now), 'Regardée aujourd\'hui à 09:05');
    expect(historyLabel(DateTime(2026, 11, 1, 22, 30), now), 'Regardée hier à 22:30');
    expect(historyLabel(DateTime(2026, 10, 28, 8, 0), now), 'Regardée le 28/10 à 08:00');
  });
}
