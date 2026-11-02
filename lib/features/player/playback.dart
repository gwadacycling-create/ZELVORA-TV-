import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../../data/source_repository.dart' show kIptvUserAgent;
import '../../domain/channel.dart';
import '../../state/library_state.dart';
import 'reconnect.dart';

/// Lecture vidéo, isolée derrière une interface pour pouvoir être remplacée
/// (tests, autre moteur) sans toucher aux écrans.
abstract class Playback {
  Future<void> play(Channel channel, {Duration? start});
  Future<void> togglePause();

  /// Position et durée (films et séries).
  Duration get position;
  Duration get duration;
  Stream<Duration> get positionStream;
  Future<void> seek(Duration to);

  /// Volume de 0 à 100.
  Future<void> setVolume(double volume);
  double get volume;
  Stream<double> get volumeStream;
  Future<void> stop();
  Widget view({bool controls = false});
  Stream<String> get errors;
  Stream<bool> get buffering;

  /// Informations techniques pour le diagnostic (état, codecs, résolution...).
  Future<Map<String, String>> diagnostics();
  void dispose();
}

/// Mode compatibilité vidéo : désactive l'accélération matérielle
/// (utile si l'image reste noire sur certaines cartes graphiques).
final videoCompatModeProvider = Provider<bool>((ref) => false);
const kVideoCompatKey = 'zelvora.video.compat';

/// Volume mémorisé entre deux ouvertures de l'application.
final initialVolumeProvider = Provider<double>((ref) => 100);
const kVolumeKey = 'zelvora.volume';

class MediaKitPlayback implements Playback {
  MediaKitPlayback({bool compatMode = false}) : _compat = compatMode {
    _controller = VideoController(
      _player,
      configuration: VideoControllerConfiguration(
        enableHardwareAcceleration: !compatMode,
        hwdec: compatMode ? 'no' : 'auto-safe',
      ),
    );
    _ready = _configure();
    _player.stream.log.listen((l) => _lastLog = maskUrls('[${l.level}] ${l.prefix}: ${l.text}'.trim()));
    _player.stream.position.listen(_onPosition);
    _player.stream.buffering.listen(_buf.add);
    _player.stream.completed.listen((done) {
      if (done && !(_current?.vod ?? false)) _recover('fin du flux envoyée par le serveur');
    });
    _player.stream.error.listen((e) {
      _journal('erreur moteur : ${maskUrls(e)}');
      if (!_policy.started) _recover('erreur à l\'ouverture');
    });
    _watchdog = Timer.periodic(const Duration(seconds: 2), (_) => _check());
  }

  final bool _compat;
  final Player _player = Player(
    configuration: const PlayerConfiguration(title: 'ZELVORA TV', logLevel: MPVLogLevel.warn),
  );
  late final VideoController _controller;
  late final Future<void> _ready;
  late final Timer _watchdog;
  final _err = StreamController<String>.broadcast();
  final _buf = StreamController<bool>.broadcast();
  final _policy = ReconnectPolicy();
  final _log = <String>[];
  String _lastLog = '';

  Channel? _current;
  int _session = 0;
  bool _userPaused = false;
  bool _reconnecting = false;
  bool _failed = false;
  Duration _lastPos = Duration.zero;
  DateTime _lastProgress = DateTime.now();

  /// Image figée depuis plus de ce délai → reconnexion.
  static const stallLimit = Duration(seconds: 10);

  /// Délai laissé au premier démarrage d'une chaîne.
  static const startLimit = Duration(seconds: 20);

  Future<void> _set(String name, String value) async {
    final p = _player.platform;
    if (p is NativePlayer) {
      try {
        await p.setProperty(name, value);
      } catch (_) {}
    }
  }

  /// Réglages réseau et tampon adaptés au direct (valeurs mpv).
  Future<void> _configure() async {
    await _set('network-timeout', '15');
    await _set('cache', 'yes');
    await _set('demuxer-max-bytes', '64MiB');
    await _set('demuxer-max-back-bytes', '16MiB');
    await _set('demuxer-readahead-secs', '20');
    await _set('hls-bitrate', 'max');
  }

  void _journal(String msg) {
    final t = DateTime.now();
    String two(int v) => v.toString().padLeft(2, '0');
    _log.add('${two(t.hour)}:${two(t.minute)}:${two(t.second)} $msg');
    if (_log.length > 30) _log.removeAt(0);
    debugPrint('[ZELVORA lecteur] $msg');
  }

  void _onPosition(Duration p) {
    final advancing = p > _lastPos && p > Duration.zero;
    _lastPos = p;
    if (advancing) {
      _lastProgress = DateTime.now();
      if (_current != null && !_reconnecting) {
        if (!_policy.started) _journal('lecture démarrée');
        _policy.onProgress(_lastProgress);
      }
    }
  }

  void _check() {
    if (_current == null || _userPaused || _reconnecting || _failed || _player.state.completed) return;
    final limit = _policy.started ? stallLimit : startLimit;
    if (DateTime.now().difference(_lastProgress) > limit) {
      _recover(_policy.started ? 'image figée depuis ${limit.inSeconds} s' : 'aucune image après ${limit.inSeconds} s');
    }
  }

