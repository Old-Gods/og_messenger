import 'dart:math';
import 'package:flutter/material.dart';

/// Utilities for color manipulation and text contrast
class ColorUtils {
  /// Ordered color palette: 11 colors × 5 shades (300-700) = 55 colors total
  /// Order: green, red, amber, pink, lightGreen, orange, purple, lime, deepOrange, deepPurple, brown
  /// Each shade gets all 11 colors before moving to the next shade
  static final List<Color> materialPalette = [
    // Shade 300
    Colors.green[300]!,
    Colors.red[300]!,
    Colors.amber[300]!,
    Colors.pink[300]!,
    Colors.lightGreen[300]!,
    Colors.orange[300]!,
    Colors.purple[300]!,
    Colors.lime[300]!,
    Colors.deepOrange[300]!,
    Colors.deepPurple[300]!,
    Colors.brown[300]!,
    // Shade 400
    Colors.green[400]!,
    Colors.red[400]!,
    Colors.amber[400]!,
    Colors.pink[400]!,
    Colors.lightGreen[400]!,
    Colors.orange[400]!,
    Colors.purple[400]!,
    Colors.lime[400]!,
    Colors.deepOrange[400]!,
    Colors.deepPurple[400]!,
    Colors.brown[400]!,
    // Shade 500
    Colors.green[500]!,
    Colors.red[500]!,
    Colors.amber[500]!,
    Colors.pink[500]!,
    Colors.lightGreen[500]!,
    Colors.orange[500]!,
    Colors.purple[500]!,
    Colors.lime[500]!,
    Colors.deepOrange[500]!,
    Colors.deepPurple[500]!,
    Colors.brown[500]!,
    // Shade 600
    Colors.green[600]!,
    Colors.red[600]!,
    Colors.amber[600]!,
    Colors.pink[600]!,
    Colors.lightGreen[600]!,
    Colors.orange[600]!,
    Colors.purple[600]!,
    Colors.lime[600]!,
    Colors.deepOrange[600]!,
    Colors.deepPurple[600]!,
    Colors.brown[600]!,
    // Shade 700
    Colors.green[700]!,
    Colors.red[700]!,
    Colors.amber[700]!,
    Colors.pink[700]!,
    Colors.lightGreen[700]!,
    Colors.orange[700]!,
    Colors.purple[700]!,
    Colors.lime[700]!,
    Colors.deepOrange[700]!,
    Colors.deepPurple[700]!,
    Colors.brown[700]!,
  ];

  /// Calculate relative luminance of a color (0.0 to 1.0)
  /// Based on WCAG 2.0 formula
  static double calculateLuminance(Color color) {
    // Convert RGB to relative luminance
    double r = color.r;
    double g = color.g;
    double b = color.b;

    // Apply gamma correction
    r = r <= 0.03928 ? r / 12.92 : pow((r + 0.055) / 1.055, 2.4).toDouble();
    g = g <= 0.03928 ? g / 12.92 : pow((g + 0.055) / 1.055, 2.4).toDouble();
    b = b <= 0.03928 ? b / 12.92 : pow((b + 0.055) / 1.055, 2.4).toDouble();

    // Calculate luminance
    return 0.2126 * r + 0.7152 * g + 0.0722 * b;
  }

  /// Get contrasting text color (black or white) for a given background color
  /// Returns white for dark backgrounds, black for light backgrounds
  static Color getContrastingTextColor(Color backgroundColor) {
    final luminance = calculateLuminance(backgroundColor);
    // Use threshold of 0.5 for better contrast
    return luminance > 0.5 ? Colors.black87 : Colors.white;
  }

  /// Adjust color brightness based on theme
  /// Makes colors lighter in dark mode, darker in light mode for better visibility
  static Color adjustColorForTheme(Color color, Brightness brightness) {
    if (brightness == Brightness.dark) {
      // In dark mode, lighten colors slightly
      return Color.lerp(color, Colors.white, 0.2) ?? color;
    } else {
      // In light mode, darken colors slightly
      return Color.lerp(color, Colors.black, 0.1) ?? color;
    }
  }

  /// Get a secondary text color (for timestamps, metadata) based on background
  /// Returns a semi-transparent version of the contrasting text color
  static Color getSecondaryTextColor(Color backgroundColor) {
    final baseColor = getContrastingTextColor(backgroundColor);
    return baseColor.withValues(alpha: 0.7);
  }
}
