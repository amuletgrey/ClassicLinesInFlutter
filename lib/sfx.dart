import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

/// Short sound effects for the game. Sounds are bundled WAVs (see assets/sounds),
/// each held by its own low-latency player so rapid replays don't cut each other off.
class Sfx {
  static const _names = ['select', 'move', 'clear', 'gameover'];

  final Map<String, AudioPlayer> _players = {};
  bool muted = false;
  bool _ready = false;

  Future<void> init({bool muted = false}) async {
    this.muted = muted;
    try {
      for (final name in _names) {
        final p = AudioPlayer(playerId: 'sfx_$name');
        await p.setReleaseMode(ReleaseMode.stop);
        await p.setPlayerMode(PlayerMode.lowLatency);
        await p.setSource(AssetSource('sounds/$name.wav'));
        _players[name] = p;
      }
      _ready = true;
    } catch (e) {
      // Audio is non-essential; never let it break the game.
      debugPrint('Sfx init failed: $e');
    }
  }

  void _play(String name) {
    if (muted || !_ready) return;
    final p = _players[name];
    if (p == null) return;
    // Fire and forget; restart from the top for a crisp retrigger.
    p.stop().then((_) => p.resume()).catchError((_) {});
  }

  void select() => _play('select');
  void move() => _play('move');
  void clear() => _play('clear');
  void gameOver() => _play('gameover');

  Future<void> dispose() async {
    for (final p in _players.values) {
      await p.dispose();
    }
    _players.clear();
  }
}
