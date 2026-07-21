import 'dart:collection';
import 'dart:math';

/// A grid coordinate. Uses [Point] for free value-equality (works in sets/maps).
typedef Cell = Point<int>;

/// Cells that a detected line covers, plus the points it is worth.
class ClearResult {
  final int points;
  final List<Cell> cells;
  const ClearResult(this.points, this.cells);

  bool get isEmpty => cells.isEmpty;
}

/// A full copy of a board's mutable state, used to undo a move.
class BoardSnapshot {
  final List<int> cells;
  final int score;
  final bool isGameOver;
  final int plannedCount;
  final List<int> nextColors;
  final List<Cell> nextCells;
  const BoardSnapshot(this.cells, this.score, this.isGameOver, this.plannedCount,
      this.nextColors, this.nextCells);
}

/// Pure rules of the classic "Lines" game: grid, BFS pathfinding, line detection
/// and scoring. No Flutter, no rendering — the UI drives it and animates the result.
///
/// Ported from the Unity `Board.cs`, with the score base tuned so a 5-in-a-row is
/// worth 10 in both modes (see [detectLines]).
class Board {
  static const int colorCount = 7;
  static const int spawnCount = 3;

  /// Grid width/height in cells (9 or 10).
  final int size;

  /// Same-colored balls in a row needed to clear (4 = easy, 5 = normal).
  final int minLine;

  final List<int> _cells;
  final Random _rng;

  /// Colors of the balls that will drop next (the NEXT preview).
  final List<int> nextColors = List<int>.filled(spawnCount, 0);

  /// Cells the next balls are reserved to land on, shown as hint dots.
  final List<Cell> nextCells = List<Cell>.filled(spawnCount, const Point(0, 0));

  /// How many entries of [nextColors]/[nextCells] are currently valid.
  int plannedCount = 0;

  int score = 0;
  bool isGameOver = false;

  Board({this.size = 9, this.minLine = 5, Random? rng})
      : _cells = List<int>.filled(size * size, 0),
        _rng = rng ?? Random();

  int get(int x, int y) => _cells[y * size + x];
  int getC(Cell c) => _cells[c.y * size + c.x];
  void _set(Cell c, int color) => _cells[c.y * size + c.x] = color;

  bool inBounds(int x, int y) => x >= 0 && x < size && y >= 0 && y < size;
  bool isEmpty(Cell c) => getC(c) == 0;

  /// Resets the board and drops two opening batches. Returns the filled cells.
  List<Cell> newGame() {
    for (var i = 0; i < _cells.length; i++) {
      _cells[i] = 0;
    }
    score = 0;
    isGameOver = false;
    plannedCount = 0;

    final spawned = <Cell>[];
    _planNext();
    spawned.addAll(spawn());
    spawned.addAll(spawn());
    return spawned;
  }

  List<Cell> _freeCells() {
    final free = <Cell>[];
    for (var y = 0; y < size; y++) {
      for (var x = 0; x < size; x++) {
        if (_cells[y * size + x] == 0) free.add(Point(x, y));
      }
    }
    return free;
  }

  /// Reserves cells and colors for the next drop so the player can plan around them.
  void _planNext() {
    final free = _freeCells();
    plannedCount = min(spawnCount, free.length);
    for (var i = 0; i < plannedCount; i++) {
      final pick = _rng.nextInt(free.length);
      nextCells[i] = free[pick];
      free.removeAt(pick);
      nextColors[i] = 1 + _rng.nextInt(colorCount);
    }
  }

  /// Drops the previewed balls onto their reserved cells (falling back to a random
  /// free cell if one was taken), then plans the next batch. Returns the filled
  /// cells and sets [isGameOver] when the board fills up.
  List<Cell> spawn() {
    final spawned = <Cell>[];
    for (var i = 0; i < spawnCount; i++) {
      final free = _freeCells();
      if (free.isEmpty) {
        isGameOver = true;
        break;
      }
      final color = i < plannedCount ? nextColors[i] : 1 + _rng.nextInt(colorCount);
      final cell = (i < plannedCount && getC(nextCells[i]) == 0)
          ? nextCells[i]
          : free[_rng.nextInt(free.length)];
      _set(cell, color);
      spawned.add(cell);
    }
    _planNext();
    if (_freeCells().isEmpty) isGameOver = true;
    return spawned;
  }

  static const _dx = [1, -1, 0, 0];
  static const _dy = [0, 0, 1, -1];

