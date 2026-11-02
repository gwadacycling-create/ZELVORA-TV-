import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// Guide TV : maquette de la grille (chaînes x créneaux horaires).
class GuidePage extends StatelessWidget {
  const GuidePage({super.key});

  static const _slotWidth = 220.0;
  static const _rowHeight = 64.0;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day, now.hour, now.minute >= 30 ? 30 : 0);
    final slots = List.generate(8, (i) => start.add(Duration(minutes: 30 * i)));
    String fmt(DateTime t) => '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

    return Padding(
      padding: const EdgeInsets.fromLTRB(40, 36, 40, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Guide TV', style: TextStyle(fontSize: 32, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          const Text('Le programme apparaîtra ici une fois une source avec guide TV (EPG) ajoutée.',
              style: TextStyle(color: AppColors.textSecondary)),
          const SizedBox(height: 24),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              clipBehavior: Clip.antiAlias,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        const SizedBox(width: 180, height: 44),
                        for (final s in slots)
                          SizedBox(
                            width: _slotWidth,
                            height: 44,
                            child: Padding(
                              padding: const EdgeInsets.only(left: 12, top: 12),
                              child: Text(fmt(s),
                                  style: const TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
                            ),
                          ),
                      ]),
                      for (var r = 0; r < 6; r++)
                        Row(children: [
                          Container(
                            width: 180,
                            height: _rowHeight,
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            alignment: Alignment.centerLeft,
                            decoration: const BoxDecoration(
                              border: Border(top: BorderSide(color: AppColors.border), right: BorderSide(color: AppColors.border)),
                            ),
                            child: Container(width: 90, height: 12, decoration: BoxDecoration(color: AppColors.surfaceHigh, borderRadius: BorderRadius.circular(6))),
                          ),
                          for (var c = 0; c < slots.length; c++)
                            Container(
                              width: _slotWidth,
                              height: _rowHeight,
                              padding: const EdgeInsets.all(6),
                              decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppColors.border))),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: c == 0 ? AppColors.accent.withValues(alpha: 0.10) : AppColors.surfaceHigh,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                            ),
                        ]),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
