import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../player/playback.dart';
import 'update_service.dart';

/// Bandeau affiché quand une nouvelle version existe.
/// Si rien n'est en lecture, la mise à jour s'installe toute seule après un
/// court compte à rebours (bouton « Plus tard » pour la reporter).
class UpdateBanner extends ConsumerStatefulWidget {
  const UpdateBanner({super.key});

  @override
  ConsumerState<UpdateBanner> createState() => _UpdateBannerState();
}

class _UpdateBannerState extends ConsumerState<UpdateBanner> {
  bool _dismissed = false;
  double? _progress;
  String? _error;
  int? _countdown;
  Timer? _timer;
  String? _scheduledFor;

  static const _delay = 10;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _schedule(UpdateInfo info) {
    if (_scheduledFor == info.version || _dismissed) return;
    _scheduledFor = info.version;
    // Pas d'installation automatique pendant qu'une chaîne est en lecture.
    if (ref.read(currentChannelProvider) != null) return;
    _countdown = _delay;
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return t.cancel();
      if (ref.read(currentChannelProvider) != null) {
        t.cancel();
        setState(() => _countdown = null);
        return;
      }
      setState(() => _countdown = _countdown! - 1);
      if (_countdown! <= 0) {
        t.cancel();
        _install(info);
      }
    });
  }

  Future<void> _install(UpdateInfo info) async {
    _timer?.cancel();
    setState(() {
      _countdown = null;
      _progress = 0;
      _error = null;
    });
    try {
      await ref.read(updateServiceProvider).install(info, onProgress: (p) => setState(() => _progress = p));
    } catch (e) {
      setState(() {
        _progress = null;
        _error = 'La mise à jour a échoué. Réessayez plus tard.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final info = ref.watch(availableUpdateProvider).value;
    if (info == null || _dismissed) return const SizedBox.shrink();
    if (_scheduledFor != info.version) WidgetsBinding.instance.addPostFrameCallback((_) => _schedule(info));
    return Material(
      color: AppColors.accent.withValues(alpha: 0.14),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
        child: Row(children: [
          const Icon(Icons.system_update_alt_rounded, color: AppColors.accent),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _error ??
                  (_progress != null
                      ? 'Téléchargement de la version ${info.version}… ${(_progress! * 100).round()} %'
                      : _countdown != null
                          ? 'Nouvelle version ${info.version} : installation automatique dans $_countdown s…'
                          : 'Une nouvelle version de ZELVORA TV est disponible (${info.version}).'),
            ),
          ),
          if (_progress == null) ...[
            TextButton(
              onPressed: () {
                _timer?.cancel();
                setState(() => _dismissed = true);
              },
              child: const Text('Plus tard'),
            ),
            const SizedBox(width: 8),
            FilledButton(onPressed: () => _install(info), child: const Text('Mettre à jour')),
          ] else
            const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: AppColors.accent)),
        ]),
      ),
    );
  }
}
