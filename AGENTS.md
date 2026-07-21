# AGENTS.md

Guidance for AI agents and developers working on this repo. See `README.md` for
the player-facing description and full rules.

## What this is

**Classic Lines** — the '98 color-lines game, rebuilt in Flutter. Primary target
is **Android**; the code is kept multiplatform (iOS / web / desktop all build).
A prior Unity implementation lives at `../ClassicLinesGame` and is the source of
the palette, the shaded-ball look, the BFS pathfinding and the line rules. When
porting more from it, read `../ClassicLinesGame/Assets/Scripts/Board.cs` and
`Art.cs`.

## Stack

- Flutter 3.44.6 (stable), Dart 3.12.2.
- Packages: `shared_preferences` (high scores + mute), `audioplayers` (SFX).
- State: plain `StatefulWidget` + `setState` (no state-management package). The
  board is small; full rebuilds are cheap and the board Stack is wrapped in a
  single `AnimatedBuilder` so only it repaints during animations.

## Architecture

```
lib/board.dart        Pure rules — no Flutter. Grid, BFS pathfinding, line
                      detection, scoring, snapshot()/restore() (undo), and
                      toJson()/fromJson() (save/resume).
lib/game_screen.dart  All UI + orchestration: rendering, input, the move/spawn/
                      clear/pulse/popup animations, controls, persistence, audio.
lib/ball.dart         The shaded ball (radial gradient lit from upper-left).
lib/palette.dart      Flat dark palette + the 7 ball colors (index 1..7).
lib/sfx.dart          Mute-aware SFX player; one low-latency AudioPlayer per sound.
lib/main.dart         App entry, dark theme, all orientations enabled.
tool/gen_sounds.py    Synthesizes assets/sounds/*.wav (pure-Python, no numpy).
test/board_test.dart  Headless rule tests.
```

Rendering model: the board is a `Stack` of absolutely-`Positioned` layers —
cell backgrounds, next-drop hint dots, settled balls, the sliding-ball overlay,
transparent tap targets, then the game-over veil. Cell size is derived from a
`LayoutBuilder` inside a square `AspectRatio`. Grid coord is `Point<int>`
(`typedef Cell`), `(x=col, y=row)`, row 0 at the top.

Responsive: a top-level `LayoutBuilder` picks `_tallLayout` (portrait/narrow —
header, board, controls stacked, capped at 560 wide) or `_wideLayout`
(landscape/large — board square on the left, header+controls in a side panel).
All orientations are enabled so tablets aren't letterboxed.

Turn flow (`_handleMove`): snapshot for undo → animate slide → commit move →
if it forms a line, clear + score (free turn); else drop 3 balls, then clear any
line the drop completed. A clearing move does **not** spawn.

Persistence (`shared_preferences`, keyed in `_GameScreenState`): mute; per-combo
high scores (`hi_{easy|normal}_{9|10}`); last mode/size (`cfg_minLine`,
`cfg_boardSize`); and the full in-progress board (`save_state`, via
`Board.toJson`). `_init()` runs async on startup — it resumes `save_state`
unless the game was over, else starts fresh in the last mode/size; `build()`
shows a bare dark screen until `_ready`. `_persist()` fires after each turn, on
new game / undo, and on `AppLifecycleState.paused|hidden|detached`; it removes
`save_state` once the game is over so the next launch starts clean.

## Rules that must not drift

- Scoring: `8 + (len − 4) × 2`, base len 4 in **both** modes ⇒ 5-in-a-row = 10,
  6 = 12, … Locked by `test/board_test.dart`.
- Mode = clear threshold: Easy 4-in-line, Normal 5-in-line.
- Four independent high scores, keyed `hi_{easy|normal}_{9|10}`.

## Build / run / test

```sh
flutter pub get
flutter test                         # rule tests (should be all green)
flutter analyze                      # must be clean
flutter run --release -d <deviceId>  # find id via `flutter devices`
flutter build apk --release          # -> build/app/outputs/flutter-apk/app-release.apk
```

## Identity & release config

- **Display name:** `Classic Lines` (all platforms).
- **Application ID / bundle id:** `com.classicdeveloper.classiclines` — set on
  Android (`applicationId`), iOS/macOS (bundle id), Linux (`APPLICATION_ID`). The
  Android `namespace` deliberately stays `com.classiclines.classic_lines` (it's
  the R-class package and can differ from the applicationId; changing it would
  mean moving `MainActivity.kt`). Owner: classicdeveloper18@gmail.com.
- **Version:** `pubspec.yaml` `version:` → `versionName+versionCode`.

### Launcher icon

Source art (a diagonal line of shaded balls on the dark board bg) is generated
by `tool/gen_icon.py` into `assets/icon/{icon,icon_foreground}.png` (source only,
not bundled at runtime). Platform icons are produced by `flutter_launcher_icons`:

```sh
ICON_DIR=assets/icon python tool/gen_icon.py   # regenerate source art
dart run flutter_launcher_icons                # regenerate all platform icons
```

Config lives in `pubspec.yaml` under `flutter_launcher_icons:` (Android adaptive
+ legacy, iOS, web, windows, macos). iOS uses `remove_alpha_ios: true`; the
source `icon.png` is a full opaque square.

### Android release signing

`android/app/build.gradle.kts` reads `android/key.properties` when present and
signs release with that upload keystore; without it, release falls back to debug
signing so `flutter run --release` still works. `key.properties`, `*.jks`,
`*.keystore` are gitignored. To set up a real signing key, copy
`android/key.properties.example` → `android/key.properties` and create the
keystore (the developer owns the passwords — don't create/commit them for them):

```sh
keytool -genkey -v -keystore upload-keystore.jks -storetype JKS \
  -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

### Windows build gotcha (important)

`android/gradle.properties` sets **`kotlin.incremental=false`**. When the pub
cache (`C:\…\Pub\Cache`) and the project sit on **different drives**, Kotlin's
incremental compiler crashes relativizing plugin source paths across roots
(`this and base files have different roots`), failing any plugin's
`compile*Kotlin` task. Do **not** remove that flag on this machine. Every native
plugin (`shared_preferences`, `audioplayers`) is affected without it.

## Regenerating sounds

```sh
OUT_DIR=assets/sounds python tool/gen_sounds.py
```

Edit frequencies/durations in `tool/gen_sounds.py`. Sounds are committed WAVs;
there is no imported/copyrighted audio.

## Verifying UI changes

- On a device/emulator: `flutter run` and look. Best signal.
- Headless screenshots of Flutter **web** hang (CanvasKit's WebGL canvas doesn't
  capture) — don't rely on browser-pane screenshots to verify the Flutter UI.
- The debug web-server (`flutter run -d web-server`) may fail its `dwds` debug
  handshake and never mount the app; use a **release** web build served
  statically if you need the web target in a browser.

## Conventions

- Keep `flutter analyze` clean (flutter_lints; braces on all flow control).
- Keep game rules in `board.dart` pure and covered by `board_test.dart`; the
  widget layer holds no rule logic.
- Match existing comment density and naming; comments explain *why*.

## Not done yet / ideas

- No actual upload keystore committed by design — the developer must create
  `android/key.properties` + `.jks` before a store build (see above).
- Possible polish: spawn "drop" tick, score-clear particles, an undo that
  refuses to claw back a scoring move (current undo is a full rollback).
