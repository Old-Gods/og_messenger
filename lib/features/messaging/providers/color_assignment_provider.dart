import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/utils/color_utils.dart';

/// Provider for assigning unique colors to device IDs
final colorAssignmentProvider =
    NotifierProvider<ColorAssignmentNotifier, Map<String, Color>>(
      ColorAssignmentNotifier.new,
    );

/// Notifier that manages device ID to color assignments
class ColorAssignmentNotifier extends Notifier<Map<String, Color>> {
  int _nextColorIndex = 0;

  @override
  Map<String, Color> build() {
    return {};
  }

  /// Get color for a device ID, assigning a new one if needed
  Color getColorForDeviceId(String deviceId) {
    // Return existing color if already assigned
    if (state.containsKey(deviceId)) {
      return state[deviceId]!;
    }

    // Assign a new color
    final color = _assignNewColor();
    state = {...state, deviceId: color};
    return color;
  }

  /// Assign the next color sequentially from the palette
  Color _assignNewColor() {
    final color = ColorUtils.materialPalette[_nextColorIndex];
    // Move to next color, wrapping around if we reach the end
    _nextColorIndex = (_nextColorIndex + 1) % ColorUtils.materialPalette.length;
    return color;
  }

  /// Clear all color assignments (useful for testing or reset)
  void clearAssignments() {
    state = {};
    _nextColorIndex = 0;
  }
}
