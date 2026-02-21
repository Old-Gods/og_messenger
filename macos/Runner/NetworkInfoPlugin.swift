import Cocoa
import FlutterMacOS
import CoreWLAN

public class NetworkInfoPlugin: NSObject, FlutterPlugin {
  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "com.ogmessenger.network_info", binaryMessenger: registrar.messenger)
    let instance = NetworkInfoPlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "getWifiSSID":
      result(getWifiSSID())
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func getWifiSSID() -> String? {
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
