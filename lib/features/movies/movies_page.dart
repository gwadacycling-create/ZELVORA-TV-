import 'package:flutter/material.dart';

import '../../domain/vod.dart';
import '../vod/vod_browser.dart';

class MoviesPage extends StatelessWidget {
  const MoviesPage({super.key});

  @override
  Widget build(BuildContext context) => const VodBrowser(kind: VodKind.movie);
}
