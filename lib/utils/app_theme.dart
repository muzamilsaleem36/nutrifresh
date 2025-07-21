import 'package:flutter/material.dart';

class AppTheme {
  // Main colors
  static const Color primaryColor = Color(0xFF5DB075);
  static const Color secondaryColor = Color(0xFF4B9460);
  static const Color accentColor = Color(0xFF4E9F3D);
  static const Color backgroundColor = Color(0xFFF9F9F9);
  
  // Status colors
  static const Color successColor = Color(0xFF4CAF50);
  static const Color warningColor = Color(0xFFFFC107);
  static const Color errorColor = Color(0xFFE53935);
  
  // Freshness colors
  static const Color freshColor = Color(0xFF5DB075); // Green
  static const Color midSpoiledColor = Color(0xFFFFCB66); // Yellow
  static const Color rottenColor = Color(0xFFE57373); // Red
  
  // Card and container styles
  static const double borderRadius = 16.0;
  static const double smallBorderRadius = 8.0;
  
  // Shadows
  static List<BoxShadow> cardShadow = [
    BoxShadow(
      color: Colors.black.withOpacity(0.05),
      blurRadius: 10,
      spreadRadius: 0,
      offset: const Offset(0, 2),
    ),
  ];
} 