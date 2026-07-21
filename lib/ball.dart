import 'package:flutter/material.dart';

/// A shaded ball, lit from the upper-left — the same look as the Unity sprite,
/// done here with a radial gradient instead of a baked texture.
class Ball extends StatelessWidget {
  final Color color;
  final double diameter;

  const Ball({super.key, required this.color, required this.diameter});

  @override
  Widget build(BuildContext context) {
    final light = Color.lerp(color, Colors.white, 0.45)!;
    final dark = Color.lerp(color, Colors.black, 0.30)!;
    return Container(
      width: diameter,
      height: diameter,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          center: const Alignment(-0.35, -0.40),
          radius: 0.95,
          colors: [light, color, dark],
          stops: const [0.0, 0.55, 1.0],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.28),
            blurRadius: diameter * 0.10,
            offset: Offset(0, diameter * 0.05),
          ),
        ],
      ),
    );
  }
}
