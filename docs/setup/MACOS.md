# macOS Setup

Setup guide for running OG Messenger on macOS.

## Prerequisites

- Flutter 3.11.0 or higher installed
- macOS 10.15 (Catalina) or higher
- Xcode 12 or higher
- Active network connection (WiFi or Ethernet)

## Installation

1. Clone or download the repository
2. Open Terminal
3. Navigate to project directory
4. Run:
```bash
flutter pub get
flutter run -d macos
```

## First Run

### Local Network Permission

macOS 14 (Sonoma) and later **require explicit permission** for local network access.

**On First Launch**, you'll see a system prompt:
> "OG Messenger would like to find and connect to devices on your local network"

✅ **Action**: Click **"OK"** or **"Allow"**

### If You Missed the Prompt

1. Open **System Settings** (System Preferences on older macOS)
2. Go to **Privacy & Security**
3. Scroll to **Local Network**
4. Find **OG Messenger** and toggle it **ON**

## Network Entitlements

The app requires specific entitlements (already configured in project):

```xml
<!-- macos/Runner/DebugProfile.entitlements -->
<!-- macos/Runner/Release.entitlements -->

<key>com.apple.security.network.client</key>
<true/>
<key>com.apple.security.network.server</key>
<true/>
```

These allow:
- **network.client**: Outgoing network connections
- **network.server**: Listening for incoming connections

## Info.plist Configuration

Already configured in the project:

```xml
<!-- macos/Runner/Info.plist -->

<key>NSLocalNetworkUsageDescription</key>
<string>OG Messenger needs to discover and communicate with devices on your local network to enable serverless messaging.</string>
```

This description appears in the permission prompt.

## Code Signing

### For Development

```bash
# Build and run (automatically signs for development)
flutter run -d macos

# For release build
flutter build macos --release
```

### For Distribution

To distribute outside the App Store, you need to sign the app:

1. **Obtain Developer ID Certificate**
   - Enroll in Apple Developer Program ($99/year)
   - Create Developer ID Application certificate

2. **Sign the App**
```bash
# Build first
flutter build macos --release

# Sign with Developer ID
codesign --deep --force --verify --verbose --sign "Developer ID Application: Your Name" build/macos/Build/Products/Release/og_messenger.app

# Verify signature
codesign --verify --verbose build/macos/Build/Products/Release/og_messenger.app
```

3. **Notarize for Gatekeeper** (macOS 10.15+)
```bash
# Create a ZIP of the app
ditto -c -k --keepParent build/macos/Build/Products/Release/og_messenger.app og_messenger.zip

# Submit for notarization
xcrun notarytool submit og_messenger.zip --apple-id your@email.com --password <app-specific-password> --team-id YOUR_TEAM_ID --wait

# Staple the notarization ticket
xcrun stapler staple build/macos/Build/Products/Release/og_messenger.app
```

## Firewall Configuration

### macOS Firewall

By default, macOS firewall doesn't block outgoing connections. If you have it enabled:

1. Open **System Settings** → **Network** → **Firewall**
2. Click **Options**
3. Ensure **"Block all incoming connections"** is **unchecked**
4. OR: Click **"+"** and add OG Messenger to allowed apps

### Using Terminal

```bash
# Check firewall status
sudo /usr/libexec/ApplicationFirewall/socketfilterfw --getglobalstate

# Add app to firewall (if needed)
sudo /usr/libexec/ApplicationFirewall/socketfilterfw --add /path/to/og_messenger.app

# Allow signed apps automatically
sudo /usr/libexec/ApplicationFirewall/socketfilterfw --setallowsigned on
```

## Network Configuration

### Check Network Connection

```bash
# Show network interfaces
ifconfig

# Check WiFi connection
networksetup -getinfo "Wi-Fi"

# Test connectivity
ping -c 3 google.com
```

### Multicast Support

macOS supports multicast natively. If discovery isn't working:

```bash
# Check routing table
netstat -rn | grep 224

# Show multicast group memberships
netstat -g

# Test multicast reception (run in two terminals)
# Terminal 1: Listen
nc -u -l 4445

# Terminal 2: Send
echo "test" | nc -u 239.255.42.99 4445
```

## Common Issues

### Issue: "App is damaged and can't be opened"

**Cause**: Gatekeeper blocking unsigned/unnotarized app.

**Solution** (Development only):
```bash
# Remove quarantine attribute
xattr -cr /path/to/og_messenger.app

# Or allow from System Settings:
# System Settings → Privacy & Security → Click "Open Anyway"
```

### Issue: Local Network Permission Not Granted

**Symptom**: No devices discovered, no permission prompt appeared.

**Solution**:
1. Check **System Settings** → **Privacy & Security** → **Local Network**
2. Manually toggle **OG Messenger** to **ON**
3. Restart the app

If still not working:
```bash
# Reset network permissions (requires restart)
tccutil reset SystemPolicyNetworkVolumes
```

### Issue: Cannot bind to TCP port

**Symptom**: Error message about port 8888 already in use.

**Solution**:
```bash
# Find what's using the port
lsof -i :8888

# Kill the process (replace PID)
kill -9 <PID>
```

OG Messenger auto-increments to ports 8889-8987, so this is rare.

### Issue: No other devices discovered

**Troubleshooting**:

1. **Check VPN**
   ```bash
   # List VPN interfaces
   ifconfig | grep -A 5 utun
   
   # Disable VPN temporarily to test
   ```

2. **Check Network**
   ```bash
   # Verify connected to WiFi
   networksetup -getairportnetwork en0
   
   # Check IP address
   ipconfig getifaddr en0
   ```

