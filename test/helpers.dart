import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:zelvora_tv/state/epg_state.dart';
import 'package:zelvora_tv/app.dart';
import 'package:zelvora_tv/data/source_repository.dart';
import 'package:zelvora_tv/domain/channel.dart';
import 'package:zelvora_tv/features/player/playback.dart';
import 'package:zelvora_tv/features/player/player_page.dart';
import 'package:zelvora_tv/state/sources_state.dart';

/// Lecteur factice : enregistre les chaînes demandées.
class FakePlayback implements Playback {
  final played = <Channel>[];
  int pauses = 0;
  final _err = StreamController<String>.broadcast();
  final _buf = StreamController<bool>.broadcast();

  @override
  Future<void> play(Channel channel) async => played.add(channel);
  @override
  Future<void> togglePause() async => pauses++;
  double _vol = 100;
  final _volCtl = StreamController<double>.broadcast();
  @override
  Future<void> setVolume(double v) async {
    _vol = v;
    _volCtl.add(v);
  }

  @override
  double get volume => _vol;
  @override
  Stream<double> get volumeStream => _volCtl.stream;
  @override
  Future<void> stop() async {}
  @override
  Widget view({bool controls = false}) => const ColoredBox(color: Colors.black, child: SizedBox.expand());
  @override
  Stream<String> get errors => _err.stream;
  @override
  Stream<bool> get buffering => _buf.stream;
  @override
  Future<Map<String, String>> diagnostics() async => {'État': 'Lecture', 'Codec vidéo': 'h264'};
  @override
  void dispose() {}
}

const samplePlaylist = '''#EXTM3U
#EXTINF:-1 tvg-id="demo1" tvg-logo="" group-title="Démo",Chaîne Démo 1
https://example.com/live/1.m3u8
#EXTINF:-1 tvg-id="demo2" group-title="Démo",Chaîne Démo 2
https://example.com/live/2.m3u8
#EXTINF:-1 group-title="Info",Info Test
https://example.com/live/3.ts
''';

http.Client fakeHttp([String body = samplePlaylist]) => MockClient((req) async {
      if (req.url.host == 'example.com' && req.url.path == '/playlist.m3u') {
        return http.Response.bytes(utf8.encode(body), 200);
      }
      return http.Response('not found', 404);
    });

Future<FakePlayback> pumpApp(WidgetTester tester, {MemorySecureStore? store, http.Client? client}) async {
  tester.view.physicalSize = const Size(1600, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final playback = FakePlayback();
  final st = store ?? MemorySecureStore();
  final http0 = client ?? fakeHttp();
  await tester.pumpWidget(ProviderScope(
    overrides: [
      secureStoreProvider.overrideWithValue(st),
      sourceRepositoryProvider.overrideWithValue(
          SourceRepository(store: st, client: http0)),
      epgLoaderProvider.overrideWithValue((url, from, to) => downloadXmltv(url, from, to, client: http0)),
      playbackProvider.overrideWithValue(playback),
      nativeFullscreenProvider.overrideWithValue(false),
    ],
    child: const ZelvoraApp(),
  ));
  await tester.pumpAndSettle();
  return playback;
}
