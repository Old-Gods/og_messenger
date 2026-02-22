import Cocoa
import FlutterMacOS
import CoreWLAN
import SystemConfiguration
import CoreLocation

@main
class AppDelegate: FlutterAppDelegate, CLLocationManagerDelegate {
  private let locationManager = CLLocationManager()
  private var locationAuthorizationGranted = false
  private var methodChannel: FlutterMethodChannel?
  
  override func applicationDidFinishLaunching(_ notification: Notification) {
    let controller = mainFlutterWindow?.contentViewController as! FlutterViewController
    
    // Request location authorization for WiFi SSID access (macOS 11+)
    locationManager.delegate = self
    if CLLocationManager.locationServicesEnabled() {
      print("🔍 Location services enabled, checking authorization...")
      
      if #available(macOS 11.0, *) {
        let status = locationManager.authorizationStatus
        print("   - Current status: \(status.rawValue)")
        
        if status == .notDetermined {
          print("   - Requesting authorization...")
          locationManager.requestAlwaysAuthorization()
        } else if status == .authorizedAlways || status == .authorized {
          locationAuthorizationGranted = true
          print("✅ Location authorization already granted")
        } else {
          print("⚠️ Location authorization denied or restricted")
        }
      } else {
        // On macOS 10.15, location authorization works differently
        print("   - macOS 10.15: Using deprecated authorization check")
        locationManager.requestAlwaysAuthorization()
        locationAuthorizationGranted = true // Assume granted on older macOS
      }
    } else {
      print("⚠️ Location services are disabled")
    }
    
    // Register network info method channel
    let networkPluginRegistrar = controller.registrar(forPlugin: "NetworkInfoPlugin")
    let channel = FlutterMethodChannel(name: "com.ogmessenger.network_info", binaryMessenger: networkPluginRegistrar.messenger)
    methodChannel = channel // Store reference for later use
    
    channel.setMethodCallHandler { (call, result) in
      if call.method == "getWifiSSID" {
        result(self.getWifiSSID())
      } else {
        result(FlutterMethodNotImplemented)
      }
    }
    
    super.applicationDidFinishLaunching(notification)
  }
  
  func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
    if #available(macOS 11.0, *) {
      let status = manager.authorizationStatus
      print("🔍 Location authorization changed: \(status.rawValue)")
      
      if status == .authorizedAlways || status == .authorized {
        locationAuthorizationGranted = true
        print("✅ Location authorization granted")
        
        // Notify Flutter that permissions were granted so it can refresh network ID
        print("📡 Notifying Flutter to refresh network ID...")
        methodChannel?.invokeMethod("onLocationPermissionGranted", arguments: nil)
      } else {
        locationAuthorizationGranted = false
        print("⚠️ Location authorization denied or restricted")
      }
    }
  }
  
  private func getWifiSSID() -> String? {
    print("🔍 Attempting to get WiFi SSID...")
    print("   - Location authorization: \(locationAuthorizationGranted)")
    
    if !locationAuthorizationGranted {
      print("⚠️ Location authorization not granted - WiFi SSID will be unavailable")
      print("   Please grant location permission in System Settings > Privacy & Security > Location Services")
    }
    
    // Method 1: Try CoreWLAN (most reliable when it works)
    if let ssid = getWifiSSIDViaCoreWLAN() {
      return ssid
    }
    
    // Method 2: Try SystemConfiguration CaptiveNetwork (legacy)
    if let ssid = getWifiSSIDViaSystemConfiguration() {
      return ssid
    }
    
    // Method 3: Try networksetup command
    if let ssid = getWifiSSIDViaNetworkSetup() {
      return ssid
    }
    
    print("⚠️ All methods failed to retrieve WiFi SSID")
    return nil
  }
  
  private func getWifiSSIDViaCoreWLAN() -> String? {
    let client = CWWiFiClient.shared()
    
    let interfaceNames = CWWiFiClient.interfaceNames()
    print("🔍 CoreWLAN: Interfaces: \(String(describing: interfaceNames))")
    
    if let names = interfaceNames {
      for name in names {
        if let interface = client.interface(withName: name),
           interface.powerOn(),
           let ssid = interface.ssid() {
          print("✅ CoreWLAN: Found SSID '\(ssid)' on \(name)")
          return ssid
        }
      }
    }
    
    print("⚠️ CoreWLAN: No SSID found")
    return nil
  }
  
  private func getWifiSSIDViaSystemConfiguration() -> String? {
    // Note: CaptiveNetwork APIs are deprecated but might still work
    print("🔍 Trying SystemConfiguration framework...")
    
    // This API is deprecated and may not work on modern macOS
    // Keeping it as a fallback attempt
    return nil
  }
  
  private func getWifiSSIDViaNetworkSetup() -> String? {
    print("🔍 Trying networksetup command...")
    
    // Try all possible WiFi interface names
    let interfaceNames = ["en0", "en1", "en2"]
    
    for interfaceName in interfaceNames {
      let task = Process()
      task.launchPath = "/usr/sbin/networksetup"
      task.arguments = ["-getairportnetwork", interfaceName]
      
      let pipe = Pipe()
      task.standardOutput = pipe
      task.standardError = pipe
      
      do {
        try task.run()
        task.waitUntilExit()
        
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        if let output = String(data: data, encoding: .utf8) {
          print("   - \(interfaceName): \(output.trimmingCharacters(in: .whitespacesAndNewlines))")
          
          // Parse "Current Wi-Fi Network: NetworkName"
          if let range = output.range(of: "Current Wi-Fi Network: ") {
            let ssid = String(output[range.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
            if !ssid.isEmpty && !ssid.contains("not associated") {
              print("✅ networksetup: Found SSID '\(ssid)' on \(interfaceName)")
              return ssid
            }
          }
        }
      } catch {
        print("   - Error checking \(interfaceName): \(error)")
      }
    }
    
    print("⚠️ networksetup: No SSID found")
    return nil
  }
  
  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return true
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }
}