  Future<void> _recover(String reason) async {
    final channel = _current;
    if (channel == null || _reconnecting || _failed || _userPaused) return;
    final delay = _policy.nextDelay();
    if (delay == null) {
      _failed = true;
      _journal('abandon après ${_policy.total} reconnexion(s) : $reason');
      _buf.add(false);
      _err.add(_policy.started
          ? 'Le serveur IPTV ne répond plus. La chaîne a été coupée plusieurs fois de suite.'
          : 'Le serveur IPTV ne répond pas pour cette chaîne.');
      return;
    }
    _reconnecting = true;
    final session = _session;
    _journal('$reason → reconnexion ${_policy.attempts} dans ${delay.inSeconds} s');
    _buf.add(true);
    await Future<void>.delayed(delay);
    if (session != _session) return;
    await _open(channel, start: channel.vod && _lastPos > Duration.zero ? _lastPos : null);
    _lastProgress = DateTime.now();
    _reconnecting = false;
  }

  Future<void> _open(Channel channel, {Duration? start}) async {
    await _ready;
    // Flux continus (.ts) : le moteur rouvre lui-même la connexion si le
    // serveur la coupe. Désactivé pour le HLS, qui gère ses segments.
    await _set(
      'stream-lavf-o',
      isHls(channel.url) || channel.vod
          ? 'reconnect=1,reconnect_streamed=1,reconnect_on_network_error=1,reconnect_delay_max=4'
          : 'reconnect=1,reconnect_streamed=1,reconnect_at_eof=1,reconnect_on_network_error=1,reconnect_delay_max=4',
    );
    await _player.open(Media(channel.url, httpHeaders: {'User-Agent': kIptvUserAgent, ...channel.headers}, start: start));
  }

  @override
  Future<void> play(Channel channel, {Duration? start}) {
    _session++;
    _current = channel;
    _policy.reset();
    _userPaused = false;
    _reconnecting = false;
    _failed = false;
    _lastProgress = DateTime.now();
    _journal('ouverture de « ${channel.name} » (${isHls(channel.url) ? 'HLS' : 'flux continu'}, ${maskUrls(channel.url)})');
    return _open(channel, start: start);
  }

  @override
  Duration get position => _player.state.position;

  @override
  Duration get duration => _player.state.duration;

  @override
  Stream<Duration> get positionStream => _player.stream.position;

  @override
  Future<void> seek(Duration to) {
    _lastProgress = DateTime.now();
    return _player.seek(to);
  }

  @override
  Future<void> togglePause() async {
    final wasPlaying = _player.state.playing;
    await _player.playOrPause();
    _userPaused = wasPlaying;
    if (!wasPlaying) _lastProgress = DateTime.now();
  }

  @override
  Future<void> setVolume(double volume) => _player.setVolume(volume.clamp(0, 100).toDouble());

  @override
  double get volume => _player.state.volume;

  @override
  Stream<double> get volumeStream => _player.stream.volume;

  @override
  Future<void> stop() {
    _session++;
    _current = null;
    _reconnecting = false;
    return _player.stop();
  }

  @override
  Stream<String> get errors => _err.stream;

  @override
  Stream<bool> get buffering => _buf.stream;

  @override
  Future<Map<String, String>> diagnostics() async {
    final st = _player.state;
    Future<String> prop(String name) async {
      try {
        final p = _player.platform;
        if (p is NativePlayer) {
          final v = await p.getProperty(name);
          return v.isEmpty ? '—' : v;
        }
      } catch (_) {}
      return '—';
    }

    final cache = await prop('demuxer-cache-duration');
    final secs = double.tryParse(cache);
    return {
      'État': _failed
          ? 'Arrêté : serveur injoignable'
          : _reconnecting
              ? 'Reconnexion en cours…'
              : st.playing
                  ? (st.buffering ? 'Chargement…' : 'Lecture')
                  : 'Arrêté / en attente',
      'Image': st.width != null && st.width! > 0 ? '${st.width} × ${st.height}' : 'aucune image reçue',
      'Codec vidéo': await prop('video-codec'),
      'Codec audio': await prop('audio-codec-name'),
      'Décodage matériel': _compat ? 'désactivé (mode compatibilité)' : await prop('hwdec-current'),
      'Sortie vidéo': await prop('current-vo'),
      'Format': await prop('file-format'),
      'Mémoire tampon': secs == null ? '—' : '${secs.toStringAsFixed(1)} s',
      'Images perdues': await prop('frame-drop-count'),
      'Reconnexions': '${_policy.total}',
      'Dernier message': _lastLog.isEmpty ? '—' : _lastLog,
      'Journal': _log.isEmpty ? '—' : _log.reversed.take(6).join('\n'),
    };
  }

  @override
  Widget view({bool controls = false}) => Video(
        controller: _controller,
        controls: controls ? MaterialDesktopVideoControls : NoVideoControls,
        fill: Colors.black,
      );

  @override
  void dispose() {
    _session++;
    _current = null;
    _watchdog.cancel();
    _player.dispose();
    _err.close();
    _buf.close();
  }
}

final playbackProvider = Provider<Playback>((ref) {
  final p = MediaKitPlayback(compatMode: ref.read(videoCompatModeProvider));
  p.setVolume(ref.read(initialVolumeProvider));
  ref.onDispose(p.dispose);
  return p;
});

/// Chaîne en cours de lecture.
final currentChannelProvider = NotifierProvider<CurrentChannelNotifier, Channel?>(CurrentChannelNotifier.new);

class CurrentChannelNotifier extends Notifier<Channel?> {
  @override
  Channel? build() => null;

  Future<void> play(Channel c, {Duration? start}) async {
    state = c;
    if (!c.vod) ref.read(historyProvider.notifier).add(c);
    await ref.read(playbackProvider).play(c, start: start);
  }

  Future<void> stop() async {
    state = null;
    await ref.read(playbackProvider).stop();
  }
}
