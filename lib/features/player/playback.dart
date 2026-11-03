import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../../core/freeze_monitor.dart';
import '../../data/source_repository.dart' show kIptvUserAgent;
import '../../domain/channel.dart';
import '../../state/library_state.dart';
import 'reconnect.dart';

/// Lecture vidéo, isolée derrière une interface pour pouvoir être remplacée
/// (tests, autre moteur) sans toucher aux écrans.
abstract class Playback {
  Future<void> play(Channel channel, {Duration? start});
  Future<void> togglePause();

  /// Pistes audio et sous-titres proposées par le flux.
  List<TrackOption> get audioTracks;
  List<TrackOption> get subtitleTracks;
  String? get currentAudio;
  String? get currentSubtitle;
  Future<void> selectAudio(String id);

  /// 'no' désactive les sous-titres.
  Future<void> selectSubtitle(String id);

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

class TrackOption {
  const TrackOption(this.id, this.label);
  final String id;
  final String label;
}

String _trackLabel(String id, String? title, String? lang, int n) {
  final parts = [
    if (lang != null && lang.isNotEmpty) _langName(lang),
    if (title != null && title.isNotEmpty && title != lang) title,
  ];
  return parts.isEmpty ? 'Piste $n' : parts.join(' · ');
}

String _langName(String code) => switch (code.toLowerCase()) {
      'fr' || 'fre' || 'fra' => 'Français',
      'en' || 'eng' => 'Anglais',
      'es' || 'spa' => 'Espagnol',
      'de' || 'ger' || 'deu' => 'Allemand',
      'it' || 'ita' => 'Italien',
      'pt' || 'por' => 'Portugais',
      'ar' || 'ara' => 'Arabe',
      'tr' || 'tur' => 'Turc',
      'nl' || 'dut' || 'nld' => 'Néerlandais',
      _ => code,
    };

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
  String? _lavf;
  DateTime _openedAt = DateTime.now();
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
    // Démarrage plus rapide des chaînes : le moteur analyse 1 s de flux au
    // lieu de 5 s (sur un direct, cette analyse se faisait au rythme réel).
    await _set('demuxer-lavf-analyzeduration', '1');
    // Langue préférée : français, sinon anglais.
    await _set('alang', 'fr,fre,fra,en,eng');
    await _set('slang', 'fr,fre,fra');
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
        if (!_policy.started) {
          _journal('lecture démarrée en ${(DateTime.now().difference(_openedAt).inMilliseconds / 1000).toStringAsFixed(1)} s');
        }
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
    final lavf = isHls(channel.url) || channel.vod
        ? 'reconnect=1,reconnect_streamed=1,reconnect_on_network_error=1,reconnect_delay_max=4'
        : 'reconnect=1,reconnect_streamed=1,reconnect_at_eof=1,reconnect_on_network_error=1,reconnect_delay_max=4';
    // Ce réglage est appliqué directement (sans file d'attente) : s'il est envoyé
    // pendant que le moteur ferme encore la chaîne précédente, tout l'écran
    // reste bloqué plusieurs secondes. On ne l'envoie donc que s'il change,
    // et seulement une fois l'ancienne chaîne arrêtée.
    if (lavf != _lavf) {
      await _player.stop();
      await _set('stream-lavf-o', lavf);
      _lavf = lavf;
    }
    _openedAt = DateTime.now();
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
    FreezeMonitor.instance.context = 'ouverture de « ${channel.name} »';
    _journal('ouverture de « ${channel.name} » (${isHls(channel.url) ? 'HLS' : 'flux continu'}, ${maskUrls(channel.url)})');
    return _open(channel, start: start);
  }

  @override
  List<TrackOption> get audioTracks {
    var n = 0;
    return [
      for (final t in _player.state.tracks.audio)
        if (t.id != 'auto' && t.id != 'no') TrackOption(t.id, _trackLabel(t.id, t.title, t.language, ++n)),
    ];
  }

  @override
  List<TrackOption> get subtitleTracks {
    var n = 0;
    return [
      for (final t in _player.state.tracks.subtitle)
        if (t.id != 'auto' && t.id != 'no') TrackOption(t.id, _trackLabel(t.id, t.title, t.language, ++n)),
    ];
  }

  @override
  String? get currentAudio => _player.state.track.audio.id;

  @override
  String? get currentSubtitle => _player.state.track.subtitle.id;

  @override
  Future<void> selectAudio(String id) async {
    final t = _player.state.tracks.audio.where((e) => e.id == id).firstOrNull;
    if (t != null) await _player.setAudioTrack(t);
  }

  @override
  Future<void> selectSubtitle(String id) async {
    if (id == 'no') return _player.setSubtitleTrack(SubtitleTrack.no());
    final t = _player.state.tracks.subtitle.where((e) => e.id == id).firstOrNull;
    if (t != null) await _player.setSubtitleTrack(t);
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
      'Blocages écran': FreezeMonitor.instance.events.isEmpty ? 'aucun' : FreezeMonitor.instance.events.reversed.take(5).join('\n'),
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
