import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'game_screen.dart';
import 'palette.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Allow every orientation; the UI adapts to portrait vs. landscape (and to
  // large screens) so tablets aren't letterboxed. Ignored on desktop/web.
  SystemChrome.setPreferredOrientations(const [
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  runApp(const ClassicLinesApp());
}

class ClassicLinesApp extends StatelessWidget {
  const ClassicLinesApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Classic Lines',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: Palette.background,
        colorScheme: const ColorScheme.dark(
          primary: Palette.accent,
          surface: Palette.background,
        ),
        fontFamily: 'Roboto',
      ),
      home: const GameScreen(),
    );
  }
}
