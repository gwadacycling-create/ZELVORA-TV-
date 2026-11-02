import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:media_kit_video/media_kit_video.dart' show defaultEnterNativeFullscreen, defaultExitNativeFullscreen;

import '../../core/theme/app_theme.dart';
import '../../domain/channel.dart';
import '../../state/epg_state.dart';
import '../../data/xmltv.dart' show EpgIndex;
import '../../state/library_state.dart';
import '../../state/vod_state.dart';
import '../vod/vod_details.dart' show fmtDuration;
import '../../state/sources_state.dart';
import 'playback.dart';
import 'volume_control.dart';

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
  Timer? _save;

  @override
  void initState() {
    super.initState();
    if (_native) defaultEnterNativeFullscreen();
    _bump();
    _save = Timer.periodic(const Duration(seconds: 10), (_) => _saveProgress());
  }

  /// Films / séries : mémorise la position pour reprendre plus tard.
  void _saveProgress() {
    if (!mounted) return;
    final c = ref.read(currentChannelProvider);
    final cur = ref.read(currentVodProvider);
    if (c == null || !c.vod || cur == null) return;
    final pb = ref.read(playbackProvider);
    if (pb.duration <= Duration.zero || pb.position <= Duration.zero) return;
    final notifier = ref.read(progressProvider.notifier);
    final p = WatchProgress(
      item: cur.item,
      episodeId: cur.episodeId,
      label: cur.label,
      position: pb.position,
      duration: pb.duration,
      at: DateTime.now(),
    );
    // Hors de la construction de l'écran (appelé aussi à la fermeture du lecteur).
    Future.microtask(() => notifier.save(p));
  }

  void _seek(int seconds) {
    final pb = ref.read(playbackProvider);
    var to = pb.position + Duration(seconds: seconds);
    if (to < Duration.zero) to = Duration.zero;
    if (pb.duration > Duration.zero && to > pb.duration) to = pb.duration;
    pb.seek(to);
    _bump();
  }

  @override
  void deactivate() {
    _saveProgress();
    super.deactivate();
  }

  @override
  void dispose() {
    _save?.cancel();
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

  void _volume(Future<void> Function(VolumeActions) f) {
    f(VolumeActions(ref));
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
    final vod = channel?.vod ?? false;
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): _close,
        const SingleActivator(LogicalKeyboardKey.goBack): _close,
        const SingleActivator(LogicalKeyboardKey.arrowUp): () => vod ? _volume((a) => a.step(5)) : _zap(-1),
        const SingleActivator(LogicalKeyboardKey.arrowDown): () => vod ? _volume((a) => a.step(-5)) : _zap(1),
        const SingleActivator(LogicalKeyboardKey.channelUp): () => _zap(-1),
        const SingleActivator(LogicalKeyboardKey.channelDown): () => _zap(1),
        const SingleActivator(LogicalKeyboardKey.keyI): () => setState(() => _diag = !_diag),
        const SingleActivator(LogicalKeyboardKey.keyM): () => _volume((a) => a.toggleMute()),
        const SingleActivator(LogicalKeyboardKey.keyF): () {
          if (channel != null) ref.read(favoritesProvider.notifier).toggle(channel);
          _bump();
        },
        const SingleActivator(LogicalKeyboardKey.audioVolumeMute): () => _volume((a) => a.toggleMute()),
        const SingleActivator(LogicalKeyboardKey.add): () => _volume((a) => a.step(5)),
        const SingleActivator(LogicalKeyboardKey.equal): () => _volume((a) => a.step(5)),
        const SingleActivator(LogicalKeyboardKey.numpadAdd): () => _volume((a) => a.step(5)),
        const SingleActivator(LogicalKeyboardKey.audioVolumeUp): () => _volume((a) => a.step(5)),
        const SingleActivator(LogicalKeyboardKey.arrowRight): () => vod ? _seek(10) : _volume((a) => a.step(5)),
        const SingleActivator(LogicalKeyboardKey.minus): () => _volume((a) => a.step(-5)),
        const SingleActivator(LogicalKeyboardKey.numpadSubtract): () => _volume((a) => a.step(-5)),
        const SingleActivator(LogicalKeyboardKey.audioVolumeDown): () => _volume((a) => a.step(-5)),
        const SingleActivator(LogicalKeyboardKey.arrowLeft): () => vod ? _seek(-10) : _volume((a) => a.step(-5)),
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
          body: Listener(
            onPointerSignal: (e) {
              if (e is PointerScrollEvent) _volume((a) => a.step(e.scrollDelta.dy > 0 ? -5 : 5));
            },
            child: MouseRegion(
              onHover: (_) => _bump(),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  GestureDetector(onTap: _bump, onDoubleTap: _close, child: playback.view()),
                  AnimatedOpacity(
                    opacity: _overlay ? 1 : 0,
                    duration: const Duration(milliseconds: 250),
                    child: IgnorePointer(
                      ignoring: !_overlay,
                      child: _Overlay(
                        channel: channel,
                        playback: playback,
                        onSeek: _seek,
                        title: channel?.name ?? '',
                        group: _subtitle(channel, ref.watch(epgProvider).value),
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
      ),
    );
  }
}

class _Overlay extends StatelessWidget {
  const _Overlay({
    required this.channel,
    required this.playback,
    required this.onSeek,
    required this.title,
    required this.group,
    required this.onClose,
    required this.onZap,
    required this.onInfo,
  });
  final Channel? channel;
  final Playback playback;
  final void Function(int) onSeek;
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
            Row(
              children: [
                IconButton.filledTonal(onPressed: onClose, icon: const Icon(Icons.arrow_back_rounded), tooltip: 'Retour (Échap)'),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (group.isNotEmpty) Text(group, style: const TextStyle(color: AppColors.textSecondary)),
                    ],
                  ),
                ),
                if (channel != null && !channel!.vod) ...[FavoriteButton(channel: channel!, filled: true), const SizedBox(width: 12)],
                if (!(channel?.vod ?? false))
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: Colors.red.shade600, borderRadius: BorderRadius.circular(6)),
                    child: const Text('EN DIRECT', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
                  ),
              ],
            ),
            const Spacer(),
            if (channel?.vod ?? false) ...[SeekBar(playback: playback), const SizedBox(height: 8)],
            Row(
              children: [
                if (channel?.vod ?? false) ...[
                  IconButton.filledTonal(
                    onPressed: () => onSeek(-10),
                    icon: const Icon(Icons.replay_10_rounded),
                    tooltip: 'Reculer de 10 s (←)',
                  ),
                  const SizedBox(width: 8),
                  IconButton.filledTonal(
                    key: const Key('vod-pause'),
                    onPressed: playback.togglePause,
                    icon: const Icon(Icons.pause_rounded),
                    tooltip: 'Lecture / pause (Espace)',
                  ),
                  const SizedBox(width: 8),
                  IconButton.filledTonal(
                    onPressed: () => onSeek(10),
                    icon: const Icon(Icons.forward_10_rounded),
                    tooltip: 'Avancer de 10 s (→)',
                  ),
                ] else ...[
                  IconButton.filledTonal(
                    onPressed: () => onZap(-1),
                    icon: const Icon(Icons.keyboard_arrow_up_rounded),
                    tooltip: 'Chaîne précédente',
                  ),
                  const SizedBox(width: 8),
                  IconButton.filledTonal(
                    onPressed: () => onZap(1),
                    icon: const Icon(Icons.keyboard_arrow_down_rounded),
                    tooltip: 'Chaîne suivante',
                  ),
                ],
                const SizedBox(width: 16),
                const SizedBox(width: 8),
                const VolumeControl(),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    (channel?.vod ?? false)
                        ? '← → avancer/reculer · ↑ ↓ ou molette volume · M muet · Espace pause · Échap quitter'
                        : '↑ ↓ chaîne · ← → ou molette volume · M muet · F favori · Espace pause · I infos · Échap quitter',
                    style: const TextStyle(color: AppColors.textSecondary),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton.filledTonal(
                  key: const Key('tracks-button'),
                  onPressed: () => showTracksDialog(context, playback),
                  icon: const Icon(Icons.subtitles_rounded),
                  tooltip: 'Audio et sous-titres',
                ),
                const SizedBox(width: 8),
                IconButton.filledTonal(onPressed: onInfo, icon: const Icon(Icons.info_outline_rounded), tooltip: 'Infos techniques (I)'),
              ],
            ),
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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded, color: AppColors.accent, size: 36),
              const SizedBox(height: 10),
              const Text('Cette chaîne ne peut pas être lue pour le moment.', textAlign: TextAlign.center),
              Text(
                _error!.startsWith('Le serveur IPTV')
                    ? '${_error!} Relancez la chaîne pour réessayer.'
                    : 'Le flux est peut-être hors ligne ou indisponible.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.textSecondary),
              ),
            ],
          ),
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
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 140,
                      child: Text(e.key, style: const TextStyle(color: AppColors.textSecondary)),
                    ),
                    Expanded(child: Text(e.value)),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Sous-titre du lecteur : émission en cours et suivante si le guide est connu.
