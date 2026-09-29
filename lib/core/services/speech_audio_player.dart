import 'dart:async';
import 'package:audioplayers/audioplayers.dart';

/// Serializes native start/stop while allowing cancellation during playback.
class SpeechAudioPlayer {
  AudioPlayer? _player;
  StreamSubscription<void>? _completion;
  Future<void> _commands = Future.value();
  Completer<void>? _finished;
  int _generation = 0;
  bool _disposed = false;
  void _finish() {
    final pending = _finished;
    _finished = null;
    if (pending != null && !pending.isCompleted) pending.complete();
  }

  Future<bool> play(
    Source source, {
    double speed = 1,
    Duration timeout = const Duration(seconds: 60),
  }) async {
    if (_disposed) return false;
    final token = ++_generation;
    _finish();
    final finished = Completer<void>();
    var started = false;
    try {
      _commands = _commands.catchError((_) {}).then((_) async {
        if (_disposed || token != _generation) return;
        final player = _player ??= AudioPlayer();
        _completion ??= player.onPlayerComplete.listen((_) => _finish());
        await player.stop();
        if (_disposed || token != _generation) return;
        await player.setPlaybackRate(speed.clamp(.65, 1.4));
        if (_disposed || token != _generation) return;
        _finished = finished;
        started = true;
        await player.play(source);
      });
      await _commands;
      if (!started || token != _generation) return true;
      await finished.future.timeout(timeout);
      return true;
    } catch (_) {
      if (token == _generation) await stop();
      return false;
    }
  }

  Future<void> stop() async {
    ++_generation;
    _finish();
    _commands = _commands.catchError((_) {}).then((_) async {
      try {
        await _player?.stop();
      } catch (_) {
        /* Already closed. */
      }
    });
    await _commands;
  }

  void dispose() {
    _disposed = true;
    unawaited(
      stop().then((_) async {
        await _completion?.cancel();
        await _player?.dispose();
      }),
    );
  }
}
