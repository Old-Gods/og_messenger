# Linux Setup & Troubleshooting

Complete guide for running OG Messenger on Linux systems.

## Prerequisites

- Flutter 3.11.0 or higher
- Linux desktop environment (Ubuntu, Fedora, Arch, etc.)
- Active network connection (WiFi or Ethernet)

## Initial Setup

### 1. Install Dependencies

OG Messenger should work out of the box on most Linux distributions, but ensure you have:

```bash
# Ubuntu/Debian
sudo apt-get install libnotify-dev

# Fedora
sudo dnf install libnotify-devel

# Arch
sudo pacman -S libnotify
```

### 2. Build and Run

```bash
flutter pub get
flutter run -d linux
```

## Multicast Configuration

Linux requires proper multicast routing to discover peers. This is the **most common issue**.

### Check Multicast Status

```bash
# Verify MULTICAST flag is enabled on your network interface
ifconfig
# or
ip addr show

# Look for: MULTICAST in flags
# Example: <UP,BROADCAST,RUNNING,MULTICAST>
```

### Check Current Multicast Groups

```bash
# Show multicast group memberships
ip maddress show

# Show multicast groups using netstat
netstat -g
```

### Add Multicast Route

If multicast doesn't work, add a route for the multicast range:

```bash
# For WiFi (replace wlan0 with your interface name)
sudo ip route add 239.0.0.0/8 dev wlan0

# For Ethernet
sudo ip route add 239.0.0.0/8 dev eth0

# Verify route was added
ip route show | grep 239
```

**Make Permanent** (survives reboot):

Ubuntu/Debian - Edit `/etc/network/interfaces`:
```bash
# For WiFi interface
auto wlan0
iface wlan0 inet dhcp
    post-up ip route add 239.0.0.0/8 dev wlan0
```

Or create `/etc/network/if-up.d/multicast-route`:
```bash
#!/bin/bash
ip route add 239.0.0.0/8 dev $IFACE
```

Make executable:
```bash
sudo chmod +x /etc/network/if-up.d/multicast-route
```

### Find Your Network Interface

```bash
# List all network interfaces
ip link show

# Common interface names:
# - wlan0, wlp2s0: WiFi
# - eth0, enp3s0: Ethernet
# - lo: Loopback (ignore this)
# - docker0: Docker (may interfere)

# Show which interface has internet
ip route get 8.8.8.8
```

## Firewall Configuration

### UFW (Ubuntu/Debian)

```bash
# Allow UDP multicast
sudo ufw allow from 239.0.0.0/8
sudo ufw allow 4445/udp

# Allow TCP for message delivery
sudo ufw allow 8888:8987/tcp

# Check status
sudo ufw status verbose
```

### firewalld (Fedora/RHEL/CentOS)

```bash
# Allow multicast
sudo firewall-cmd --permanent --add-rich-rule='rule family="ipv4" destination address="239.0.0.0/8" accept'

# Allow UDP discovery port
sudo firewall-cmd --permanent --add-port=4445/udp

# Allow TCP message ports
sudo firewall-cmd --permanent --add-port=8888-8987/tcp

# Reload firewall
sudo firewall-cmd --reload

# Verify
sudo firewall-cmd --list-all
```

### iptables (Advanced)

```bash
# Allow multicast input
sudo iptables -A INPUT -d 239.255.42.99/32 -j ACCEPT

# Allow multicast output
sudo iptables -A OUTPUT -d 239.255.42.99/32 -j ACCEPT

# Allow UDP discovery port
sudo iptables -A INPUT -p udp --dport 4445 -j ACCEPT

# Allow TCP message ports
sudo iptables -A INPUT -p tcp --dport 8888:8987 -j ACCEPT

# Save rules (Ubuntu/Debian)
sudo iptables-save > /etc/iptables/rules.v4

# Save rules (Fedora/RHEL)
sudo service iptables save
```

## Common Issues

### Issue: "Cannot discover peers"

**Diagnosis**:
```bash
# 1. Check if multicast route exists
ip route show | grep 239

# 2. Verify interface supports multicast
ip link show | grep MULTICAST

# 3. Test multicast reception
sudo tcpdump -i any 'udp and dst host 239.255.42.99 and port 4445'
# Leave this running and start the app on another device
```

**Solutions**:
1. Add multicast route (see above)
2. Check firewall isn't blocking UDP 4445
3. Verify not using VPN
4. Ensure WiFi interface is active

### Issue: Docker Interface Interference

**Symptom**: Multicast traffic goes to `docker0` instead of WiFi/Ethernet.

