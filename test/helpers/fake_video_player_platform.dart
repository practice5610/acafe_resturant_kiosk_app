import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

/// A video_player backend with no native player: every created player reports
/// [videoSize] as soon as it is asked for events, and counts creates/disposes so
/// a test can prove a controller is made once and released once.
class FakeVideoPlayerPlatform extends VideoPlayerPlatform {
  FakeVideoPlayerPlatform({this.videoSize = const Size(576, 1024)});

  final Size videoSize;
  int created = 0;
  int disposed = 0;
  final List<String> assets = [];
  final Map<int, StreamController<VideoEvent>> _events = {};

  @override
  Future<void> init() async {}

  @override
  Future<int?> create(DataSource dataSource) async {
    assets.add(dataSource.asset ?? '');
    return created++;
  }

  @override
  Future<int?> createWithOptions(VideoCreationOptions options) =>
      create(options.dataSource);

  @override
  Stream<VideoEvent> videoEventsFor(int playerId) {
    final StreamController<VideoEvent> c =
        _events.putIfAbsent(playerId, () => StreamController<VideoEvent>());
    scheduleMicrotask(() => c.add(VideoEvent(
          eventType: VideoEventType.initialized,
          duration: const Duration(seconds: 6),
          size: videoSize,
        )));
    return c.stream;
  }

  @override
  Future<void> dispose(int playerId) async {
    disposed++;
    await _events.remove(playerId)?.close();
  }

  @override
  Future<void> setLooping(int playerId, bool looping) async {}
  @override
  Future<void> play(int playerId) async {}
  @override
  Future<void> pause(int playerId) async {}
  @override
  Future<void> setVolume(int playerId, double volume) async {}
  @override
  Future<void> seekTo(int playerId, Duration position) async {}
  @override
  Future<void> setPlaybackSpeed(int playerId, double speed) async {}
  @override
  Future<Duration> getPosition(int playerId) async => Duration.zero;
  @override
  Widget buildView(int playerId) => const SizedBox.expand();
  @override
  Future<void> setMixWithOthers(bool mixWithOthers) async {}
}
