import 'package:flutter/material.dart';

class AppColors {
  // Seed (used by ColorScheme)
  static const seed = Color(0xFF8AD7FF);

  // Pastel “Donezy” vibes (light)
  static const pastelPink = Color(0xFFFFC6E0);
  static const pastelBlue = Color(0xFFBFE9FF);
  static const pastelMint = Color(0xFFBFF7E5);
  static const pastelLavender = Color(0xFFD7C7FF);
  static const pastelPeach = Color(0xFFFFD7B5);

  // Dark-mode friendly pastels (slightly muted)
  static const darkSurface = Color(0xFF12141A);
  static const darkCard = Color(0xFF1A1F2A);

  // Common gradients (Phase 2 foundation)
  static const Gradient gBubblePrimary = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [pastelBlue, pastelLavender],
  );

  static const Gradient gBubbleWarm = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [pastelPeach, pastelPink],
  );

  static const Gradient gCardSoft = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFFFFFFFF), Color(0xFFF6FAFF)],
  );
}
