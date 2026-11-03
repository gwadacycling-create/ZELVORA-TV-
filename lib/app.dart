import 'dart:async';
import 'dart:io' show Platform;
import 'dart:ui' show AppExitResponse;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'features/player/playback.dart';
import 'state/sources_state.dart';

class ZelvoraApp extends ConsumerStatefulWidget {
  const ZelvoraApp({super.key});

  @override
  ConsumerState<ZelvoraApp> createState() => _ZelvoraAppState();
}

class _ZelvoraAppState extends ConsumerState<ZelvoraApp> with WidgetsBindingObserver {
  Timer? _timer;
  DateTime _lastRefresh = DateTime.now();
  late final AppLifecycleListener _exit;

  @override
  void initState() {
    super.initState();
    // Fermeture de la fenêtre (ordinateur) : on coupe la vidéo et le son avant de quitter.
    _exit = AppLifecycleListener(onExitRequested: () async {
      try {
        await ref.read(playbackProvider).stop().timeout(const Duration(seconds: 1));
      } catch (_) {}
      return AppExitResponse.exit;
    });
    WidgetsBinding.instance.addObserver(this);
    _schedule(kAutoRefreshEvery);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _exit.dispose();
    _timer?.cancel();
    super.dispose();
  }

  void _schedule(Duration d) {
    _timer?.cancel();
    _timer = Timer(d, _autoRefresh);
  }

  /// Actualise les playlists en arrière-plan. Pendant la lecture d'une vidéo,
  /// on attend un peu pour ne pas gêner le flux.
  void _autoRefresh() {
    final path = ref.read(appRouterProvider).routerDelegate.currentConfiguration.uri.path;
    if (path == '/player') {
      _schedule(const Duration(minutes: 10));
      return;
    }
    _lastRefresh = DateTime.now();
    _schedule(kAutoRefreshEvery);
    ref.read(silentRefreshProvider)();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Application quittée (ou mise en arrière-plan sur Android / Android TV) :
    // on coupe la vidéo pour que le son ne continue pas.
    if (state == AppLifecycleState.detached || (state == AppLifecycleState.paused && Platform.isAndroid)) {
      ref.read(currentChannelProvider.notifier).stop();
    }
    // Box TV ou téléphone restés en veille longtemps : on rattrape au réveil.
    if (state == AppLifecycleState.resumed && DateTime.now().difference(_lastRefresh) >= kAutoRefreshEvery) {
      _autoRefresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(appRouterProvider);
    return MaterialApp.router(
      title: 'ZELVORA TV',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark(),
      routerConfig: router,
      // Navigation au clavier et à la télécommande (flèches + OK/Entrée).
      shortcuts: {
        ...WidgetsApp.defaultShortcuts,
        const SingleActivator(LogicalKeyboardKey.select): const ActivateIntent(),
        const SingleActivator(LogicalKeyboardKey.numpadEnter): const ActivateIntent(),
        const SingleActivator(LogicalKeyboardKey.gameButtonA): const ActivateIntent(),
      },
    );
  }
}
