package com.ogmessenger.og_messenger

import android.content.Context
import android.net.wifi.WifiManager
import android.os.PowerManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.ogmessenger.og_messenger/multicast"
    private var multicastLock: WifiManager.MulticastLock? = null
    private var wakeLock: PowerManager.WakeLock? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "acquireMulticastLock" -> {
                        try {
                            acquireMulticastLock()
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("LOCK_ERROR", e.message, null)
                        }
                    }
                    "releaseMulticastLock" -> {
                        releaseMulticastLock()
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun acquireMulticastLock() {
        val wifiManager = applicationContext.getSystemService(Context.WIFI_SERVICE) as WifiManager
        
        // Acquire multicast lock
        multicastLock = wifiManager.createMulticastLock("og_messenger_multicast").apply {
            setReferenceCounted(false)
            acquire()
        }
        
        // Keep CPU awake for background multicast operations
        // Use indefinite wake lock - will be released when multicast lock is released
        val powerManager = applicationContext.getSystemService(Context.POWER_SERVICE) as PowerManager
        wakeLock = powerManager.newWakeLock(
            PowerManager.PARTIAL_WAKE_LOCK,
            "og_messenger::MulticastWakeLock"
        ).apply {
            setReferenceCounted(false)
            acquire() // Acquire indefinitely until explicitly released
        }
    }

    private fun releaseMulticastLock() {
        multicastLock?.release()
        multicastLock = null
        
        wakeLock?.release()
        wakeLock = null
    }

    override fun onDestroy() {
        releaseMulticastLock()
        super.onDestroy()
    }
}
