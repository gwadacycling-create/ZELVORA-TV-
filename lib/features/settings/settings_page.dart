import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/common.dart';
import '../../data/source_repository.dart';
import '../../domain/iptv_source.dart';
import '../../state/sources_state.dart';
import '../player/playback.dart';
import '../../state/parental_state.dart';
import '../update/update_service.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sources = ref.watch(sourcesProvider);
    return PageScaffold(
      title: 'Réglages',
      children: [
        _Section(
          title: 'Mes sources IPTV',
          children: [
            const Text(
              'Ajoutez uniquement des sources auxquelles vous avez légalement accès. '
              'ZELVORA TV ne fournit aucune chaîne ni aucun contenu. '
              'Vos liens et identifiants sont chiffrés sur cet appareil.',
              style: TextStyle(color: AppColors.textSecondary, height: 1.5),
            ),
            const SizedBox(height: 16),
            ...switch (sources) {
              AsyncData(:final value) => [for (final s in value) _SourceTile(source: s)],
              AsyncError() => [const Text('Impossible de lire les sources enregistrées.')],
              _ => [const LinearProgressIndicator()],
            },
            const SizedBox(height: 12),
            Wrap(spacing: 12, runSpacing: 12, children: [
              _SourceButton(
                icon: Icons.playlist_add_rounded,
                label: 'Playlist M3U / M3U8',
                onPressed: () => showDialog(context: context, builder: (_) => const AddM3uDialog()),
              ),
              _SourceButton(
                icon: Icons.dns_rounded,
                label: 'Compte Xtream Codes',
                onPressed: () => showDialog(context: context, builder: (_) => const AddXtreamDialog()),
              ),
            ]),
          ],
        ),
        const _Section(title: 'Lecture vidéo', children: [_CompatSwitch()]),
        const _Section(title: 'Contrôle parental', children: [ParentalSwitch()]),
        const _Section(
          title: 'Mise à jour',
          children: [
            Text('ZELVORA TV · version $kAppVersion', style: TextStyle(color: AppColors.textSecondary)),
            SizedBox(height: 12),
            UpdateCheck(),
          ],
        ),
      ],
    );
  }
}

class _SourceTile extends ConsumerWidget {
  const _SourceTile({required this.source});
  final IptvSource source;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref.watch(channelCacheProvider)[source.id]?.length;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(color: AppColors.surfaceHigh, borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: Icon(
            switch (source.kind) {
              SourceKind.m3uFile => Icons.insert_drive_file_rounded,
              SourceKind.m3uUrl => Icons.link_rounded,
              SourceKind.xtream => Icons.dns_rounded,
            },
            color: AppColors.accent),
        title: Text(source.name),
        subtitle: Text(
          '${source.kind == SourceKind.xtream ? 'Xtream Codes' : 'M3U'} · ${source.displayLocation}'
          '${count != null ? ' · $count chaînes' : ''}',
          style: const TextStyle(color: AppColors.textSecondary),
        ),
        trailing: IconButton(
          tooltip: 'Supprimer',
          icon: const Icon(Icons.delete_outline_rounded),
          onPressed: () async {
            final ok = await showDialog<bool>(
              context: context,
              builder: (c) => AlertDialog(
                title: const Text('Supprimer cette source ?'),
                content: Text('« ${source.name} » et ses chaînes seront retirées de l’application.'),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Annuler')),
                  FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Supprimer')),
                ],
              ),
            );
            if (ok == true) await ref.read(sourcesProvider.notifier).remove(source.id);
          },
        ),
      ),
    );
  }
}

/// Fenêtre d'ajout d'une playlist M3U (par lien ou par fichier).
class AddM3uDialog extends ConsumerStatefulWidget {
  const AddM3uDialog({super.key});

  @override
  ConsumerState<AddM3uDialog> createState() => _AddM3uDialogState();
}