String _subtitle(Channel? c, EpgIndex? epg) {
  if (c == null) return '';
  final (now, next) = nowNext(programmesOf(epg, c), DateTime.now());
  if (now == null) return c.group;
  return next == null ? 'En ce moment : ${now.title}' : 'En ce moment : ${now.title}  ·  Ensuite : ${next.title}';
}

/// Barre de progression des films et séries.
class SeekBar extends StatefulWidget {
  const SeekBar({super.key, required this.playback});
  final Playback playback;

  @override
  State<SeekBar> createState() => _SeekBarState();
}

class _SeekBarState extends State<SeekBar> {
  double? _drag;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Duration>(
      stream: widget.playback.positionStream,
      builder: (context, _) {
        final pos = widget.playback.position;
        final dur = widget.playback.duration;
        final max = dur.inMilliseconds <= 0 ? 1.0 : dur.inMilliseconds.toDouble();
        final value = (_drag ?? pos.inMilliseconds.toDouble()).clamp(0.0, max);
        return Row(
          children: [
            Text(
              fmtDuration(Duration(milliseconds: value.round())),
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            Expanded(
              child: Slider(
                key: const Key('vod-seek'),
                value: value,
                max: max,
                activeColor: AppColors.accent,
                onChanged: dur > Duration.zero ? (v) => setState(() => _drag = v) : null,
                onChangeEnd: (v) {
                  widget.playback.seek(Duration(milliseconds: v.round()));
                  setState(() => _drag = null);
                },
              ),
            ),
            Text(dur > Duration.zero ? fmtDuration(dur) : '--:--', style: const TextStyle(color: AppColors.textSecondary)),
          ],
        );
      },
    );
  }
}

