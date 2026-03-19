<h1>
  <picture>
    <source srcset="images/og_messenger_full.dark.png" media="(prefers-color-scheme: dark)">
    <source srcset="images/og_messenger_full.png" media="(prefers-color-scheme: light)">
    <img align="center" alt="OG Messenger Logo" src="images/og_messenger_full.png" />
  </picture>
  OG Messenger
</h1>

A serverless, cross-platform LAN messenger for private networks. Built with Flutter/Dart for Android, iOS, macOS, Windows, and Linux.

## Features

- 🌐 **Serverless**: No central server required - works entirely on your local network
- 🔍 **Auto-Discovery**: Automatically finds other devices using UDP multicast
- 📱 **Cross-Platform**: Works on Android, iOS, macOS, Windows, and Linux
- � **Encrypted**: RSA/AES hybrid encryption for end-to-end message security
- �🔔 **Notifications**: Get notified when messages arrive while app is in background
- 🗄️ **Message History**: Configurable retention (default 30 days)
- ⚡ **Real-time**: Messages sync instantly across all online devices

## Quick Start

### Installation

1. Clone this repository
2. Ensure you have Flutter installed (3.11.0 or higher)
3. Run `flutter pub get` to install dependencies
4. Follow platform-specific setup instructions below

### Platform Setup

- **[Linux Setup & Troubleshooting](docs/setup/LINUX.md)** - Required multicast configuration
- **[Windows Setup](docs/setup/WINDOWS.md)** - Firewall configuration
- **[macOS Setup](docs/setup/MACOS.md)** - Network entitlements

### Running the App

```bash
# Desktop (macOS/Windows/Linux)
flutter run -d macos    # or windows, linux

# Mobile
flutter run -d <device-id>
```

## How It Works

1. **Device Discovery**: Uses UDP multicast (239.255.42.99:4445) to broadcast presence
2. **Message Delivery**: TCP connections (port 8888+) for reliable message transmission
3. **Synchronization**: UTC timestamps ensure consistent message ordering across devices
4. **Identity**: Each device has a unique UUID; users identify themselves by name

## Requirements

- Same local network (WiFi/Ethernet)
- UDP multicast support (most modern routers)
- Devices must be online to send/receive messages

## Troubleshooting

See [TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md) for common issues and solutions.

## Architecture

- **State Management**: Riverpod
- **Database**: SQLite via sqflite (local storage with automatic cleanup)
- **Networking**: Raw UDP/TCP sockets using dart:io
- **Security**: RSA-2048 key exchange + AES-256-GCM message encryption
- **Notifications**: flutter_local_notifications

## Limitations

- Web platform not supported (browser security restrictions)
- Messages only delivered to online devices
- iOS requires app in foreground or VoIP background mode

## License

MIT License - see [LICENSE](LICENSE) for details.