class _AddM3uDialogState extends ConsumerState<AddM3uDialog> {
  final _name = TextEditingController();
  final _url = TextEditingController();
  SourceKind _kind = SourceKind.m3uUrl;
  String? _filePath;
  bool _legal = false;
  bool _hideUrl = true;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _url.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    final f = await FilePicker.pickFile(
      dialogTitle: 'Choisir une playlist M3U',
      type: FileType.custom,
      allowedExtensions: const ['m3u', 'm3u8', 'txt'],
    );
    if (f?.path != null) setState(() => _filePath = f!.path);
  }

  Future<void> _submit() async {
    final location = _kind == SourceKind.m3uUrl ? _url.text.trim() : (_filePath ?? '');
    if (location.isEmpty) {
      setState(() => _error = _kind == SourceKind.m3uUrl ? 'Saisissez le lien de la playlist.' : 'Choisissez un fichier.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final n = await ref.read(sourcesProvider.notifier).add(name: _name.text, kind: _kind, location: location);
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Playlist ajoutée : $n chaînes.')));
    } on SourceException catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(() => _error = 'Une erreur inattendue est survenue.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.surface,
      title: const Text('Ajouter une playlist M3U'),
      content: SizedBox(
        width: 520,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _name,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Nom (ex. : Ma box TV)'),
            ),
            const SizedBox(height: 16),
            SegmentedButton<SourceKind>(
              segments: const [
                ButtonSegment(value: SourceKind.m3uUrl, label: Text('Lien'), icon: Icon(Icons.link_rounded)),
                ButtonSegment(value: SourceKind.m3uFile, label: Text('Fichier'), icon: Icon(Icons.folder_open_rounded)),
              ],
              selected: {_kind},
              onSelectionChanged: (s) => setState(() => _kind = s.first),
            ),
            const SizedBox(height: 12),
            if (_kind == SourceKind.m3uUrl)
              TextField(
                key: const Key('m3u-url'),
                controller: _url,
                obscureText: _hideUrl,
                keyboardType: TextInputType.url,
                decoration: InputDecoration(
                  labelText: 'Lien de la playlist (http:// ou https://)',
                  suffixIcon: IconButton(
                    tooltip: _hideUrl ? 'Afficher' : 'Masquer',
                    icon: Icon(_hideUrl ? Icons.visibility_rounded : Icons.visibility_off_rounded),
                    onPressed: () => setState(() => _hideUrl = !_hideUrl),
                  ),
                ),
                onSubmitted: (_) => _legal && !_busy ? _submit() : null,
              )
            else
              Row(children: [
                OutlinedButton.icon(
                  onPressed: _pickFile,
                  icon: const Icon(Icons.folder_open_rounded),
                  label: const Text('Parcourir…'),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(_filePath?.split(RegExp(r'[\\/]')).last ?? 'Aucun fichier choisi',
                      overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.textSecondary)),
                ),
              ]),
            const SizedBox(height: 12),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: _legal,
              onChanged: (v) => setState(() => _legal = v ?? false),
              controlAffinity: ListTileControlAffinity.leading,
              title: const Text('Je certifie avoir le droit d’accéder à cette source.', style: TextStyle(fontSize: 14)),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(_error!, style: const TextStyle(color: AppColors.accentSoft)),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: _busy ? null : () => Navigator.pop(context), child: const Text('Annuler')),
        FilledButton(
          onPressed: _legal && !_busy ? _submit : null,
          child: _busy
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
              : const Text('Ajouter'),
        ),
      ],
    );
  }
}

/// Fenêtre d'ajout d'un compte Xtream Codes (serveur, identifiant, mot de passe).
class AddXtreamDialog extends ConsumerStatefulWidget {
  const AddXtreamDialog({super.key});

  @override
  ConsumerState<AddXtreamDialog> createState() => _AddXtreamDialogState();
}

