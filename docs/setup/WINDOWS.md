# Windows Setup

Setup guide for running OG Messenger on Windows.

## Prerequisites

- Flutter 3.11.0 or higher installed
- Windows 10 or Windows 11
- Active network connection (WiFi or Ethernet)

## Installation

1. Clone or download the repository
2. Open Command Prompt or PowerShell
3. Navigate to project directory
4. Run:
```powershell
flutter pub get
flutter run -d windows
```

## First Run

### Windows Firewall Prompt

On first launch, Windows Defender Firewall will show a prompt:

**"Windows Defender Firewall has blocked some features of this app"**

✅ **Action**: Click **"Allow access"** for both:
- Private networks (home/work)
- Public networks (if you plan to use on public WiFi)

### If You Missed the Prompt

Manually configure Windows Firewall:

1. Open **Windows Defender Firewall**
   - Press `Win + R`
   - Type `firewall.cpl`
   - Press Enter

2. Click **"Allow an app or feature through Windows Defender Firewall"**

3. Click **"Change settings"** (requires admin)

4. Click **"Allow another app..."**

5. Browse to: `<project>\build\windows\x64\runner\Release\og_messenger.exe`

6. Click **"Add"**

7. Check both **"Private"** and **"Public"** boxes

8. Click **"OK"**

## Advanced Firewall Configuration

If you need more control, add specific rules:

### Using PowerShell (Run as Administrator)

```powershell
# Allow UDP for device discovery
New-NetFirewallRule -DisplayName "OG Messenger UDP" -Direction Inbound -Protocol UDP -LocalPort 4445 -Action Allow

# Allow TCP for messages
New-NetFirewallRule -DisplayName "OG Messenger TCP" -Direction Inbound -Protocol TCP -LocalPort 8888-8987 -Action Allow

# Allow outbound as well
New-NetFirewallRule -DisplayName "OG Messenger UDP Out" -Direction Outbound -Protocol UDP -LocalPort 4445 -Action Allow
New-NetFirewallRule -DisplayName "OG Messenger TCP Out" -Direction Outbound -Protocol TCP -LocalPort 8888-8987 -Action Allow
```

### Using GUI (Advanced)

1. Open **Windows Defender Firewall with Advanced Security**
   - Press `Win + R`
   - Type `wf.msc`
   - Press Enter

2. Click **"Inbound Rules"** → **"New Rule..."**

3. **Rule Type**: Port → Next

4. **Protocol**: UDP
   - **Specific local ports**: 4445
   - Next

5. **Action**: Allow the connection → Next

6. **Profile**: Check all (Domain, Private, Public) → Next

7. **Name**: "OG Messenger Discovery" → Finish

8. Repeat steps 2-7 for TCP:
   - Protocol: TCP
   - Ports: 8888-8987
   - Name: "OG Messenger Messages"

## Network Configuration

### Check Network Connection

```powershell
# Check network adapters
Get-NetAdapter

# Test connectivity
Test-NetConnection -ComputerName google.com

# Show IP configuration
ipconfig /all
```

### Multicast Support

Windows 10/11 supports multicast by default. If discovery isn't working:

```powershell
# Check multicast routing table
route print

# Check firewall status
Get-NetFirewallProfile
```

## Common Issues

### Issue: "Cannot bind to TCP port 8888"

**Cause**: Port already in use by another application.

**Solution**:
```powershell
# Find what's using the port
netstat -ano | findstr :8888

# Kill the process (replace PID with actual Process ID)
taskkill /PID <PID> /F
```

OG Messenger will automatically try ports 8888-8987, so this usually isn't an issue.

### Issue: No other devices discovered

**Possible Causes**:

1. **Firewall blocking UDP**
   - Verify firewall rules (see above)
   - Temporarily disable firewall to test: `netsh advfirewall set allprofiles state off`
   - Re-enable after testing: `netsh advfirewall set allprofiles state on`

2. **Wrong network adapter**
   - If you have multiple adapters (WiFi + Ethernet + VPN), ensure using correct one
   - Disable unnecessary adapters temporarily
   
3. **VPN interference**
   - Disable VPN while using OG Messenger
   - VPNs route traffic through different networks

4. **WiFi Isolation**
   - Some public WiFi networks isolate clients
   - Use on home/trusted network only

### Issue: High CPU usage

**Cause**: Windows Defender real-time scanning.

**Solution**: Add exclusion:
1. Open **Windows Security**
2. **Virus & threat protection** → **Manage settings**
3. **Exclusions** → **Add an exclusion**
4. Choose **Folder** → Select project directory

### Issue: Build fails

