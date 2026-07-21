import 'package:flutter/material.dart';

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

  /// Ball colors, indexed 1..7 (index 0 is empty / unused).
  static const ballColors = <Color>[
    Color(0x00000000), // 0 — empty
    Color(0xFFE54B4B), // 1 red
    Color(0xFF4CAF50), // 2 green
    Color(0xFF428BF5), // 3 blue
    Color(0xFFF5C142), // 4 yellow
    Color(0xFFA65AD8), // 5 purple
    Color(0xFF2EC4C4), // 6 cyan
    Color(0xFFEC842F), // 7 orange
  ];
}
