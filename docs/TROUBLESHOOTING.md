# Troubleshooting Guide

Common issues and solutions for OG Messenger.

## Connection Issues

### Cannot discover other devices

**Symptoms**: App shows "0 peers online" even though other devices are on the same network.

**Possible Causes & Solutions**:

1. **Different WiFi Networks**
   - Ensure all devices are on the same network
   - Check for guest networks or isolated VLANs
   
2. **Router Blocking Multicast**
   - Some routers disable multicast by default
   - Check router settings for IGMP/Multicast configuration
   - Try connecting all devices to a different network
   
3. **Firewall Blocking UDP**
   - See platform-specific setup guides
   - Ensure UDP port 4445 is allowed
   
4. **VPN Interference**
   - Disable VPN on all devices
   - VPNs can route traffic through different networks

### Messages not sending

**Symptoms**: Messages stuck in "sending" state or not appearing on other devices.

**Possible Causes & Solutions**:

1. **TCP Port Blocked**
   - Check firewall allows TCP ports 8888-8987
   - App will auto-increment if port is busy
   
2. **Device Went Offline**
   - Check network connection
   - App requires continuous connection
   
3. **Message Too Large**
   - Maximum message size is 10KB
   - Check character counter below input field

## Performance Issues

### High Battery Drain (Mobile)

**Solution**: Background discovery uses battery. Consider:
- Keep app in foreground when actively chatting
- Close app when not in use
- On Android: Ensure multicast lock is released when backgrounded

### Slow Message Delivery

**Possible Causes**:
- Poor WiFi signal strength
- Network congestion
- Too many devices on network

**Solutions**:
- Move closer to WiFi router
- Reduce network traffic
- Use 5GHz WiFi if available

## Platform-Specific Issues

### Linux

See [Linux Setup Guide](setup/LINUX.md) for detailed troubleshooting.

**Quick Checks**:
```bash
# Verify multicast is enabled
ip maddress show

# Check for multicast route
ip route show | grep 239

# Test multicast reception
tcpdump -i any 'udp and dst host 239.255.42.99'
```

### Windows

**Windows Firewall Prompt**:
- Click "Allow" when prompted on first run
- If blocked, manually allow in Windows Defender Firewall settings

**No Firewall Prompt**:
- Open Windows Defender Firewall
- Click "Allow an app through firewall"
- Add og_messenger.exe manually

### macOS

**Local Network Permission**:
- macOS 14+ requires local network permission
- Grant permission when prompted
- Check System Settings > Privacy & Security > Local Network

### iOS

**Background Limitations**:
- iOS suspends apps after ~10 seconds in background
- Keep app in foreground for active messaging
- VoIP background mode helps but has limitations

**Local Network Permission**:
- iOS 14+ requires explicit permission
- Tap "OK" when prompted
- Check Settings > Privacy > Local Network > OG Messenger

### Android

**Multicast Not Working**:
```kotlin
// Ensure multicast lock is acquired
// Should happen automatically, but check logs for errors
```

**Battery Optimization**:
- Some manufacturers aggressively kill background apps
- Disable battery optimization for OG Messenger
- Settings > Apps > OG Messenger > Battery > Unrestricted

## Data Issues

### Messages Not Appearing After Reopening App

**Cause**: Messages older than retention period are automatically deleted.

**Solution**: 
- Check Settings > Retention Period
- Increase from default 30 days if needed
- Range: 7-90 days

### Storage Growing Too Large

**Solution**:
- Decrease retention period in Settings
- Old messages are automatically cleaned daily
- Manual: Uninstall and reinstall app (clears all data)

## Error Messages

### "Failed to bind to TCP port"

**Meaning**: All ports from 8888-8987 are in use.

**Solutions**:
- Close other apps using these ports
- Restart device
- Check for zombie processes: `lsof -i :8888-8987` (macOS/Linux)

### "Multicast lock acquisition failed" (Android)

**Meaning**: Cannot acquire WiFi multicast lock.

**Solutions**:
- Grant all requested permissions
- Ensure WiFi is enabled (not just mobile data)
- Try restarting app

### "Network permission denied" (iOS/macOS)

**Meaning**: Local network permission not granted.

**Solutions**:
- Go to Settings > Privacy > Local Network
- Enable permission for OG Messenger
- Restart app

## Debug Mode

To enable detailed logging:

1. Run app from IDE (VS Code, Android Studio)
2. Check debug console for network events
3. Look for:
   - "UDP Discovery: Beacon sent"
   - "TCP Server: Bound to port XXXX"
   - "Peer discovered: [device-id]"
   - "Message sent/received"

## Getting Help

If issues persist:

1. Check all devices are on same network
2. Verify permissions are granted
3. Review platform-specific setup guide
4. Try with just 2 devices first
5. Check router doesn't isolate clients

## Known Limitations

- **Web**: Not supported (browser security model incompatible)
- **iOS Background**: Limited to VoIP mode or foreground only
- **Offline**: No message queuing - must be online to send/receive
- **Security**: No encryption - use on trusted private networks only