3. **Test Multicast**
   ```bash
   # Listen for OG Messenger broadcasts
   sudo tcpdump -i any 'udp and dst host 239.255.42.99 and port 4445'
   ```

### Issue: App crashes on launch

**Solution**:
```bash
# Check crash logs
open ~/Library/Logs/DiagnosticReports/

# Look for og_messenger crash files

# Or use Console app:
# Applications → Utilities → Console
# Search for "og_messenger"
```

## Performance Tips

### Reduce Energy Usage

```bash
# Check energy usage
pmset -g assertions

# Let system sleep when not in use
# OG Messenger will stop broadcasting when backgrounded
```

### Network Performance

```bash
# Check network statistics
netstat -i

# Monitor bandwidth
nettop -m route

# Check WiFi signal
/System/Library/PrivateFrameworks/Apple80211.framework/Versions/Current/Resources/airport -I
```

## Development

### Debug Mode

```bash
# Run with verbose logging
flutter run -d macos -v

# View real-time logs
log stream --predicate 'process == "og_messenger"' --level debug
```

### Clean Build

```bash
# Clean Flutter build
flutter clean

# Clean Xcode build
cd macos
xcodebuild clean
cd ..

# Rebuild
flutter pub get
flutter build macos
```

## macOS Version Compatibility

### macOS 15 (Sequoia) - Latest
✅ Full support, all features work

### macOS 14 (Sonoma)
✅ Full support, requires local network permission

### macOS 13 (Ventura)
✅ Full support

### macOS 12 (Monterey)
✅ Full support

### macOS 11 (Big Sur)
✅ Full support

### macOS 10.15 (Catalina)
✅ Supported (minimum version)
⚠️ Notarization required for Gatekeeper

### macOS 10.14 and earlier
❌ Not supported (Flutter requirement)

## Apple Silicon vs Intel

### Apple Silicon (M1/M2/M3/M4)
✅ Native ARM64 support
- Builds as universal binary by default
- Excellent performance

### Intel
✅ Full support
- x86_64 architecture
- May run slightly slower than Apple Silicon

### Universal Binary

Flutter builds universal binaries by default (supports both):
```bash
# Verify architecture
lipo -info build/macos/Build/Products/Release/og_messenger.app/Contents/MacOS/og_messenger

# Should show: x86_64 arm64
```

## Sandboxing

**Development builds**: Not sandboxed (network access works)
**Release builds**: Not sandboxed due to network requirements

If you need sandboxing (App Store submission):
- ⚠️ Requires additional entitlements
- May need App Sandbox exception for local network
- Not currently configured for App Store

## Background Behavior

### App in Foreground
✅ Full functionality - discovers peers, sends/receives messages

### App in Background
⚠️ Limited - discovery continues for ~10 seconds, then pauses
- Messages can still be received on established TCP connections
- Notifications will appear

### App Minimized to Dock
✅ Continues running normally (not technically "background")

## System Requirements

**Minimum**:
- macOS 10.15 (Catalina)
- 4 GB RAM
- 500 MB disk space
- WiFi or Ethernet adapter

**Recommended**:
- macOS 14 (Sonoma) or later
- 8 GB RAM
- SSD storage
- Apple Silicon Mac

## Uninstallation

### Remove App

```bash
# Remove application
rm -rf /path/to/og_messenger.app

# Or drag to Trash
```

### Remove App Data

```bash
# Remove preferences
rm -rf ~/Library/Preferences/com.ogmessenger.ogMessenger.plist

# Remove application support
rm -rf ~/Library/Application\ Support/com.ogmessenger.ogMessenger

# Remove cached data
rm -rf ~/Library/Caches/com.ogmessenger.ogMessenger

# Remove logs
rm -rf ~/Library/Logs/com.ogmessenger.ogMessenger
```

### Reset Permissions

```bash
# Reset local network permission
tccutil reset SystemPolicyNetworkVolumes com.ogmessenger.ogMessenger
```

## Troubleshooting Commands

```bash
# Test UDP port binding
nc -u -l 4445

# Check what's listening on ports
lsof -i -P | grep LISTEN | grep -E '(4445|888[0-9])'

# Monitor network activity
sudo nettop -m route

# Check DNS and routing
scutil --dns
netstat -rn

# View system logs
log show --predicate 'process == "og_messenger"' --last 5m

# Check entitlements
codesign -d --entitlements - build/macos/Build/Products/Release/og_messenger.app
```

## Known Issues

### Rosetta 2 (Intel apps on Apple Silicon)

Not an issue for this app - builds natively for Apple Silicon.

### Firewall Blocking

If third-party firewall (Little Snitch, LuLu):
- Allow incoming connections on UDP 4445
- Allow outgoing connections to 239.255.42.99
- Allow incoming TCP 8888-8987

### VPN Interference

Common with:
- Corporate VPNs
- Privacy VPNs (NordVPN, ExpressVPN)
- Tailscale, ZeroTier

**Solution**: Disconnect VPN while using OG Messenger

## Getting Help

If issues persist:

1. Check permissions (Privacy & Security → Local Network)
2. Verify not using VPN
3. Test with another macOS device first
4. Check Console.app for errors
5. Review entitlements with `codesign -d --entitlements -`

## Tested Configurations

✅ **Confirmed Working**:
- macOS 15 (Sequoia) - Apple Silicon & Intel
- macOS 14 (Sonoma) - Apple Silicon & Intel
- macOS 13 (Ventura) - Apple Silicon & Intel
- MacBook Pro, MacBook Air, iMac, Mac mini, Mac Studio

⚠️ **Untested**:
- Hackintosh (may work if network properly configured)
- macOS in VM (VirtualBox, Parallels) - networking complex
