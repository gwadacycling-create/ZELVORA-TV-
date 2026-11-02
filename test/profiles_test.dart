import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zelvora_tv/data/source_repository.dart';
import 'package:zelvora_tv/domain/channel.dart';
import 'package:zelvora_tv/state/library_state.dart';
import 'package:zelvora_tv/state/parental_state.dart';
import 'package:zelvora_tv/state/profile_state.dart';
import 'package:zelvora_tv/state/sources_state.dart';

import 'helpers.dart';

Future<void> settle() async {
  for (var i = 0; i < 5; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  test('profils enregistrés et relus', () {
    const s = ProfilesState([Profile(id: kMainProfileId, name: 'Principal'), Profile(id: 'k', name: 'Léa', kids: true)], 'k');
    final back = ProfilesState.decode(s.encode());
    expect(back.list, s.list);
    expect(back.current.name, 'Léa');
    expect(ProfilesState.decode('n/a').list.single.id, kMainProfileId);
    expect(profileKey(kFavoritesKey, s.list[0]), kFavoritesKey, reason: 'le profil Principal garde les anciennes données');
    expect(profileKey(kFavoritesKey, s.list[1]), '$kFavoritesKey.k');
  });

  test('chaque profil a ses favoris ; le profil Enfant masque les contenus adultes', () async {
    final store = MemorySecureStore();
    final c = ProviderContainer(overrides: [secureStoreProvider.overrideWithValue(store)]);
    addTearDown(c.dispose);
    c.listen(favoritesProvider, (_, _) {});
    const tf1 = Channel(name: 'Une', url: 'http://x/1.ts', sourceId: 's');
    await settle();
    await c.read(favoritesProvider.notifier).toggle(tf1);
    expect(c.read(favoritesProvider), [tf1.key]);
    expect(c.read(hideAdultProvider), isFalse);

    final kid = await c.read(profilesProvider.notifier).add('Léa', kids: true);
    await c.read(profilesProvider.notifier).select(kid.id);
    await settle();
    expect(c.read(favoritesProvider), isEmpty);
    expect(c.read(hideAdultProvider), isTrue);

    await c.read(profilesProvider.notifier).select(kMainProfileId);
    await settle();
    expect(c.read(favoritesProvider), [tf1.key]);
    expect(c.read(hideAdultProvider), isFalse);
    expect(ProfilesState.decode(await store.read(kProfilesKey)).list, hasLength(2));
  });

  testWidgets('« Qui regarde ? » au démarrage ; code PIN pour quitter le profil Enfant', (tester) async {
    await pumpApp(
      tester,
      profiles: const ProfilesState([Profile(id: kMainProfileId, name: 'Papa'), Profile(id: 'k', name: 'Léa', kids: true)], 'k'),
    );
    expect(find.text('Qui regarde ?'), findsOneWidget);
    await ProviderScope.containerOf(tester.element(find.text('Papa'))).read(parentalProvider.notifier).setPin('1234');
    await tester.tap(find.text('Papa'));
    await tester.pumpAndSettle();
    expect(find.text('Code PIN pour quitter le profil Enfant'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('parental-pin')), '0000');
    await tester.tap(find.text('Valider'));
    await tester.pumpAndSettle();
    expect(find.text('Qui regarde ?'), findsOneWidget, reason: 'mauvais code : on reste');
    await tester.tap(find.text('Léa'));
    await tester.pumpAndSettle();
    expect(find.text('Qui regarde ?'), findsNothing, reason: 'profil Enfant ouvert sans code');
  });
}