  /// Shortest path between two cells through empty cells only (4-directional).
  /// Returns null when unreachable. Includes both endpoints.
  List<Cell>? findPath(Cell from, Cell to) {
    if (from == to || getC(from) == 0 || getC(to) != 0) return null;

    final cameFrom = List<int>.filled(size * size, -1);
    final fromIdx = from.y * size + from.x;
    final toIdx = to.y * size + to.x;
    cameFrom[fromIdx] = fromIdx;

    final queue = Queue<Cell>()..add(from);
    while (queue.isNotEmpty) {
      final cur = queue.removeFirst();
      final curIdx = cur.y * size + cur.x;
      if (curIdx == toIdx) return _buildPath(cameFrom, fromIdx, toIdx);

      for (var d = 0; d < 4; d++) {
        final nx = cur.x + _dx[d];
        final ny = cur.y + _dy[d];
        if (!inBounds(nx, ny)) continue;
        final nIdx = ny * size + nx;
        if (cameFrom[nIdx] != -1 || _cells[nIdx] != 0) continue;
        cameFrom[nIdx] = curIdx;
        queue.add(Point(nx, ny));
      }
    }
    return null;
  }

  List<Cell> _buildPath(List<int> cameFrom, int fromIdx, int toIdx) {
    final path = <Cell>[];
    var cur = toIdx;
    while (cur != fromIdx) {
      path.add(Point(cur % size, cur ~/ size));
      cur = cameFrom[cur];
    }
    path.add(Point(fromIdx % size, fromIdx ~/ size));
    return path.reversed.toList();
  }

  void moveBall(Cell from, Cell to) {
    _set(to, getC(from));
    _set(from, 0);
  }

  /// Places a ball directly. Handy for setting up deterministic states in tests.
  void place(Cell c, int color) => _set(c, color);

  /// Captures the full mutable state so a later [restore] can undo a move.
  BoardSnapshot snapshot() => BoardSnapshot(
        List<int>.of(_cells),
        score,
        isGameOver,
        plannedCount,
        List<int>.of(nextColors),
        List<Cell>.of(nextCells),
      );

  /// Rolls the board back to a [snapshot].
  void restore(BoardSnapshot s) {
    for (var i = 0; i < _cells.length; i++) {
      _cells[i] = s.cells[i];
    }
    score = s.score;
    isGameOver = s.isGameOver;
    plannedCount = s.plannedCount;
    for (var i = 0; i < nextColors.length; i++) {
      nextColors[i] = s.nextColors[i];
    }
    for (var i = 0; i < nextCells.length; i++) {
      nextCells[i] = s.nextCells[i];
    }
  }

  // Line directions: right, up, up-right, up-left. A run is only counted from the
  // cell with no same-colored neighbour behind it, so each run is scored once.
  static const _lineDx = [1, 0, 1, -1];
  static const _lineDy = [0, 1, 1, 1];

  /// Finds every run of [minLine]+ same-colored balls. Returns the covered cells
  /// and points, but does NOT modify the board (the UI clears them after animating).
  ///
  /// Points: `8 + (len - 4) * 2`, using an absolute base of 4 in both modes, so a
  /// line is worth the same regardless of mode (5-in-a-row = 10, 6 = 12, ...).
  ClearResult detectLines() {
    final toClear = <Cell>{};
    var gained = 0;

    for (var y = 0; y < size; y++) {
      for (var x = 0; x < size; x++) {
        final color = _cells[y * size + x];
        if (color == 0) continue;

        for (var d = 0; d < 4; d++) {
          final px = x - _lineDx[d];
          final py = y - _lineDy[d];
          if (inBounds(px, py) && get(px, py) == color) continue; // not the run's start

          var len = 0;
          var cx = x;
          var cy = y;
          while (inBounds(cx, cy) && get(cx, cy) == color) {
            len++;
            cx += _lineDx[d];
            cy += _lineDy[d];
          }
          if (len < minLine) continue;

          gained += 8 + (len - 4) * 2;
          cx = x;
          cy = y;
          for (var i = 0; i < len; i++) {
            toClear.add(Point(cx, cy));
            cx += _lineDx[d];
            cy += _lineDy[d];
          }
        }
      }
    }
    return ClearResult(gained, toClear.toList());
  }

  /// Applies a previously [detectLines] result: empties the cells and adds the score.
  void applyClear(ClearResult res) {
    for (final c in res.cells) {
      _set(c, 0);
    }
    score += res.points;
    if (res.cells.isNotEmpty) isGameOver = false; // room was made again
  }
}
