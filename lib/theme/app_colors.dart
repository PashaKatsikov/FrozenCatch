import 'package:flutter/material.dart';

/// Central color palette for the icy, winter-fishing themed UI.
class AppColors {
  AppColors._();

  static const Color deepIce = Color(0xFF063A63);
  static const Color midIce = Color(0xFF0E5A93);
  static const Color skyBlue = Color(0xFF7EC8E3);
  static const Color paleIce = Color(0xFFDFF6FF);
  static const Color frost = Color(0xFFEAF9FF);

  static const Color accentGold = Color(0xFFFFC24B);
  static const Color accentOrange = Color(0xFFFF8A3D);
  static const Color accentRed = Color(0xFFFF5252);

  static const Color legendaryPurple = Color(0xFFB388FF);
  static const Color rareCyan = Color(0xFF4DE8E8);
  static const Color successGreen = Color(0xFF4CD97B);

  static const Color panelDark = Color(0xCC0A2C4D);
  static const Color panelLight = Color(0xE6FFFFFF);

  static const LinearGradient skyGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF3F8FD1), Color(0xFF9AD6F2)],
  );

  static const LinearGradient buttonGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF35C2FF), Color(0xFF0E7FD9)],
  );

  static const LinearGradient goldGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFFFFE08A), Color(0xFFFFA733)],
  );
}