class _AddXtreamDialogState extends ConsumerState<AddXtreamDialog> {
  final _name = TextEditingController();
  final _server = TextEditingController();
  final _user = TextEditingController();
  final _pass = TextEditingController();
  bool _legal = false;
  bool _hidePass = true;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    for (final c in [_name, _server, _user, _pass]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (_server.text.trim().isEmpty || _user.text.trim().isEmpty || _pass.text.isEmpty) {
      setState(() => _error = 'Renseignez le serveur, l’identifiant et le mot de passe.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final n = await ref.read(sourcesProvider.notifier).add(
            name: _name.text,
            kind: SourceKind.xtream,
            location: _server.text,
            username: _user.text,
            password: _pass.text,
          );
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Compte Xtream ajouté : $n chaînes.')));
    } on SourceException catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(() => _error = 'Une erreur inattendue est survenue.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.surface,
      title: const Text('Ajouter un compte Xtream Codes'),
      content: SizedBox(
        width: 520,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(controller: _name, autofocus: true, decoration: const InputDecoration(labelText: 'Nom (ex. : Mon abonnement)')),
            const SizedBox(height: 8),
            TextField(
              key: const Key('xt-server'),
              controller: _server,
              keyboardType: TextInputType.url,
              decoration: const InputDecoration(labelText: 'Adresse du serveur (ex. : http://serveur.com:8080)'),
            ),
            const SizedBox(height: 8),
            TextField(key: const Key('xt-user'), controller: _user, decoration: const InputDecoration(labelText: 'Identifiant')),
            const SizedBox(height: 8),
            TextField(
              key: const Key('xt-pass'),
              controller: _pass,
              obscureText: _hidePass,
              decoration: InputDecoration(
                labelText: 'Mot de passe',
                suffixIcon: IconButton(
                  tooltip: _hidePass ? 'Afficher' : 'Masquer',
                  icon: Icon(_hidePass ? Icons.visibility_rounded : Icons.visibility_off_rounded),
                  onPressed: () => setState(() => _hidePass = !_hidePass),
                ),
              ),
              onSubmitted: (_) => _legal && !_busy ? _submit() : null,
            ),
            const SizedBox(height: 12),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: _legal,
              onChanged: (v) => setState(() => _legal = v ?? false),
              controlAffinity: ListTileControlAffinity.leading,
              title: const Text('Je certifie avoir le droit d’accéder à ce service.', style: TextStyle(fontSize: 14)),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(_error!, style: const TextStyle(color: AppColors.accentSoft)),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: _busy ? null : () => Navigator.pop(context), child: const Text('Annuler')),
        FilledButton(
          onPressed: _legal && !_busy ? _submit : null,
          child: _busy
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
              : const Text('Se connecter'),
        ),
      ],
    );
  }
}

class _SourceButton extends StatelessWidget {
  const _SourceButton({required this.icon, required this.label, required this.onPressed});
  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children});
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _CompatSwitch extends ConsumerStatefulWidget {
  const _CompatSwitch();

  @override
  ConsumerState<_CompatSwitch> createState() => _CompatSwitchState();
}

class _CompatSwitchState extends ConsumerState<_CompatSwitch> {
  late bool _value = ref.read(videoCompatModeProvider);

  @override
  Widget build(BuildContext context) {
    final changed = _value != ref.read(videoCompatModeProvider);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        value: _value,
        title: const Text('Mode compatibilité vidéo'),
        subtitle: const Text(
          'À activer si le son fonctionne mais que l’image reste noire. '
          'Désactive l’accélération de la carte graphique.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        onChanged: (v) async {
          setState(() => _value = v);
          await ref.read(secureStoreProvider).write(kVideoCompatKey, v ? '1' : '0');
        },
      ),
      if (changed)
        const Text('Redémarrez ZELVORA TV pour appliquer ce réglage.', style: TextStyle(color: AppColors.accentSoft)),
    ]);
  }
}

/// Recherche et installation manuelle d'une mise à jour (Réglages).
class UpdateCheck extends ConsumerStatefulWidget {
  const UpdateCheck({super.key});

  @override
  ConsumerState<UpdateCheck> createState() => _UpdateCheckState();
}

class _UpdateCheckState extends ConsumerState<UpdateCheck> {
  bool _checking = false;
  bool _checked = false;
  UpdateInfo? _found;
  double? _progress;
  String? _error;

