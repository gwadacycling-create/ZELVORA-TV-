import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/channel_tiles.dart';
import '../../core/widgets/visuals.dart';
import '../../domain/channel.dart';
import '../../state/sources_state.dart';
import '../player/playback.dart';

const _days = ['lun.', 'mar.', 'mer.', 'jeu.', 'ven.', 'sam.', 'dim.'];
const _months = ['janv.', 'févr.', 'mars', 'avr.', 'mai', 'juin', 'juil.', 'août', 'sept.', 'oct.', 'nov.', 'déc.'];
String _fmtDay(DateTime d) => '${_days[d.weekday - 1]} ${d.day} ${_months[d.month - 1]}';
String _hhmm(DateTime t) => '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

/// Guide TV : grille chaînes × horaires.
/// Les programmes s'afficheront avec le guide EPG (étape 4).
class GuidePage extends ConsumerStatefulWidget {
  const GuidePage({super.key});

  @override
  ConsumerState<GuidePage> createState() => _GuidePageState();
}

class _GuidePageState extends ConsumerState<GuidePage> {
  static const _slotWidth = 160.0; // 30 minutes
  static const _rowHeight = 58.0;
  static const _channelCol = 230.0;
  int _day = 0;
  Channel? _selected;

  @override
  Widget build(BuildContext context) {
    final channels = ref.watch(channelsProvider).value?.channels ?? const <Channel>[];
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day, now.hour - 1, now.minute >= 30 ? 30 : 0);
    final slots = List.generate(10, (i) => start.add(Duration(minutes: 30 * i)));
    final nowX = now.difference(start).inMinutes / 30 * _slotWidth;
    final selected = _selected ?? (channels.isEmpty ? null : channels.first);

    return Stack(children: [
      HeroHeader(
        height: 230,
        sunX: 0.68,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(40, 24, 32, 0),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Guide TV', style: TextStyle(fontSize: 46, fontWeight: FontWeight.w900)),
                SizedBox(height: 4),
                Text('Consultez le programme TV, naviguez entre les chaînes et ne manquez rien de vos émissions.',
                    style: TextStyle(fontSize: 16, color: Color(0xFFE4E4E7))),
              ]),
            ),
            const TopBar(),
          ]),
        ),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(32, 150, 32, 24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          // Sélecteur de jour.
          Row(children: [
            _RoundBtn(icon: Icons.chevron_left_rounded, onTap: _day > 0 ? () => setState(() => _day--) : null),
            const SizedBox(width: 10),
            for (var d = 0; d < 3; d++) ...[
              _DayChip(
                label: d == 0
                    ? 'Aujourd’hui · ${_fmtDay(now)}'
                    : d == 1
                        ? 'Demain'
                        : _fmtDay(now.add(Duration(days: d))),
                selected: _day == d,
                onTap: () => setState(() => _day = d),
              ),
              const SizedBox(width: 10),
            ],
            _RoundBtn(icon: Icons.chevron_right_rounded, onTap: _day < 2 ? () => setState(() => _day++) : null),
          ]),
          const SizedBox(height: 16),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xE6111114),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              clipBehavior: Clip.antiAlias,
              child: channels.isEmpty
                  ? const Center(
                      child: Text('Ajoutez une source pour afficher la grille des chaînes.',
                          style: TextStyle(color: AppColors.textSecondary)))
                  : SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: SizedBox(
                        width: _channelCol + slots.length * _slotWidth,
                        child: Stack(children: [
                          Column(children: [
                            // En-tête horaire.
                            SizedBox(
                              height: 50,
                              child: Row(children: [
                                const SizedBox(width: _channelCol),
                                for (final s in slots)
                                  SizedBox(
                                    width: _slotWidth,
                                    child: Padding(
                                      padding: const EdgeInsets.only(left: 10, top: 14),
                                      child: Text(_hhmm(s), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                                    ),
                                  ),
                              ]),
                            ),
                            Expanded(
                              child: ListView.builder(
                                itemCount: channels.length,
                                itemExtent: _rowHeight,
                                itemBuilder: (context, i) {
                                  final c = channels[i];
                                  return Row(children: [
                                    InkWell(
                                      onTap: () => setState(() => _selected = c),
                                      child: Container(
                                        width: _channelCol,
                                        padding: const EdgeInsets.symmetric(horizontal: 12),
                                        decoration: BoxDecoration(
                                          border: const Border(top: BorderSide(color: AppColors.border)),
                                          color: selected?.key == c.key ? AppColors.accent.withValues(alpha: 0.12) : null,
                                        ),
                                        child: Row(children: [
                                          Text((i + 1).toString().padLeft(3, '0'),
                                              style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                                          const SizedBox(width: 10),
                                          ChannelLogo(url: c.logo, size: 34, fallbackIcon: categoryIcon(c.group)),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: Text(c.name,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(fontWeight: FontWeight.w700)),
                                          ),
                                        ]),
                                      ),
                                    ),
                                    Expanded(
                                      child: Container(
                                        padding: const EdgeInsets.all(5),
                                        decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppColors.border))),
                                        child: InkWell(
                                          onTap: () => setState(() => _selected = c),
                                          borderRadius: BorderRadius.circular(8),
                                          child: Container(
                                            alignment: Alignment.centerLeft,
                                            padding: const EdgeInsets.symmetric(horizontal: 14),
                                            decoration: BoxDecoration(
                                              color: AppColors.surfaceHigh.withValues(alpha: 0.7),
                                              borderRadius: BorderRadius.circular(8),
                                              border: Border.all(
                                                  color: selected?.key == c.key ? AppColors.accent : Colors.transparent, width: 1.5),
                                            ),
                                            child: const Text('Programme non disponible — guide EPG à l’étape suivante',
                                                style: TextStyle(color: AppColors.textSecondary)),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ]);
                                },
                              ),
                            ),
                          ]),
                          // Ligne « maintenant ».
                          if (_day == 0)
                            Positioned(
                              left: _channelCol + nowX - 1,
                              top: 10,
                              bottom: 0,
                              child: Column(children: [
                                Transform.translate(
                                  offset: const Offset(-28, 0),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                                    decoration:
                                        BoxDecoration(color: AppColors.accent, borderRadius: BorderRadius.circular(12)),
                                    child: Text(_hhmm(now),
                                        style: const TextStyle(fontWeight: FontWeight.w800, color: Colors.black)),
                                  ),
                                ),
                                Expanded(child: Container(width: 2, color: AppColors.accent)),
                              ]),
                            ),
                        ]),
                      ),
                    ),
            ),
          ),
          if (selected != null) ...[
            const SizedBox(height: 16),
            _DetailCard(channel: selected),
          ],
        ]),
      ),
    ]);
  }
}

