import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/favorites/favorites_page.dart';
import '../../features/guide/guide_page.dart';
import '../../features/history/history_page.dart';
import '../../features/home/home_page.dart';
import '../../features/live/live_page.dart';
import '../../features/movies/movies_page.dart';
import '../../features/player/player_page.dart';
import '../../features/series/series_page.dart';
import '../../features/settings/settings_page.dart';
import '../../features/shell/app_shell.dart';

/// Une entrée du menu latéral.
class NavDestination {
  const NavDestination(this.path, this.label, this.icon, this.builder);
  final String path;
  final String label;
  final IconData icon;
  final WidgetBuilder builder;
}

final destinations = <NavDestination>[
  NavDestination('/', 'Accueil', Icons.home_rounded, (_) => const HomePage()),
  NavDestination('/live', 'TV en direct', Icons.live_tv_rounded, (_) => const LivePage()),
  NavDestination('/guide', 'Guide TV', Icons.calendar_view_week_rounded, (_) => const GuidePage()),
  NavDestination('/movies', 'Films', Icons.movie_rounded, (_) => const MoviesPage()),
  NavDestination('/series', 'Séries', Icons.video_library_rounded, (_) => const SeriesPage()),
  NavDestination('/favorites', 'Favoris', Icons.favorite_rounded, (_) => const FavoritesPage()),
  NavDestination('/history', 'Historique', Icons.history_rounded, (_) => const HistoryPage()),
  NavDestination('/settings', 'Réglages', Icons.settings_rounded, (_) => const SettingsPage()),
];

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(path: '/player', builder: (context, state) => const PlayerPage()),
      ShellRoute(
        builder: (context, state, child) =>
            AppShell(location: state.uri.path, child: child),
        routes: [
          for (final d in destinations)
            GoRoute(
              path: d.path,
              pageBuilder: (context, state) => NoTransitionPage(child: d.builder(context)),
            ),
        ],
      ),
    ],
  );
});
