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
  Future<void> stop();
  Widget view({bool controls = false});
  Stream<String> get errors;
  Stream<bool> get buffering;
  void dispose();
}

class MediaKitPlayback implements Playback {
  MediaKitPlayback() {
    _controller = VideoController(_player);
  }

  final Player _player = Player(configuration: const PlayerConfiguration(title: 'ZELVORA TV'));
  late final VideoController _controller;

  @override
  Future<void> play(Channel channel) =>
      _player.open(Media(channel.url, httpHeaders: {'User-Agent': kIptvUserAgent, ...channel.headers}));

  @override
  Future<void> togglePause() => _player.playOrPause();

  @override
  Future<void> stop() => _player.stop();

  @override
  Stream<String> get errors => _player.stream.error;

  @override
  Stream<bool> get buffering => _player.stream.buffering;

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
  final p = MediaKitPlayback();
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