/// Choix de la langue audio et des sous-titres.
Future<void> showTracksDialog(BuildContext context, Playback playback) => showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) {
          final audio = playback.audioTracks;
          final subs = playback.subtitleTracks;
          Widget option(String label, bool selected, VoidCallback onTap) => ListTile(
                dense: true,
                leading: Icon(selected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
                    color: selected ? AppColors.accent : AppColors.textSecondary),
                title: Text(label),
                onTap: onTap,
              );
          return AlertDialog(
            title: const Text('Audio et sous-titres'),
            content: SizedBox(
              width: 380,
              child: ListView(shrinkWrap: true, children: [
                const Text('Langue audio', style: TextStyle(fontWeight: FontWeight.w700)),
                if (audio.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Text('Une seule piste audio.', style: TextStyle(color: AppColors.textSecondary)),
                  ),
                for (final t in audio)
                  option(t.label, playback.currentAudio == t.id, () async {
                    await playback.selectAudio(t.id);
                    setState(() {});
                  }),
                const SizedBox(height: 12),
                const Text('Sous-titres', style: TextStyle(fontWeight: FontWeight.w700)),
                option('Désactivés', playback.currentSubtitle == null || playback.currentSubtitle == 'no', () async {
                  await playback.selectSubtitle('no');
                  setState(() {});
                }),
                for (final t in subs)
                  option(t.label, playback.currentSubtitle == t.id, () async {
                    await playback.selectSubtitle(t.id);
                    setState(() {});
                  }),
              ]),
            ),
            actions: [TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Fermer'))],
          );
        },
      ),
    );
