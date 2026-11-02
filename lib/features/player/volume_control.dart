import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../state/sources_state.dart';
import 'playback.dart';

/// Gestion du volume : changement, coupure du son et mémorisation.
class VolumeActions {
  VolumeActions(this.ref);
  final WidgetRef ref;
  static double _beforeMute = 100;
  static Timer? _save;

  Playback get _p => ref.read(playbackProvider);

  Future<void> set(double v) async {
    final value = v.clamp(0, 100).toDouble();
    await _p.setVolume(value);
    _save?.cancel();
    final store = ref.read(secureStoreProvider);
    _save = Timer(const Duration(milliseconds: 600), () => store.write(kVolumeKey, value.round().toString()));
  }

  Future<void> step(double delta) => set(_p.volume + delta);

  Future<void> toggleMute() async {
    if (_p.volume > 0) {
      _beforeMute = _p.volume;
      await set(0);
    } else {
      await set(_beforeMute <= 0 ? 50 : _beforeMute);
    }
  }
}

/// Bouton muet + curseur de volume.
class VolumeControl extends ConsumerWidget {
  const VolumeControl({super.key, this.width = 160});
  final double width;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playback = ref.watch(playbackProvider);
    final actions = VolumeActions(ref);
    return StreamBuilder<double>(
      stream: playback.volumeStream,
      initialData: playback.volume,
      builder: (context, snap) {
        final v = snap.data ?? playback.volume;
        return Row(mainAxisSize: MainAxisSize.min, children: [
          IconButton(
            key: const Key('volume-mute'),
            tooltip: v == 0 ? 'Remettre le son (M)' : 'Couper le son (M)',
            onPressed: actions.toggleMute,
            icon: Icon(
              v == 0
                  ? Icons.volume_off_rounded
                  : v < 50
                      ? Icons.volume_down_rounded
                      : Icons.volume_up_rounded,
            ),
          ),
          SizedBox(
            width: width,
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: AppColors.accent,
                thumbColor: AppColors.accent,
                inactiveTrackColor: Colors.white24,
                trackHeight: 4,
                overlayShape: SliderComponentShape.noOverlay,
              ),
              child: Slider(
                key: const Key('volume-slider'),
                value: v.clamp(0, 100).toDouble(),
                max: 100,
                onChanged: actions.set,
                semanticFormatterCallback: (x) => 'Volume ${x.round()} %',
              ),
            ),
          ),
          SizedBox(
            width: 40,
            child: Text('${v.round()}', textAlign: TextAlign.right, style: const TextStyle(color: AppColors.textSecondary)),
          ),
        ]);
      },
    );
  }
}
