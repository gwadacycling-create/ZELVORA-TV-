import 'package:flutter/material.dart';

import '../../domain/vod.dart';
import '../vod/vod_browser.dart';

class SeriesPage extends StatelessWidget {
  const SeriesPage({super.key});

  @override
  Widget build(BuildContext context) => const VodBrowser(kind: VodKind.series);
}
