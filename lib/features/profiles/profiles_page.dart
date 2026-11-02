import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../state/parental_state.dart';
import '../../state/profile_state.dart';

/// Demande un code PIN à 4 chiffres (null si annulé).
Future<String?> askPin(BuildContext context, String title) {
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

IconData profileIcon(Profile p) => p.kids ? Icons.child_care_rounded : Icons.person_rounded;

/// Change de profil. Quitter un profil Enfant demande le code PIN.
/// Renvoie true si le profil a changé.
Future<bool> switchProfile(BuildContext context, WidgetRef ref, Profile target) async {
  final current = ref.read(currentProfileProvider);
  final pin = ref.read(parentalProvider).pin;
  if (current.kids && !target.kids && pin != null) {
    final messenger = ScaffoldMessenger.of(context);
    final entered = await askPin(context, 'Code PIN pour quitter le profil Enfant');
    if (entered == null) return false;
    if (entered != pin) {
      messenger.showSnackBar(const SnackBar(content: Text('Code incorrect.')));
      return false;
    }
  }
  await ref.read(profilesProvider.notifier).select(target.id);
  return true;
}

/// Écran « Qui regarde ? », affiché au démarrage quand il y a plusieurs profils.
class ProfilesPage extends ConsumerWidget {
  const ProfilesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(profilesProvider);
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('Qui regarde ?', style: TextStyle(fontSize: 40, fontWeight: FontWeight.w900)),
            const SizedBox(height: 36),
            Wrap(spacing: 24, runSpacing: 24, alignment: WrapAlignment.center, children: [
              for (final p in s.list)
                _ProfileTile(
                  profile: p,
                  autofocus: p.id == s.currentId,
                  onTap: () async {
                    if (await switchProfile(context, ref, p) && context.mounted) context.go('/');
                  },
                ),
            ]),
          ]),
        ),
      ),
    );
  }
}

class _ProfileTile extends StatefulWidget {
  const _ProfileTile({required this.profile, required this.onTap, this.autofocus = false});
  final Profile profile;
  final VoidCallback onTap;
  final bool autofocus;

  @override
  State<_ProfileTile> createState() => _ProfileTileState();
}

class _ProfileTileState extends State<_ProfileTile> {
  bool _active = false;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      autofocus: widget.autofocus,
      onTap: widget.onTap,
      onFocusChange: (f) => setState(() => _active = f),
      onHover: (h) => setState(() => _active = h),
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 170,
        padding: const EdgeInsets.symmetric(vertical: 24),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _active ? AppColors.accent : AppColors.border, width: 2),
        ),
        child: Column(children: [
          Container(
            width: 84,
            height: 84,
            decoration: const BoxDecoration(shape: BoxShape.circle, gradient: AppColors.accentGradient),
            child: Icon(profileIcon(widget.profile), size: 46, color: Colors.black),
          ),
          const SizedBox(height: 14),
          Text(widget.profile.name,
              maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          if (widget.profile.kids) const Text('Enfant', style: TextStyle(color: AppColors.textSecondary)),
        ]),
      ),
    );
  }
}

/// Réglages : liste des profils, ajout, suppression et changement.
class ProfilesSection extends ConsumerWidget {
  const ProfilesSection({super.key});

  Future<void> _add(BuildContext context, WidgetRef ref) async {
    final name = TextEditingController();
    var kids = false;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('Nouveau profil'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(
              key: const Key('profile-name'),
              controller: name,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Prénom ou nom du profil'),
            ),
            SwitchListTile(
              key: const Key('profile-kids'),
              contentPadding: EdgeInsets.zero,
              value: kids,
              onChanged: (v) => setState(() => kids = v),
              title: const Text('Profil Enfant'),
              subtitle: const Text('Contenus adultes toujours masqués. Code PIN pour en sortir.',
                  style: TextStyle(color: AppColors.textSecondary)),
            ),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Annuler')),
            FilledButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Créer')),
          ],
        ),
      ),
    );
    if (ok != true || !context.mounted) return;
    // Un profil Enfant a besoin d'un code PIN pour qu'on ne puisse pas en sortir librement.
    if (kids && ref.read(parentalProvider).pin == null) {
      final messenger = ScaffoldMessenger.of(context);
      final pin = await askPin(context, 'Choisissez un code PIN (pour quitter le profil Enfant)');
      if (pin == null) return;
      if (!RegExp(r'^\d{4}$').hasMatch(pin)) {
        messenger.showSnackBar(const SnackBar(content: Text('Le code doit contenir 4 chiffres.')));
        return;
      }
      await ref.read(parentalProvider.notifier).setPin(pin);
    }
    await ref.read(profilesProvider.notifier).add(name.text, kids: kids);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(profilesProvider);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text(
        'Chaque profil a ses propres favoris, son historique et sa reprise des films. '
        'Avec plusieurs profils, l’application demande « Qui regarde ? » au démarrage.',
        style: TextStyle(color: AppColors.textSecondary, height: 1.5),
      ),
      const SizedBox(height: 12),
      for (final p in s.list)
        Container(
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(color: AppColors.surfaceHigh, borderRadius: BorderRadius.circular(12)),
          child: ListTile(
            leading: Icon(profileIcon(p), color: AppColors.accent),
            title: Text(p.name),
            subtitle: Text(p.kids ? 'Profil Enfant' : 'Profil adulte', style: const TextStyle(color: AppColors.textSecondary)),
            onTap: p.id == s.currentId ? null : () => switchProfile(context, ref, p),
            trailing: Row(mainAxisSize: MainAxisSize.min, children: [
              if (p.id == s.currentId)
                const Padding(
                  padding: EdgeInsets.only(right: 8),
                  child: Text('Actif', style: TextStyle(color: AppColors.accent, fontWeight: FontWeight.w700)),
                ),
              if (p.id != kMainProfileId && p.id != s.currentId)
                IconButton(
                  tooltip: 'Supprimer le profil',
                  icon: const Icon(Icons.delete_outline_rounded),
                  onPressed: () => ref.read(profilesProvider.notifier).remove(p.id),
                ),
            ]),
          ),
        ),
      const SizedBox(height: 4),
      OutlinedButton.icon(
        key: const Key('profile-add'),
        onPressed: () => _add(context, ref),
        icon: const Icon(Icons.person_add_alt_1_rounded),
        label: const Text('Ajouter un profil'),
      ),
    ]);
  }
}
