import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:zelvora_tv/features/settings/settings_page.dart';
import 'package:zelvora_tv/features/update/update_service.dart';

void main() {
  test('comparaison de versions', () {
    expect(compareVersions('0.2.1', '0.2.0'), greaterThan(0));
    expect(compareVersions('v1.0.0', '0.9.9'), greaterThan(0));
    expect(compareVersions('0.10.0', '0.9.0'), greaterThan(0));
    expect(compareVersions('0.2.0', '0.2.0'), 0);
    expect(compareVersions('0.1.9', '0.2.0'), lessThan(0));
  });

  http.Client api(String tag, {int status = 200}) => MockClient((r) async => http.Response(
      jsonEncode({
        'tag_name': tag,
        'body': 'Notes',
        'assets': [
          {'name': 'ZELVORA-TV-Setup-${tag.substring(1)}.exe', 'browser_download_url': 'https://dl/setup.exe'}
        ],
      }),
      status));

  test('détecte une version plus récente', () async {
    final info = await UpdateService(client: api('v0.3.0'), currentVersion: '0.2.1').check();
    expect(info?.version, '0.3.0');
    expect(info?.installerUrl, 'https://dl/setup.exe');
  });

  test('rien si déjà à jour, hors ligne ou erreur', () async {
    expect(await UpdateService(client: api('v0.2.1'), currentVersion: '0.2.1').check(), isNull);
    expect(await UpdateService(client: api('v0.3.0', status: 404), currentVersion: '0.2.1').check(), isNull);
    expect(
        await UpdateService(client: MockClient((_) async => throw Exception('offline')), currentVersion: '0.2.1').check(),
        isNull);
  });

  Future<void> pumpCheck(WidgetTester tester, String tag) => tester.pumpWidget(ProviderScope(
        overrides: [updatesSupportedProvider.overrideWithValue(true), updateServiceProvider.overrideWithValue(UpdateService(client: api(tag), currentVersion: '0.2.1'))],
        child: const MaterialApp(home: Scaffold(body: UpdateCheck())),
      ));

  testWidgets('Réglages : rechercher une mise à jour', (tester) async {
    await pumpCheck(tester, 'v0.3.0');
    await tester.tap(find.byKey(const Key('update-check')));
    await tester.pumpAndSettle();
    expect(find.text('Nouvelle version disponible : 0.3.0'), findsOneWidget);
    expect(find.byKey(const Key('update-install')), findsOneWidget);
  });

  testWidgets('Réglages : déjà à jour', (tester) async {
    await pumpCheck(tester, 'v0.2.1');
    await tester.tap(find.byKey(const Key('update-check')));
    await tester.pumpAndSettle();
    expect(find.text('Vous avez la dernière version.'), findsOneWidget);
  });
}
