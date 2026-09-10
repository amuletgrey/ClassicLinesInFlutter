/// Static text shown in the in-app info dialogs (Help / About). The privacy
/// policy is loaded from assets/legal/privacy_policy.txt instead of living here.
class Info {
  /// Keep in sync with `version:` in pubspec.yaml.
  static const version = '1.2.0';

  static const help = '''HOW TO PLAY

• Tap a ball to pick it up, then tap an empty cell to move it there.
• A ball only moves if a clear path of empty cells connects the two — no
  jumping over other balls.
• Line up 4 (Easy) or 5 (Normal) balls of the same color in a row, column, or
  diagonal to clear them and score. Longer lines score more.
• A move that clears a line is free; otherwise 3 new balls drop. Their colors
  are shown under NEXT, and small dots mark where they will land.
• The game ends when the board fills up.

CONTROLS

• New game — start over in the selected mode and board size.
• Easy / Normal — clear at 4 or 5 in a line.
• 9×9 / 10×10 — board size. Each mode + size keeps its own high score.
• ↶ Undo — take back your last move (once).
• The three color buttons switch the ball palette.
• Tap the speaker to mute or unmute the sounds.

Your game, scores and settings are saved on the device, so you can close the
app and pick up where you left off.''';

  static const about = '''Classic Lines

A modern, flat take on the classic '98 color-lines puzzle. Free, no ads, and no
tracking — everything stays on your device.

Developer: Max Cavrilon
Feedback: maxcavrilon@gmail.com
Version $version''';
}
