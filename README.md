# OG Messenger

<img align="right" width="200" alt="OG Messenger Logo" src="images/og_messenger.dark.png" />

A serverless, cross-platform LAN messenger for private networks. Built with Flutter/Dart for Android, iOS, macOS, Windows, and Linux.

## Features

- 🌐 **Serverless**: No central server required - works entirely on your local network
- 💬 **Single Chatroom**: One shared conversation per network for simplicity
- 🔍 **Auto-Discovery**: Automatically finds other devices using UDP multicast
- 📱 **Cross-Platform**: Works on Android, iOS, macOS, Windows, and Linux
- 🔔 **Notifications**: Get notified when messages arrive while app is in background
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
- **Database**: Isar (local storage with automatic cleanup)
- **Networking**: Raw UDP/TCP sockets using dart:io
- **Notifications**: flutter_local_notifications

## Limitations

- Web platform not supported (browser security restrictions)
- Messages only delivered to online devices
- No end-to-end encryption (designed for trusted private networks)
- iOS requires app in foreground or VoIP background mode

## License

Private project - not for public distribution.

## Version

1.0.0+1