```powershell
# Clean and rebuild
flutter clean
flutter pub get
flutter build windows
```

## Windows 10 vs Windows 11

### Windows 10
- Full support, no special configuration needed
- Firewall prompts may appear differently

### Windows 11
- Full support
- Enhanced security may show additional prompts
- All networking features work identically

## Running on Startup (Optional)

To launch OG Messenger at Windows startup:

1. Build release version:
```powershell
flutter build windows --release
```

2. Create shortcut to:
```
<project>\build\windows\x64\runner\Release\og_messenger.exe
```

3. Copy shortcut to:
```
%APPDATA%\Microsoft\Windows\Start Menu\Programs\Startup
```

Or using PowerShell:
```powershell
$source = "C:\path\to\og_messenger.exe"
$destination = "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup\OG Messenger.lnk"
$WshShell = New-Object -ComObject WScript.Shell
$Shortcut = $WshShell.CreateShortcut($destination)
$Shortcut.TargetPath = $source
$Shortcut.Save()
```

## Performance Tips

### Reduce Background Activity

- Close app when not in use
- Windows may show "Background app" notification

### Network Performance

```powershell
# Check network statistics
netstat -e

# Monitor bandwidth
Get-NetAdapterStatistics
```

## Development

### Debug Mode

Run from PowerShell or Command Prompt to see logs:
```powershell
flutter run -d windows -v
```

### Release Build

For distribution:
```powershell
flutter build windows --release

# Executable will be at:
# build\windows\x64\runner\Release\og_messenger.exe
```

### Package for Distribution

The Release folder contains all necessary files:
```
Release\
├── og_messenger.exe          # Main executable
├── flutter_windows.dll       # Flutter engine
└── data\                     # Assets and resources
```

Zip this entire folder for distribution.

## Antivirus & Security Software

Some antivirus programs may flag the app:

### Windows Defender
- Usually no issues
- May scan first run (slows startup)
- Add exclusion if needed (see High CPU section)

### Third-party Antivirus
- Kaspersky, Norton, McAfee may show warnings
- Add to trusted applications
- Whitelist network activity

## System Requirements

**Minimum**:
- Windows 10 version 1809 or higher
- 4 GB RAM
- 500 MB disk space
- WiFi or Ethernet adapter

**Recommended**:
- Windows 11
- 8 GB RAM
- SSD storage
- Modern WiFi adapter (802.11ac or newer)

## Uninstallation

### Remove App

1. Simply delete the application folder
2. No registry entries or system files

### Remove Firewall Rules

```powershell
# List OG Messenger rules
Get-NetFirewallRule | Where-Object {$_.DisplayName -like "*OG Messenger*"}

# Remove rules
Remove-NetFirewallRule -DisplayName "OG Messenger UDP"
Remove-NetFirewallRule -DisplayName "OG Messenger TCP"
Remove-NetFirewallRule -DisplayName "OG Messenger UDP Out"
Remove-NetFirewallRule -DisplayName "OG Messenger TCP Out"
```

### Remove App Data

App data is stored in:
```
%LOCALAPPDATA%\og_messenger
```

Delete this folder to clear all message history and settings.

## Troubleshooting Commands

```powershell
# Test UDP port
Test-NetConnection -ComputerName localhost -Port 4445 -InformationLevel Detailed

# Check listening ports
netstat -an | findstr :888

# View Windows Firewall logs
Get-Content C:\Windows\System32\LogFiles\Firewall\pfirewall.log -Tail 50

# Check network profile (Public/Private)
Get-NetConnectionProfile
```

## Known Issues

### Windows Defender SmartScreen

**Symptom**: "Windows protected your PC" warning.

**Solution**:
- Click "More info"
- Click "Run anyway"
- Or sign executable with certificate for distribution

### UWP/AppX Limitations

This is a **Win32 desktop app**, not a UWP app:
- ✅ Can access raw sockets
- ✅ No sandboxing restrictions
- ❌ Cannot distribute via Microsoft Store (without UWP conversion)

## Getting Help

If issues persist:

1. Verify firewall allows app
2. Check app is on same network as other devices
3. Temporarily disable firewall to test
4. Check Event Viewer for errors:
   - Press `Win + R` → `eventvwr.msc`
   - Windows Logs → Application

## Tested Configurations

✅ **Confirmed Working**:
- Windows 10 (1809, 20H2, 21H2, 22H2)
- Windows 11 (21H2, 22H2, 23H2)
- Both WiFi and Ethernet
- Intel and AMD processors

⚠️ **Not Supported**:
- Windows 7/8 (Flutter requires Windows 10+)
- Windows Server (untested, may work)
- Windows ARM (untested)
