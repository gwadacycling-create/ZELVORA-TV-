import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';

import 'app.dart';
import 'data/source_repository.dart';
import 'features/player/playback.dart';
import 'state/parental_state.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  var compat = false;
  var volume = 100.0;
  var parental = const ParentalSettings();
  try {
    const store = SystemSecureStore();
    compat = await store.read(kVideoCompatKey) == '1';
    volume = double.tryParse(await store.read(kVolumeKey) ?? '') ?? 100;
    parental = ParentalSettings.decode(await store.read(kParentalKey));
  } catch (_) {}
  runApp(ProviderScope(
    overrides: [
      videoCompatModeProvider.overrideWithValue(compat),
      initialVolumeProvider.overrideWithValue(volume),
      initialParentalProvider.overrideWithValue(parental),
    ],
    child: const ZelvoraApp(),
  ));
}
