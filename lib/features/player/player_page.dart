import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:media_kit_video/media_kit_video.dart' show defaultEnterNativeFullscreen, defaultExitNativeFullscreen;

import '../../core/theme/app_theme.dart';
import '../../state/sources_state.dart';
import 'playback.dart';

/// Lecteur plein écran.
/// Clavier / télécommande : Échap ou Retour = quitter, Haut/Bas = chaîne
/// précédente/suivante, Espace/OK = pause.
/// Plein écran Windows réel (désactivé dans les tests).
final nativeFullscreenProvider = Provider<bool>((ref) => true);

class PlayerPage extends ConsumerStatefulWidget {
  const PlayerPage({super.key});

  @override
  ConsumerState<PlayerPage> createState() => _PlayerPageState();
}

class _PlayerPageState extends ConsumerState<PlayerPage> {
  bool _overlay = true;
  bool _diag = false;
  Timer? _hide;
  late final bool _native = ref.read(nativeFullscreenProvider);

  @override
  void initState() {
    super.initState();
    if (_native) defaultEnterNativeFullscreen();
    _bump();
  }

  @override
  void dispose() {
    _hide?.cancel();
    if (_native) defaultExitNativeFullscreen();
    super.dispose();
  }

  void _bump() {
    _hide?.cancel();
    if (!_overlay) setState(() => _overlay = true);
    _hide = Timer(const Duration(seconds: 4), () {
      if (mounted) setState(() => _overlay = false);
    });
  }

  void _zap(int delta) {
    final list = ref.read(visibleChannelsProvider);
    final current = ref.read(currentChannelProvider);
    if (list.isEmpty || current == null) return;
    final i = list.indexWhere((c) => c.key == current.key);
    final next = list[((i < 0 ? 0 : i) + delta) % list.length];
    ref.read(currentChannelProvider.notifier).play(next);
    _bump();
  }

  void _close() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/live');
    }
  }

  @override
  Widget build(BuildContext context) {
    final playback = ref.watch(playbackProvider);
    final channel = ref.watch(currentChannelProvider);
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): _close,
        const SingleActivator(LogicalKeyboardKey.goBack): _close,
        const SingleActivator(LogicalKeyboardKey.arrowUp): () => _zap(-1),
        const SingleActivator(LogicalKeyboardKey.arrowDown): () => _zap(1),
        const SingleActivator(LogicalKeyboardKey.channelUp): () => _zap(-1),
        const SingleActivator(LogicalKeyboardKey.channelDown): () => _zap(1),
        const SingleActivator(LogicalKeyboardKey.keyI): () => setState(() => _diag = !_diag),
        const SingleActivator(LogicalKeyboardKey.space): () {
          playback.togglePause();
          _bump();
        },
        const SingleActivator(LogicalKeyboardKey.select): () {
          playback.togglePause();
          _bump();
        },
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
          backgroundColor: Colors.black,
          body: MouseRegion(
            onHover: (_) => _bump(),
            child: Stack(
              fit: StackFit.expand,
              children: [
                GestureDetector(
                  onTap: _bump,
                  onDoubleTap: _close,
                  child: playback.view(),
                ),
                AnimatedOpacity(
                  opacity: _overlay ? 1 : 0,
                  duration: const Duration(milliseconds: 250),
                  child: IgnorePointer(
                    ignoring: !_overlay,
                    child: _Overlay(
                      title: channel?.name ?? '',
                      group: channel?.group ?? '',
                      onClose: _close,
                      onZap: _zap,
                      onInfo: () => setState(() => _diag = !_diag),
                    ),
                  ),
                ),
                const _PlaybackStatus(),
                if (_diag) Positioned(top: 100, right: 32, child: DiagnosticsPanel(playback: playback)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Overlay extends StatelessWidget {
  const _Overlay({required this.title, required this.group, required this.onClose, required this.onZap, required this.onInfo});
  final String title;
  final String group;
  final VoidCallback onClose;
  final void Function(int) onZap;
  final VoidCallback onInfo;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xCC000000), Colors.transparent, Colors.transparent, Color(0xCC000000)],
          stops: [0, 0.25, 0.7, 1],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              IconButton.filledTonal(onPressed: onClose, icon: const Icon(Icons.arrow_back_rounded), tooltip: 'Retour (Échap)'),
              const SizedBox(width: 16),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(title, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800), overflow: TextOverflow.ellipsis),
                  if (group.isNotEmpty) Text(group, style: const TextStyle(color: AppColors.textSecondary)),
                ]),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: Colors.red.shade600, borderRadius: BorderRadius.circular(6)),
                child: const Text('EN DIRECT', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
              ),
            ]),
            const Spacer(),
            Row(children: [
              IconButton.filledTonal(onPressed: () => onZap(-1), icon: const Icon(Icons.keyboard_arrow_up_rounded), tooltip: 'Chaîne précédente'),
              const SizedBox(width: 8),
              IconButton.filledTonal(onPressed: () => onZap(1), icon: const Icon(Icons.keyboard_arrow_down_rounded), tooltip: 'Chaîne suivante'),
              const SizedBox(width: 16),
              const Expanded(
                child: Text('↑ ↓ changer de chaîne · Espace pause · I infos techniques · Échap quitter',
                    style: TextStyle(color: AppColors.textSecondary)),
              ),
              IconButton.filledTonal(onPressed: onInfo, icon: const Icon(Icons.info_outline_rounded), tooltip: 'Infos techniques (I)'),
            ]),
          ],
        ),
      ),
    );
  }
}