  Future<void> _check() async {
    setState(() { _checking = true; _error = null; });
    final info = await ref.read(updateServiceProvider).check();
    if (!mounted) return;
    setState(() { _checking = false; _checked = true; _found = info; });
  }

  Future<void> _install(UpdateInfo info) async {
    setState(() { _progress = 0; _error = null; });
    try {
      await ref.read(updateServiceProvider).install(info, onProgress: (p) => setState(() => _progress = p));
    } catch (_) {
      if (mounted) setState(() { _progress = null; _error = 'La mise à jour a échoué. Réessayez plus tard.'; });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!ref.watch(updatesSupportedProvider)) {
      return const Text(
        'Sur Android, installez la dernière version (fichier APK) depuis la page des versions de ZELVORA TV.',
        style: TextStyle(color: AppColors.textSecondary),
      );
    }
    final found = _found;
    final String status;
    if (_error != null) {
      status = _error!;
    } else if (_progress != null) {
      status = 'Téléchargement de la version ${found?.version}… ${(_progress! * 100).round()} %';
    } else if (_checking) {
      status = 'Recherche en cours…';
    } else if (found != null) {
      status = 'Nouvelle version disponible : ${found.version}';
    } else if (_checked) {
      status = 'Vous avez la dernière version.';
    } else {
      status = 'Les mises à jour s\'installent automatiquement au démarrage.';
    }
    return Wrap(
      spacing: 16,
      runSpacing: 10,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        if (found != null && _progress == null)
          FilledButton.icon(
            key: const Key('update-install'),
            onPressed: () => _install(found),
            icon: const Icon(Icons.download_rounded),
            label: Text('Installer la version ${found.version}'),
          )
        else
          OutlinedButton.icon(
            key: const Key('update-check'),
            onPressed: _checking || _progress != null ? null : _check,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Rechercher une mise à jour'),
          ),
        Text(status, style: const TextStyle(color: AppColors.textSecondary)),
      ],
    );
  }
}

/// Contrôle parental : masque les catégories adultes, code PIN pour désactiver.
class ParentalSwitch extends ConsumerWidget {
  const ParentalSwitch({super.key});

  Future<String?> _askPin(BuildContext context, String title) {
    final ctl = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(
          key: const Key('parental-pin'),
          controller: ctl,
          autofocus: true,
          obscureText: true,
          keyboardType: TextInputType.number,
          maxLength: 4,
          decoration: const InputDecoration(hintText: 'Code à 4 chiffres'),
          onSubmitted: (v) => Navigator.of(ctx).pop(v),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Annuler')),
          FilledButton(onPressed: () => Navigator.of(ctx).pop(ctl.text), child: const Text('Valider')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = ref.watch(parentalProvider);
    return SwitchListTile(
      key: const Key('parental-switch'),
      contentPadding: EdgeInsets.zero,
      value: p.enabled,
      title: const Text('Masquer les contenus adultes'),
      subtitle: const Text(
        'Cache les catégories et titres adultes (chaînes, films, séries). Un code PIN est demandé pour désactiver.',
        style: TextStyle(color: AppColors.textSecondary),
      ),
      onChanged: (v) async {
        final messenger = ScaffoldMessenger.of(context);
        final n = ref.read(parentalProvider.notifier);
        if (v) {
          final pin = await _askPin(context, 'Choisissez un code PIN');
          if (pin == null) return;
          if (!RegExp(r'^\d{4}$').hasMatch(pin)) {
            messenger.showSnackBar(const SnackBar(content: Text('Le code doit contenir 4 chiffres.')));
            return;
          }
          await n.enable(pin);
        } else {
          if (!context.mounted) return;
          final pin = await _askPin(context, 'Code PIN du contrôle parental');
          if (pin == null) return;
          if (!await n.disable(pin)) {
            messenger.showSnackBar(const SnackBar(content: Text('Code incorrect.')));
          }
        }
      },
    );
  }
}
