import 'package:flutter/material.dart';

/// A named set of ball colors, indexed 1..7 (index 0 is empty / unused).
///
/// The board stores color *indices*, never colors, so switching palettes only
/// changes how existing balls are painted — it never touches the game state.
class BallPalette {
  final String id;
  final List<Color> colors;
  const BallPalette(this.id, this.colors);
}

/// Flat dark palette, carried over from the Unity build so the two games share a look.
class Palette {
  static const background = Color(0xFF1B1F2A);
  static const boardPanel = Color(0xFF252B3A);
  static const cell = Color(0xFF2F3648);
  static const cellHighlight = Color(0xFF3D465C);
  static const text = Color(0xFFE8ECF4);
  static const textDim = Color(0xFF8B95AC);
  static const accent = Color(0xFF4C8BF5);
  static const danger = Color(0xFFE54B4B);
  static const gain = Color(0xFF6FE39A); // the floating "+X" score popup

  /// The original vibrant set, shared with the Unity build.
  static const classicBalls = BallPalette('classic', <Color>[
    Color(0x00000000), // 0 — empty
    Color(0xFFE54B4B), // 1 red
    Color(0xFF4CAF50), // 2 green
    Color(0xFF428BF5), // 3 blue
    Color(0xFFF5C142), // 4 yellow
    Color(0xFFA65AD8), // 5 purple
    Color(0xFF2EC4C4), // 6 cyan
    Color(0xFFEC842F), // 7 orange
  ]);

  /// Bright neon set — electric, high-saturation hues that glow on the dark board.
  static const neonBalls = BallPalette('neon', <Color>[
    Color(0x00000000), // 0 — empty
    Color(0xFFFF3D8B), // 1 hot pink
    Color(0xFF9CFF3D), // 2 electric lime
    Color(0xFF38A8FF), // 3 vivid azure
    Color(0xFFFFD21F), // 4 bright amber
    Color(0xFFB45CFF), // 5 electric purple
    Color(0xFF22E6CE), // 6 aqua
    Color(0xFFFF7A2E), // 7 vivid orange
  ]);

  /// Maximum separation for readability: the six saturated RGB primaries and
  /// secondaries plus white, all bright against the dark board.
  static const contrastBalls = BallPalette('contrast', <Color>[
    Color(0x00000000), // 0 — empty
    Color(0xFFFF3B30), // 1 red
    Color(0xFF2FE05C), // 2 green
    Color(0xFF4D8DFF), // 3 blue
    Color(0xFFFFE81F), // 4 yellow
    Color(0xFFFF4FD8), // 5 magenta
    Color(0xFF24E0E0), // 6 cyan
    Color(0xFFF5F5FA), // 7 white
  ]);

  /// Selectable palettes, in the order they appear in the picker.
  static const ballPalettes = <BallPalette>[classicBalls, neonBalls, contrastBalls];
}
