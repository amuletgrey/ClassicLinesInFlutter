import 'dart:convert';
import 'dart:math';

import 'package:classic_lines/board.dart';
import 'package:flutter_test/flutter_test.dart';

/// Fills a board directly for deterministic rule checks.
extension _Setup on Board {
  void seed(List<List<int>> rows) {
    for (var y = 0; y < size; y++) {
      for (var x = 0; x < size; x++) {
        final v = rows[y][x];
        if (v != 0) place(Point(x, y), v);
      }
    }
  }
}

void main() {
  group('scoring — 8 + (len - 4) * 2', () {
    test('4-in-a-row scores 8 (easy base)', () {
      final b = Board(size: 9, minLine: 4);
      for (var x = 0; x < 4; x++) {
        b.place(Point(x, 0), 1);
      }
      final res = b.detectLines();
      expect(res.cells.length, 4);
      expect(res.points, 8);
    });

    test('5-in-a-row scores 10 in both modes', () {
      for (final minLine in [4, 5]) {
        final b = Board(size: 9, minLine: minLine);
        for (var x = 0; x < 5; x++) {
          b.place(Point(x, 0), 2);
        }
        expect(b.detectLines().points, 10, reason: 'minLine=$minLine');
      }
    });

    test('6-in-a-row scores 12', () {
      final b = Board(size: 9, minLine: 5);
      for (var x = 0; x < 6; x++) {
        b.place(Point(x, 0), 3);
      }
      expect(b.detectLines().points, 12);
    });
  });

  group('line detection', () {
    test('normal mode ignores a run of 4', () {
      final b = Board(size: 9, minLine: 5);
      for (var x = 0; x < 4; x++) {
        b.place(Point(x, 0), 1);
      }
      expect(b.detectLines().isEmpty, isTrue);
    });

    test('detects a diagonal run', () {
      final b = Board(size: 9, minLine: 5);
      for (var i = 0; i < 5; i++) {
        b.place(Point(i, i), 4);
      }
      expect(b.detectLines().cells.length, 5);
    });

    test('different colors do not combine', () {
      final b = Board(size: 9, minLine: 4);
      b.seed([
        [1, 1, 2, 2, 0, 0, 0, 0, 0],
        ...List.generate(8, (_) => List.filled(9, 0)),
      ]);
      expect(b.detectLines().isEmpty, isTrue);
    });
  });

  group('pathfinding', () {
    test('reaches an open cell', () {
      final b = Board(size: 9, minLine: 5);
      b.place(const Point(0, 0), 1);
      final path = b.findPath(const Point(0, 0), const Point(5, 5));
      expect(path, isNotNull);
      expect(path!.first, const Point(0, 0));
      expect(path.last, const Point(5, 5));
    });

    test('returns null when walled off', () {
      final b = Board(size: 3, minLine: 5);
      // Trap the ball at (0,0): block (1,0) and (0,1).
      b.place(const Point(0, 0), 1);
      b.place(const Point(1, 0), 2);
      b.place(const Point(0, 1), 2);
      expect(b.findPath(const Point(0, 0), const Point(2, 2)), isNull);
    });

    test('cannot move onto an occupied cell', () {
      final b = Board(size: 9, minLine: 5);
      b.place(const Point(0, 0), 1);
      b.place(const Point(1, 0), 2);
      expect(b.findPath(const Point(0, 0), const Point(1, 0)), isNull);
    });
  });

  test('snapshot/restore rolls back a move and its score (undo)', () {
    final b = Board(size: 9, minLine: 4);
    b.place(const Point(0, 0), 1);
    final before = b.snapshot();

    // Simulate a move that clears a line and scores.
    b.moveBall(const Point(0, 0), const Point(1, 1));
    for (var x = 0; x < 4; x++) {
      b.place(Point(x, 3), 2);
    }
    b.applyClear(b.detectLines());
    expect(b.score, greaterThan(0));

    b.restore(before);
    expect(b.score, 0);
    expect(b.get(0, 0), 1);
    expect(b.get(1, 1), 0);
    expect(b.get(0, 3), 0);
  });

  test('applyClear empties cells and adds score', () {
    final b = Board(size: 9, minLine: 4);
    for (var x = 0; x < 4; x++) {
      b.place(Point(x, 0), 1);
    }
    final res = b.detectLines();
    b.applyClear(res);
    expect(b.score, 8);
    for (var x = 0; x < 4; x++) {
      expect(b.get(x, 0), 0);
    }
  });

  test('toJson/fromJson round-trips the full game (resume)', () {
    final b = Board(size: 10, minLine: 4);
    b.newGame();
    b.place(const Point(2, 3), 5);
    b.place(const Point(7, 8), 6);

    final restored = Board.fromJson(
        jsonDecode(jsonEncode(b.toJson())) as Map<String, dynamic>);

    expect(restored.size, 10);
    expect(restored.minLine, 4);
    expect(restored.score, b.score);
    expect(restored.isGameOver, b.isGameOver);
    expect(restored.plannedCount, b.plannedCount);
    expect(restored.get(2, 3), 5);
    expect(restored.get(7, 8), 6);
    for (var y = 0; y < 10; y++) {
      for (var x = 0; x < 10; x++) {
        expect(restored.get(x, y), b.get(x, y));
      }
    }
    expect(restored.nextColors, b.nextColors);
    expect(restored.nextCells, b.nextCells);
  });
}
