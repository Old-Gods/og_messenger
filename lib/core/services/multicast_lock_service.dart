import 'dart:io';
import 'package:flutter/services.dart';

/// Service to manage Android multicast lock via platform channel
class MulticastLockService {
  static const platform = MethodChannel(
    'com.ogmessenger.og_messenger/multicast',
  );

  bool _isAcquired = false;

  /// Acquire the multicast lock (Android only)
  /// Returns true if successful or if not on Android
  Future<bool> acquireLock() async {
    // Only needed on Android
    if (!Platform.isAndroid) {
      return true;
    }

    try {
      final result = await platform.invokeMethod('acquireMulticastLock');
      _isAcquired = result == true;
      return _isAcquired;
    } on PlatformException catch (e) {
      throw Exception('Failed to acquire multicast lock: ${e.message}');
    }
  }

  /// Release the multicast lock (Android only)
  Future<void> releaseLock() async {
    if (!Platform.isAndroid || !_isAcquired) {
      return;
    }

    try {
      await platform.invokeMethod('releaseMulticastLock');
      _isAcquired = false;
    } on PlatformException catch (e) {
      // Log error but don't throw - we're releasing anyway
      print('Error releasing multicast lock: ${e.message}');
    }
  }

  bool get isAcquired => _isAcquired;
}
