import 'package:classic_lines/board.dart';
import 'package:classic_lines/palette.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('there are three selectable palettes with unique ids', () {
    expect(Palette.ballPalettes.length, 3);
    final ids = Palette.ballPalettes.map((p) => p.id).toSet();
    expect(ids.length, 3, reason: 'palette ids must be unique');
  });

  test('every palette covers colors 1..7 with a transparent slot 0', () {
    for (final p in Palette.ballPalettes) {
      expect(p.colors.length, Board.colorCount + 1, reason: p.id);
      expect(p.colors[0].a, 0, reason: '${p.id}: index 0 must be empty/transparent');
      for (var i = 1; i <= Board.colorCount; i++) {
        expect(p.colors[i].a, 1.0, reason: '${p.id}: color $i must be opaque');
      }
    }
  });

  test('ball colors within a palette are all distinct', () {
    for (final p in Palette.ballPalettes) {
      final balls = p.colors.sublist(1).map((c) => c.toARGB32()).toSet();
      expect(balls.length, Board.colorCount, reason: '${p.id} has duplicate ball colors');
    }
  });

  test('the neon palette is brighter than the classic one', () {
    double meanLuminance(BallPalette p) {
      final l = p.colors.sublist(1).map((c) => c.computeLuminance());
      return l.reduce((a, b) => a + b) / l.length;
    }

    expect(
      meanLuminance(Palette.neonBalls),
      greaterThan(meanLuminance(Palette.classicBalls)),
    );
  });
}
