import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';

import 'app.dart';
import 'core/freeze_monitor.dart';
import 'data/source_repository.dart';
import 'features/player/playback.dart';
import 'state/parental_state.dart';
import 'state/profile_state.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  FreezeMonitor.instance.start();
  var compat = false;
  var volume = 100.0;
  var parental = const ParentalSettings();
  var profiles = ProfilesState.initial;
  try {
    const store = SystemSecureStore();
    compat = await store.read(kVideoCompatKey) == '1';
    volume = double.tryParse(await store.read(kVolumeKey) ?? '') ?? 100;
    parental = ParentalSettings.decode(await store.read(kParentalKey));
    profiles = ProfilesState.decode(await store.read(kProfilesKey));
  } catch (_) {}
  runApp(ProviderScope(
    overrides: [
      videoCompatModeProvider.overrideWithValue(compat),
      initialVolumeProvider.overrideWithValue(volume),
      initialParentalProvider.overrideWithValue(parental),
      initialProfilesProvider.overrideWithValue(profiles),
    ],
    child: const ZelvoraApp(),
  ));
}