class _DetailCard extends ConsumerWidget {
  const _DetailCard({required this.channel});
  final Channel channel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(children: [
        Container(
          width: 150,
          height: 84,
          decoration: BoxDecoration(gradient: tileGradient(channel.name), borderRadius: BorderRadius.circular(10)),
          alignment: Alignment.center,
          child: ChannelLogo(url: channel.logo, size: 56, boxed: false, fallbackIcon: categoryIcon(channel.group)),
        ),
        const SizedBox(width: 20),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(channel.name, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
            const SizedBox(height: 4),
            Text(channel.group.isEmpty ? 'Chaîne en direct' : channel.group,
                style: const TextStyle(color: AppColors.textSecondary)),
          ]),
        ),
        FilledButton.icon(
          onPressed: () {
            ref.read(currentChannelProvider.notifier).play(channel);
            context.push('/player');
          },
          icon: const Icon(Icons.play_arrow_rounded),
          label: const Text('Regarder', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
        ),
      ]),
    );
  }
}

class _DayChip extends StatelessWidget {
  const _DayChip({required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
        decoration: BoxDecoration(
          color: const Color(0xCC111114),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: selected ? AppColors.accent : AppColors.border, width: selected ? 2 : 1),
          boxShadow: selected ? AppColors.glow(0.3) : null,
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (selected) ...[const Icon(Icons.calendar_today_rounded, size: 18), const SizedBox(width: 8)],
          Text(label, style: TextStyle(fontWeight: selected ? FontWeight.w700 : FontWeight.w500, fontSize: 15)),
        ]),
      ),
    );
  }
}

class _RoundBtn extends StatelessWidget {
  const _RoundBtn({required this.icon, this.onTap});
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: const Color(0xCC111114),
          border: Border.all(color: AppColors.border),
        ),
        child: Icon(icon, color: onTap == null ? AppColors.textSecondary : Colors.white),
      ),
    );
  }
}
