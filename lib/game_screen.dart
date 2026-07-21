import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'ball.dart';
import 'board.dart';
import 'palette.dart';
import 'sfx.dart';

/// A ball sliding along a BFS path, drawn as an overlay while it animates.
class _MovingBall {
  final int color;
  final List<Cell> path;
  const _MovingBall(this.color, this.path);
  Cell get from => path.first;
}

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> with TickerProviderStateMixin {
  // ---- Config (the four combinations each keep their own high score) ----
  int _minLine = 5; // 4 = Easy, 5 = Normal
  int _boardSize = 9; // 9 or 10

  late Board _board;
  SharedPreferences? _prefs;
  int _best = 0;

  // ---- Interaction / animation state ----
  Cell? _selected;
  bool _busy = false;
  _MovingBall? _moving;
  Cell? _blockedCell; // flashes when a move has no path
  Set<Cell> _fxCells = <Cell>{}; // cells currently popping in / out
  String _fxMode = 'spawn'; // 'spawn' or 'clear'

  int? _scorePopup; // the floating "+X" over the score
  BoardSnapshot? _undo; // state to roll back to; single-use per move

  final Sfx _sfx = Sfx();
  bool _muted = false;
  bool _gameOverAnnounced = false; // so the game-over sound only plays once

  late final AnimationController _moveCtrl;
  late final AnimationController _fxCtrl;
  late final AnimationController _pulseCtrl;
  late final AnimationController _popupCtrl;

  @override
  void initState() {
    super.initState();
    _moveCtrl = AnimationController(vsync: this);
    _fxCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 220));
    _pulseCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _popupCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))
      ..addStatusListener((s) {
        if (s == AnimationStatus.completed && mounted) setState(() => _scorePopup = null);
      });

    _board = Board(size: _boardSize, minLine: _minLine);
    final spawned = _board.newGame();
    // Mark them as popping in from scale 0 so the very first frame doesn't flash
    // them at full size before the animation starts.
    _fxMode = 'spawn';
    _fxCells = spawned.toSet();

    SharedPreferences.getInstance().then((p) {
      if (!mounted) return;
      setState(() {
        _prefs = p;
        _best = p.getInt(_bestKey) ?? 0;
        _muted = p.getBool('muted') ?? false;
      });
      _sfx.init(muted: _muted);
    });

    // Pop the opening balls in once the first frame is laid out.
    WidgetsBinding.instance.addPostFrameCallback((_) => _playSpawn(spawned));
  }

  @override
  void dispose() {
    _moveCtrl.dispose();
    _fxCtrl.dispose();
    _pulseCtrl.dispose();
    _popupCtrl.dispose();
    _sfx.dispose();
    super.dispose();
  }

  void _toggleMute() {
    setState(() => _muted = !_muted);
    _sfx.muted = _muted;
    _prefs?.setBool('muted', _muted);
  }

  String get _bestKey => 'hi_${_minLine == 4 ? 'easy' : 'normal'}_$_boardSize';

  void _maybeSaveBest() {
    if (_board.score > _best) {
      _best = _board.score;
      _prefs?.setInt(_bestKey, _best);
    }
  }

  // ---------------------------------------------------------------- new game
  Future<void> _newGame({int? minLine, int? boardSize}) async {
    _moveCtrl.stop();
    _fxCtrl.stop();
    _pulseCtrl.stop();
    setState(() {
      if (minLine != null) _minLine = minLine;
      if (boardSize != null) _boardSize = boardSize;
      _board = Board(size: _boardSize, minLine: _minLine);
      _selected = null;
      _moving = null;
      _blockedCell = null;
      _fxCells = <Cell>{};
      _undo = null;
      _scorePopup = null;
      _gameOverAnnounced = false;
      _busy = true;
      _best = _prefs?.getInt(_bestKey) ?? 0;
    });
    final spawned = _board.newGame();
    await _playSpawn(spawned);
    if (mounted) setState(() => _busy = false);
  }

  /// Rolls back the last move (and everything it triggered). Single-use: after an
  /// undo the button is disabled until the next move creates a fresh snapshot.
  void _undoMove() {
    if (_busy || _undo == null) return;
    HapticFeedback.selectionClick();
    _pulseCtrl.stop();
    _board.restore(_undo!);
    setState(() {
      _undo = null;
      _selected = null;
      _moving = null;
      _blockedCell = null;
      _fxCells = <Cell>{};
      _scorePopup = null;
      _gameOverAnnounced = false;
    });
  }

  // ------------------------------------------------------------------- input
  void _onCellTap(Cell c) {
    if (_busy || _board.isGameOver) return;
    final ball = _board.getC(c);

    if (_selected == null) {
      if (ball != 0) _select(c);
      return;
    }
    if (c == _selected) {
      _deselect();
      return;
    }
    if (ball != 0) {
      _select(c); // switch selection to another ball
      return;
    }

    final path = _board.findPath(_selected!, c);
    if (path == null) {
      _flashBlocked(c);
      return;
    }
    _handleMove(_selected!, c, path);
  }

  void _select(Cell c) {
    HapticFeedback.selectionClick();
    _sfx.select();
    setState(() => _selected = c);
    _pulseCtrl.repeat(reverse: true);
  }

  void _deselect() {
    setState(() => _selected = null);
    _pulseCtrl.stop();
  }

  void _flashBlocked(Cell c) {
    HapticFeedback.lightImpact();
    setState(() => _blockedCell = c);
    Future.delayed(const Duration(milliseconds: 260), () {
      if (mounted && _blockedCell == c) setState(() => _blockedCell = null);
    });
  }

  // -------------------------------------------------------------- move / turn
  Future<void> _handleMove(Cell from, Cell to, List<Cell> path) async {
    _pulseCtrl.stop();
    _sfx.move();
    final color = _board.getC(from);
    final snapshot = _board.snapshot(); // state to return to on undo
    setState(() {
      _busy = true;
      _selected = null;
      _blockedCell = null;
      _undo = snapshot;
      _moving = _MovingBall(color, path);
    });

    _moveCtrl.duration = Duration(milliseconds: (path.length * 45).clamp(150, 520));
    await _moveCtrl.forward(from: 0);

    _board.moveBall(from, to);
    setState(() => _moving = null);

    // A move that clears scores and grants a free turn; otherwise 3 balls drop.
    var res = _board.detectLines();
    if (!res.isEmpty) {
      await _playClear(res);
    } else {
      final spawned = _board.spawn();
      if (spawned.isNotEmpty) await _playSpawn(spawned);
      res = _board.detectLines(); // a fresh drop can complete a line too
      if (!res.isEmpty) await _playClear(res);
    }

    if (mounted) setState(() => _busy = false);

    if (_board.isGameOver && !_gameOverAnnounced) {
      _gameOverAnnounced = true;
      _sfx.gameOver();
    }
  }

  Future<void> _playSpawn(List<Cell> cells) async {
    if (cells.isEmpty) return;
    setState(() {
      _fxMode = 'spawn';
      _fxCells = cells.toSet();
    });
    await _fxCtrl.forward(from: 0);
    if (mounted) setState(() => _fxCells = <Cell>{});
  }

  Future<void> _playClear(ClearResult res) async {
    HapticFeedback.mediumImpact();
    _sfx.clear();
    setState(() {
      _fxMode = 'clear';
      _fxCells = res.cells.toSet();
    });
    await _fxCtrl.forward(from: 0);
    _board.applyClear(res);
    if (mounted) {
      setState(() {
        _fxCells = <Cell>{};
        _scorePopup = res.points;
        _maybeSaveBest();
      });
      _popupCtrl.forward(from: 0);
    }
  }

  // ------------------------------------------------------------------- render
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Palette.background,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _header(),
                  const SizedBox(height: 14),
                  Expanded(child: Center(child: _boardPanel())),
                  const SizedBox(height: 14),
                  _controls(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _header() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _scoreColumn(),
        const SizedBox(width: 20),
        _stat('BEST', '$_best'),
        const Spacer(),
        _nextPreview(),
      ],
    );
  }

  /// The SCORE readout with a floating "+X" that rises and fades on each clear.
  Widget _scoreColumn() {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        _stat('SCORE', '${_board.score}', big: true),
        if (_scorePopup != null)
          Positioned(
            left: 2,
            top: 0,
            child: AnimatedBuilder(
              animation: _popupCtrl,
              builder: (context, child) {
                final v = _popupCtrl.value;
                return Opacity(
                  opacity: (1 - v).clamp(0.0, 1.0),
                  child: Transform.translate(
                    offset: Offset(0, -26 * Curves.easeOut.transform(v)),
                    child: child,
                  ),
                );
              },
              child: Text('+$_scorePopup',
                  style: const TextStyle(
                      color: Palette.gain, fontSize: 18, fontWeight: FontWeight.w800)),
            ),
          ),
      ],
    );
  }

  Widget _stat(String label, String value, {bool big = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                color: Palette.textDim, fontSize: 11, letterSpacing: 1.5, fontWeight: FontWeight.w600)),
        const SizedBox(height: 2),
        Text(value,
            style: TextStyle(
                color: Palette.text, fontSize: big ? 30 : 20, fontWeight: FontWeight.w700, height: 1)),
      ],
    );
  }

  Widget _nextPreview() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        const Text('NEXT',
            style: TextStyle(
                color: Palette.textDim, fontSize: 11, letterSpacing: 1.5, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < _board.plannedCount; i++)
              Padding(
                padding: const EdgeInsets.only(left: 6),
                child: Ball(color: Palette.ballColors[_board.nextColors[i]], diameter: 20),
              ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _iconButton(
              icon: Icons.undo_rounded,
              tooltip: 'Undo',
              enabled: !_busy && _undo != null,
              onTap: _undoMove,
            ),
            const SizedBox(width: 8),
            _iconButton(
              icon: _muted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
              tooltip: _muted ? 'Unmute' : 'Mute',
              color: _muted ? Palette.textDim : Palette.text,
              onTap: _toggleMute,
            ),
          ],
        ),
      ],
    );
  }

  Widget _iconButton({
    required IconData icon,
    required VoidCallback onTap,
    String? tooltip,
    bool enabled = true,
    Color? color,
  }) {
    final c = enabled ? (color ?? Palette.text) : Palette.textDim.withValues(alpha: 0.45);
    final button = SizedBox(
      width: 42,
      height: 34,
      child: Material(
        color: Palette.boardPanel,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: enabled ? onTap : null,
          child: Center(child: Icon(icon, size: 19, color: c)),
        ),
      ),
    );
    return tooltip == null ? button : Tooltip(message: tooltip, child: button);
  }

  Widget _controls() {
    return Row(
      children: [
        SizedBox(
          width: 116,
          child: _actionButton(label: 'New game', filled: true, height: 76, onTap: () => _newGame()),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            children: [
              _segmented(
                value: _minLine,
                options: const [MapEntry('Easy', 4), MapEntry('Normal', 5)],
                onChanged: (v) => _newGame(minLine: v),
              ),
              const SizedBox(height: 8),
              _segmented(
                value: _boardSize,
                options: const [MapEntry('9×9', 9), MapEntry('10×10', 10)],
                onChanged: (v) => _newGame(boardSize: v),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _actionButton({
    required String label,
    required bool filled,
    required VoidCallback onTap,
    IconData? icon,
    bool enabled = true,
    double height = 34,
  }) {
    final fg = !enabled
        ? Palette.textDim
        : filled
            ? Colors.white
            : Palette.text;
    return SizedBox(
      height: height,
      width: double.infinity,
      child: Material(
        color: enabled && filled ? Palette.accent : Palette.boardPanel,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: enabled ? onTap : null,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 16, color: fg),
                const SizedBox(width: 5),
              ],
              Text(label,
                  style: TextStyle(color: fg, fontSize: 14, fontWeight: FontWeight.w700)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _segmented({
    required int value,
    required List<MapEntry<String, int>> options,
    required ValueChanged<int> onChanged,
  }) {
    return Container(
      height: 34,
      decoration: BoxDecoration(
        color: Palette.boardPanel,
        borderRadius: BorderRadius.circular(10),
      ),
      padding: const EdgeInsets.all(3),
      child: Row(
        children: [
          for (final opt in options)
            Expanded(
              child: GestureDetector(
                onTap: () {
                  if (opt.value != value) onChanged(opt.value);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: opt.value == value ? Palette.accent : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    opt.key,
                    style: TextStyle(
                      color: opt.value == value ? Colors.white : Palette.textDim,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _boardPanel() {
    return AspectRatio(
      aspectRatio: 1,
      child: Container(
        decoration: BoxDecoration(
          color: Palette.boardPanel,
          borderRadius: BorderRadius.circular(16),
        ),
        padding: const EdgeInsets.all(8),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final boardPixel = min(constraints.maxWidth, constraints.maxHeight);
            final cell = boardPixel / _board.size;
            return AnimatedBuilder(
              animation: Listenable.merge([_moveCtrl, _fxCtrl, _pulseCtrl]),
              builder: (context, _) => SizedBox(
                width: boardPixel,
                height: boardPixel,
                child: Stack(children: _boardChildren(cell)),
              ),
            );
          },
        ),
      ),
    );
  }

  List<Widget> _boardChildren(double cell) {
    final n = _board.size;
    final children = <Widget>[];

    // 1. Cell backgrounds.
    for (var y = 0; y < n; y++) {
      for (var x = 0; x < n; x++) {
        final c = Point(x, y);
        final isSel = _selected == c;
        final isBlocked = _blockedCell == c;
        children.add(Positioned(
          left: x * cell,
          top: y * cell,
          width: cell,
          height: cell,
          child: Padding(
            padding: EdgeInsets.all(cell * 0.06),
            child: Container(
              decoration: BoxDecoration(
                color: isBlocked
                    ? Palette.danger.withValues(alpha: 0.35)
                    : (isSel ? Palette.cellHighlight : Palette.cell),
                borderRadius: BorderRadius.circular(cell * 0.16),
              ),
            ),
          ),
        ));
      }
    }

    // 2. Hint dots where the next balls are reserved to land.
    for (var i = 0; i < _board.plannedCount; i++) {
      final c = _board.nextCells[i];
      if (_board.getC(c) != 0) continue;
      children.add(Positioned(
        left: c.x * cell,
        top: c.y * cell,
        width: cell,
        height: cell,
        child: Center(
          child: Opacity(
            opacity: 0.55,
            child: Ball(color: Palette.ballColors[_board.nextColors[i]], diameter: cell * 0.24),
          ),
        ),
      ));
    }

    // 3. Settled balls (skip the one currently sliding).
    final ballSize = cell * 0.78;
    for (var y = 0; y < n; y++) {
      for (var x = 0; x < n; x++) {
        final c = Point(x, y);
        final color = _board.get(x, y);
        if (color == 0) continue;
        if (_moving != null && c == _moving!.from) continue;

        var scale = 1.0;
        if (_fxCells.contains(c)) {
          scale = _fxMode == 'spawn'
              ? Curves.easeOutBack.transform(_fxCtrl.value)
              : (1 - Curves.easeIn.transform(_fxCtrl.value));
        }
        if (_selected == c) scale *= 1 + 0.12 * _pulseCtrl.value;

        children.add(Positioned(
          left: x * cell,
          top: y * cell,
          width: cell,
          height: cell,
          child: Center(
            child: Transform.scale(
              scale: scale,
              child: Ball(color: Palette.ballColors[color], diameter: ballSize),
            ),
          ),
        ));
      }
    }

    // 4. The sliding ball overlay.
    if (_moving != null) {
      final path = _moving!.path;
      final seg = _moveCtrl.value * (path.length - 1);
      final i = seg.floor().clamp(0, path.length - 1);
      final frac = seg - i;
      final a = path[i];
      final b = path[min(i + 1, path.length - 1)];
      final px = (a.x + (b.x - a.x) * frac) * cell;
      final py = (a.y + (b.y - a.y) * frac) * cell;
      children.add(Positioned(
        left: px,
        top: py,
        width: cell,
        height: cell,
        child: Center(
          child: Ball(color: Palette.ballColors[_moving!.color], diameter: ballSize),
        ),
      ));
    }

    // 5. Tap targets (transparent, on top so every cell is reachable).
    for (var y = 0; y < n; y++) {
      for (var x = 0; x < n; x++) {
        final c = Point(x, y);
        children.add(Positioned(
          left: x * cell,
          top: y * cell,
          width: cell,
          height: cell,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => _onCellTap(c),
          ),
        ));
      }
    }

    // 6. Game-over veil.
    if (_board.isGameOver && !_busy) {
      children.add(Positioned.fill(child: _gameOver()));
    }

    return children;
  }

  Widget _gameOver() {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Palette.background.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Game over',
                style: TextStyle(color: Palette.text, fontSize: 26, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text('Score ${_board.score}   •   Best $_best',
                style: const TextStyle(color: Palette.textDim, fontSize: 15)),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: () => _newGame(),
              style: FilledButton.styleFrom(
                backgroundColor: Palette.accent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('New game', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );
  }
}
