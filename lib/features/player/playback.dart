import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../../data/source_repository.dart' show kIptvUserAgent;
import '../../domain/channel.dart';

/// Lecture vidéo, isolée derrière une interface pour pouvoir être remplacée
/// (tests, autre moteur) sans toucher aux écrans.
abstract class Playback {
  Future<void> play(Channel channel);
  Future<void> togglePause();

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
    _player.stream.log.listen((l) => _lastLog = '[${l.level}] ${l.prefix}: ${l.text}'.trim());
  }

  final bool _compat;
  final Player _player = Player(
    configuration: const PlayerConfiguration(title: 'ZELVORA TV', logLevel: MPVLogLevel.warn),
  );
  late final VideoController _controller;
  String _lastLog = '';

  @override
  Future<void> play(Channel channel) =>
      _player.open(Media(channel.url, httpHeaders: {'User-Agent': kIptvUserAgent, ...channel.headers}));

  @override
  Future<void> togglePause() => _player.playOrPause();

  @override
  Future<void> setVolume(double volume) => _player.setVolume(volume.clamp(0, 100).toDouble());

  @override
  double get volume => _player.state.volume;

  @override
  Stream<double> get volumeStream => _player.stream.volume;

  @override
  Future<void> stop() => _player.stop();

  @override
  Stream<String> get errors => _player.stream.error;

  @override
  Stream<bool> get buffering => _player.stream.buffering;

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

    return {
      'État': st.playing ? (st.buffering ? 'Chargement…' : 'Lecture') : 'Arrêté / en attente',
      'Image': st.width != null && st.width! > 0 ? '${st.width} × ${st.height}' : 'aucune image reçue',
      'Codec vidéo': await prop('video-codec'),
      'Codec audio': await prop('audio-codec-name'),
      'Décodage matériel': _compat ? 'désactivé (mode compatibilité)' : await prop('hwdec-current'),
      'Sortie vidéo': await prop('current-vo'),
      'Format': await prop('file-format'),
      'Dernier message': _lastLog.isEmpty ? '—' : _lastLog,
    };
  }

  @override
  Widget view({bool controls = false}) => Video(
        controller: _controller,
        controls: controls ? MaterialDesktopVideoControls : NoVideoControls,
        fill: Colors.black,
      );

  @override
  void dispose() => _player.dispose();
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

  Future<void> play(Channel c) async {
    state = c;
    await ref.read(playbackProvider).play(c);
  }

  Future<void> stop() async {
    state = null;
    await ref.read(playbackProvider).stop();
  }
}
