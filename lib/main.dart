import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';

import 'app.dart';
import 'data/source_repository.dart';
import 'features/player/playback.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  var compat = false;
  try {
    compat = await const SystemSecureStore().read(kVideoCompatKey) == '1';
  } catch (_) {}
  runApp(ProviderScope(
    overrides: [videoCompatModeProvider.overrideWithValue(compat)],
    child: const ZelvoraApp(),
  ));
}
