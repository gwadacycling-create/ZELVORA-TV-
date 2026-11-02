import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import 'update_service.dart';

/// Bandeau affiché en haut de l'application quand une nouvelle version existe.
class UpdateBanner extends ConsumerStatefulWidget {
  const UpdateBanner({super.key});

  @override
  ConsumerState<UpdateBanner> createState() => _UpdateBannerState();
}

class _UpdateBannerState extends ConsumerState<UpdateBanner> {
  bool _dismissed = false;
  double? _progress;
  String? _error;

  Future<void> _install(UpdateInfo info) async {
    setState(() {
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
                      : 'Une nouvelle version de ZELVORA TV est disponible (${info.version}).'),
            ),
          ),
          if (_progress == null) ...[
            TextButton(onPressed: () => setState(() => _dismissed = true), child: const Text('Plus tard')),
            const SizedBox(width: 8),
            FilledButton(onPressed: () => _install(info), child: const Text('Mettre à jour')),
          ] else
            const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: AppColors.accent)),
        ]),
      ),
    );
  }
}
