import Cocoa
import FlutterMacOS
import CoreWLAN

class NetworkInfoHelper {
  static func handleMethodCall(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "getWifiSSID":
      result(getWifiSSID())
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  static func getWifiSSID() -> String? {
    guard let interface = CWWiFiClient.shared().interface() else {
      print("⚠️ CoreWLAN: No WiFi interface found")
      return nil
    }
    
    guard let ssid = interface.ssid() else {
      print("⚠️ CoreWLAN: No SSID available")
      return nil
    }
    
    print("✅ CoreWLAN: SSID detected: \(ssid)")
    return ssid
  }
}
