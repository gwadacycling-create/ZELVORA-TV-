import 'package:flutter_test/flutter_test.dart';
import 'package:zelvora_tv/features/player/reconnect.dart';

void main() {
  test('reconnexions limitées avec attente progressive', () {
    final p = ReconnectPolicy();
    p.onProgress(DateTime(2026)); // la chaîne a démarré
    expect([for (var i = 0; i < 5; i++) p.nextDelay()!.inSeconds], [1, 2, 4, 8, 16]);
    expect(p.nextDelay(), isNull, reason: 'pas de boucle infinie');
  });

  test('chaîne qui ne démarre jamais : abandon rapide', () {
    final p = ReconnectPolicy();
    expect(p.nextDelay(), isNotNull);
    expect(p.nextDelay(), isNotNull);
    expect(p.nextDelay(), isNull);
  });

  test('compteur remis à zéro après 60 s de lecture correcte', () {
    final p = ReconnectPolicy();
    final t0 = DateTime(2026);
    p.onProgress(t0);
    p.nextDelay();
    p.nextDelay();
    p.onProgress(t0.add(const Duration(seconds: 5)));
    expect(p.attempts, 2);
    p.onProgress(t0.add(const Duration(seconds: 70)));
    expect(p.attempts, 0);
    expect(p.total, 2);
  });

  test('les URL sont masquées dans le journal (pas d\'identifiants)', () {
    final s = maskUrls('Failed http://user:pw@srv.example.com:8080/live/jean/secret/123.ts?token=abc end');
    expect(s, 'Failed http://srv.example.com/… end');
    expect(s.contains('secret'), isFalse);
    expect(s.contains('jean'), isFalse);
  });

  test('détection HLS / flux continu', () {
    expect(isHls('http://a.b/live/u/p/1.m3u8'), isTrue);
    expect(isHls('http://a.b/live/u/p/1.ts'), isFalse);
    expect(isHls('http://a.b/x.M3U8?t=1'), isTrue);
  });
}