**Diagnosis**:
```bash
# Check routing priority
ip route show

# If docker0 appears before your real interface, it's interfering
```

**Solution**:
```bash
# Temporarily disable Docker
sudo systemctl stop docker

# Or add explicit route with higher priority
sudo ip route add 239.255.42.99/32 dev wlan0 metric 10
```

### Issue: Multiple Network Interfaces

**Symptom**: App binds to wrong interface (VPN, virtual, etc.).

**Solution**: Explicitly specify interface in route:
```bash
# Route multicast only through WiFi
sudo ip route add 239.0.0.0/8 dev wlan0 metric 10

# Remove conflicting routes if needed
sudo ip route del 239.0.0.0/8 dev tun0
```

### Issue: "Permission denied" on UDP socket

**Symptom**: App crashes with socket permission error.

**Solution**: 
- Linux usually doesn't require special permissions for UDP > 1024
- If using port < 1024: Run with elevated privileges (not recommended)
- Check SELinux/AppArmor isn't blocking

**SELinux** (Fedora/RHEL):
```bash
# Temporarily disable to test
sudo setenforce 0

# If that fixes it, create proper policy:
sudo audit2allow -a -M ogmessenger
sudo semodule -i ogmessenger.pp
```

## Testing Multicast

### Send Test Multicast Packet

Terminal 1 (Receiver):
```bash
# Listen for multicast
socat UDP4-RECVFROM:4445,bind=0.0.0.0,ip-add-membership=239.255.42.99:0.0.0.0,fork STDOUT
```

Terminal 2 (Sender):
```bash
# Send test packet
echo "test" | socat - UDP4-DATAGRAM:239.255.42.99:4445
```

If Terminal 1 shows "test", multicast is working!

### Advanced: Use iperf

```bash
# Terminal 1: Start multicast receiver
iperf -s -u -B 239.255.42.99 -i 1

# Terminal 2: Send multicast traffic
iperf -c 239.255.42.99 -u -T 32 -t 3 -i 1
```

## Performance Tips

### Reduce CPU Usage

OG Messenger sends UDP beacons every 3 seconds. On low-power devices:
- Close app when not in use
- Consider increasing beacon interval (requires code modification)

### Network Performance

```bash
# Check for packet loss
netstat -su | grep -i error

# Monitor multicast traffic
tcpdump -i any 'ip multicast' -c 100

# Check UDP buffer sizes
sysctl net.core.rmem_default
sysctl net.core.rmem_max
```

## Distribution-Specific Notes

### Ubuntu/Debian
- Works out of the box after multicast route setup
- UFW firewall is common, configure as shown above

### Fedora/RHEL
- firewalld is default, configure as shown above
- SELinux may require policy (see above)

### Arch Linux
- Minimal by default, ensure `libnotify` installed
- Usually no firewall, add `ufw` or `firewalld` if needed

### Pop!_OS/System76
- Based on Ubuntu, same as Ubuntu instructions
- Disable VPN in Settings if installed

## Logging & Debug

### Enable Verbose Logging

Run from terminal to see detailed logs:
```bash
flutter run -d linux -v
```

### Check System Logs

```bash
# View app logs
journalctl -f | grep og_messenger

# Network-related logs
dmesg | grep -i network
```

### Network Diagnostics

```bash
# Show active connections
ss -tunap | grep -E '(4445|888[0-9])'

# Monitor network in real-time
watch -n 1 'ss -s'

# Detailed interface stats
ip -s link show wlan0
```

## Uninstallation

```bash
# Remove app data
rm -rf ~/.local/share/og_messenger
rm -rf ~/.config/og_messenger

# Remove multicast route (if added)
sudo ip route del 239.0.0.0/8

# Remove firewall rules (UFW example)
sudo ufw delete allow from 239.0.0.0/8
sudo ufw delete allow 4445/udp
sudo ufw delete allow 8888:8987/tcp
```

## Getting Help

If issues persist after following this guide:

1. Run diagnostic commands from "Testing Multicast" section
2. Check `flutter doctor` output
3. Verify Linux kernel supports multicast: `grep CONFIG_IP_MULTICAST /boot/config-$(uname -r)`
4. Try on different network to rule out router issues
5. Test with 2 Linux devices first before cross-platform

## Known Working Configurations

✅ **Confirmed Working**:
- Ubuntu 22.04+ (GNOME/KDE)
- Fedora 38+
- Arch Linux (latest)
- Pop!_OS 22.04+
- Linux Mint 21+

⚠️ **Known Issues**:
- WSL2: Networking is complex, use native Windows build instead
- Virtual machines: May need bridged networking mode
- Container environments: Docker/LXC require host networking mode