/// Indicateur de chargement et message d'erreur de lecture.
class _PlaybackStatus extends ConsumerWidget {
  const _PlaybackStatus();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PlaybackStatus(playback: ref.watch(playbackProvider), channelKey: ref.watch(currentChannelProvider)?.key);
  }
}

class PlaybackStatus extends StatefulWidget {
  const PlaybackStatus({super.key, required this.playback, this.channelKey});
  final Playback playback;
  final String? channelKey;

  @override
  State<PlaybackStatus> createState() => _PlaybackStatusState();
}

class _PlaybackStatusState extends State<PlaybackStatus> {
  StreamSubscription<String>? _err;
  StreamSubscription<bool>? _buf;
  String? _error;
  bool _buffering = false;

  @override
  void initState() {
    super.initState();
    _err = widget.playback.errors.listen((e) => mounted ? setState(() => _error = e) : null);
    _buf = widget.playback.buffering.listen((b) => mounted ? setState(() => _buffering = b) : null);
  }

  @override
  void didUpdateWidget(PlaybackStatus old) {
    super.didUpdateWidget(old);
    if (old.channelKey != widget.channelKey) _error = null;
  }

  @override
  void dispose() {
    _err?.cancel();
    _buf?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Center(
        child: Container(
          padding: const EdgeInsets.all(20),
          margin: const EdgeInsets.all(20),
          decoration: BoxDecoration(color: const Color(0xDD000000), borderRadius: BorderRadius.circular(14)),
          child: const Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.error_outline_rounded, color: AppColors.accent, size: 36),
            SizedBox(height: 10),
            Text('Cette chaîne ne peut pas être lue pour le moment.', textAlign: TextAlign.center),
            Text('Le flux est peut-être hors ligne ou indisponible.',
                textAlign: TextAlign.center, style: TextStyle(color: AppColors.textSecondary)),
          ]),
        ),
      );
    }
    if (_buffering) {
      return const Center(child: CircularProgressIndicator(color: AppColors.accent));
    }
    return const SizedBox.shrink();
  }
}

/// Panneau « Infos techniques » : aide à comprendre pourquoi une chaîne ne s'affiche pas.
class DiagnosticsPanel extends StatefulWidget {
  const DiagnosticsPanel({super.key, required this.playback});
  final Playback playback;

  @override
  State<DiagnosticsPanel> createState() => _DiagnosticsPanelState();
}

class _DiagnosticsPanelState extends State<DiagnosticsPanel> {
  Map<String, String> _data = const {};
  Timer? _t;

  @override
  void initState() {
    super.initState();
    _refresh();
    _t = Timer.periodic(const Duration(seconds: 1), (_) => _refresh());
  }

  Future<void> _refresh() async {
    final d = await widget.playback.diagnostics();
    if (mounted) setState(() => _data = d);
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 440,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xE6000000),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: SelectionArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Infos techniques', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
            const SizedBox(height: 10),
            for (final e in _data.entries)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  SizedBox(width: 140, child: Text(e.key, style: const TextStyle(color: AppColors.textSecondary))),
                  Expanded(child: Text(e.value)),
                ]),
              ),
          ],
        ),
      ),
    );
  }
}
