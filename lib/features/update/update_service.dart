import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

/// Version de l'application, injectée à la compilation (--dart-define=APP_VERSION=x.y.z).
const kAppVersion = String.fromEnvironment('APP_VERSION', defaultValue: '0.0.0');

/// Les installeurs sont publiés dans les « Releases » du dépôt GitHub.
const kReleasesApi = 'https://api.github.com/repos/gwadacycling-create/ZELVORA-TV-/releases/latest';

class UpdateInfo {
  const UpdateInfo(this.version, this.installerUrl, this.notes);
  final String version;
  final String installerUrl;
  final String notes;
}

/// Compare deux versions « 1.2.3 ». Renvoie > 0 si [a] est plus récente.
int compareVersions(String a, String b) {
  List<int> parse(String v) =>
      v.replaceFirst(RegExp(r'^v'), '').split(RegExp(r'[.+-]')).take(3).map((p) => int.tryParse(p) ?? 0).toList();
  final x = parse(a), y = parse(b);
  for (var i = 0; i < 3; i++) {
    final d = (i < x.length ? x[i] : 0) - (i < y.length ? y[i] : 0);
    if (d != 0) return d;
  }
  return 0;
}

class UpdateService {
  UpdateService({http.Client? client, this.currentVersion = kAppVersion}) : _client = client ?? http.Client();
  final http.Client _client;
  final String currentVersion;

  /// Renvoie la mise à jour disponible, ou null (à jour, hors ligne, erreur).
  Future<UpdateInfo?> check() async {
    try {
      final res = await _client
          .get(Uri.parse(kReleasesApi), headers: const {'Accept': 'application/vnd.github+json'})
          .timeout(const Duration(seconds: 15));
      if (res.statusCode != 200) return null;
      final j = jsonDecode(res.body) as Map<String, dynamic>;
      final tag = (j['tag_name'] as String? ?? '').replaceFirst('v', '');
      if (tag.isEmpty || compareVersions(tag, currentVersion) <= 0) return null;
      final assets = (j['assets'] as List? ?? const []).cast<Map<String, dynamic>>();
      final exe = assets.where((a) => (a['name'] as String? ?? '').toLowerCase().endsWith('.exe'));
      if (exe.isEmpty) return null;
      return UpdateInfo(tag, exe.first['browser_download_url'] as String, j['body'] as String? ?? '');
    } catch (_) {
      return null;
    }
  }

  /// Télécharge l'installeur, le lance en mode silencieux et ferme l'application.
  /// L'installeur relance ZELVORA TV automatiquement à la fin.
  Future<void> install(UpdateInfo info, {void Function(double)? onProgress}) async {
    final req = http.Request('GET', Uri.parse(info.installerUrl));
    final res = await _client.send(req);
    if (res.statusCode != 200) throw Exception('Téléchargement impossible (${res.statusCode}).');
    final file = File('${Directory.systemTemp.path}${Platform.pathSeparator}ZELVORA-TV-Setup-${info.version}.exe');
    final sink = file.openWrite();
    final total = res.contentLength ?? 0;
    var done = 0;
    await for (final chunk in res.stream) {
      sink.add(chunk);
      done += chunk.length;
      if (total > 0) onProgress?.call(done / total);
    }
    await sink.close();
    await Process.start(file.path, const ['/SILENT', '/SUPPRESSMSGBOXES', '/NORESTART', '/CLOSEAPPLICATIONS'],
        mode: ProcessStartMode.detached);
    exit(0);
  }
}

final updateServiceProvider = Provider<UpdateService>((ref) => UpdateService());

/// Vérifie au démarrage puis toutes les heures (Windows uniquement).
final availableUpdateProvider = StreamProvider<UpdateInfo?>((ref) async* {
  if (!Platform.isWindows) {
    yield null;
    return;
  }
  final service = ref.read(updateServiceProvider);
  while (true) {
    yield await service.check();
    await Future<void>.delayed(const Duration(hours: 1));
  }
});
