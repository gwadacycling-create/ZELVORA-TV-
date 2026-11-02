import 'dart:async';
import 'dart:io';
import 'dart:isolate';

/// Les gros traitements (lecture des playlists, réponses Xtream) sont faits
/// dans un fil séparé pour que l'écran reste toujours réactif.
/// Pendant les tests automatiques le temps est simulé : on reste sur place
/// (sauf si un test active explicitement le fil séparé).
bool useBackgroundThread = !Platform.environment.containsKey('FLUTTER_TEST');

Future<T> inBackground<T>(FutureOr<T> Function() work) async =>
    useBackgroundThread ? await Isolate.run(work) : await work();
