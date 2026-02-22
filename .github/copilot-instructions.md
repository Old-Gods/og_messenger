# OG Messenger - AI Coding Agent Instructions

## Project Overview

OG Messenger is a **serverless, cross-platform LAN messenger** built with Flutter/Dart. It uses UDP multicast for peer discovery and TCP for reliable message delivery, with RSA/AES hybrid encryption for security. No central server required - all communication happens peer-to-peer on the local network.

**Key characteristics**: Real-time messaging, auto-discovery, configurable message retention (SQLite), cross-platform (Android/iOS/macOS/Windows/Linux), notification support.

## Architecture & Project Structure

### Feature-Based Organization

The codebase follows **feature-based modular architecture** with clean separation of concerns:

```
lib/
├── main.dart                    # App entry, service initialization
├── core/                        # Shared utilities, constants
│   ├── constants/              # Network/app constants
│   ├── services/               # Platform channels (MulticastLockService)
│   └── utils/                  # Color utilities, extensions
└── features/                    # Feature modules (domain-driven)
    ├── chat/                   # UI screens (ChatScreen, SyncScreen)
    ├── discovery/              # Peer discovery entities/providers
    ├── messaging/              # Message handling (entities, repo, TCP server)
    ├── network/                # Network info service
    ├── notifications/          # Local notifications service
    ├── security/               # RSA/AES encryption service
    ├── settings/               # Settings service & provider
    ├── setup/                  # First-launch setup screen
    └── storage/                # Database service (SQLite)
```

### Layer Responsibilities Within Features

- **`domain/entities/`**: Core business objects (Message, Peer) - pure Dart, no dependencies
- **`data/repositories/`**: Data access layer (MessageRepository)
- **`data/services/`**: Singleton services for specific concerns (TcpServerService, SecurityService)
- **`providers/`**: Riverpod state management (NotifierProvider pattern, NO code generation)
- **`presentation/screens/`**: UI components (ConsumerWidget/ConsumerStatefulWidget)

## Critical Patterns & Conventions

### 1. Service Pattern - Singleton Instances

All core services use the singleton pattern with private constructors:

```dart
class SecurityService {
  static final SecurityService instance = SecurityService._();
  SecurityService._();
  
  Future<void> initialize() async { /* ... */ }
}
```

**Usage**: Always access via `ServiceName.instance` (e.g., `SecurityService.instance.encryptMessage()`). Services must be initialized in `main.dart` before app launch.

### 2. Riverpod State Management

**Pattern**: Use `NotifierProvider` (NOT code generation) with explicit provider definitions:

```dart
final messageProvider = NotifierProvider<MessageNotifier, MessageState>(
  () => MessageNotifier(),
);

class MessageNotifier extends Notifier<MessageState> {
  @override
  MessageState build() => MessageState.initial();
  // Methods for state mutations...
}
```

**Key providers**:
- `messageProvider` - Message state, sending/receiving logic
- `settingsProvider` - User settings, network ID detection
- `discoveryProvider` - Active peer list

**UI usage**: Use `ConsumerWidget` or `ConsumerStatefulWidget`, never `StatefulWidget` alone.

### 3. Security Architecture

**Critical flow understanding**:
1. **First user** creates password → generates RSA-2048 key pair → generates AES-256 key
2. **Subsequent users** discover authenticated peer → enter same password → receive encrypted AES key via RSA
3. **All messages** encrypted with shared AES-256-GCM key
4. **Authentication cleared** on every app restart (by design - see `main.dart`)

**Services involved**:
- `SecurityService.instance` - RSA/AES operations, password hashing (SHA-256)
- `TcpServerService.instance` - Handles auth request/response streams separately from messages

### 4. Network Protocol

**Discovery (UDP multicast)**:
- Address: `239.255.42.99:4445` (see [NetworkConstants](lib/core/constants/network_constants.dart))
- Beacons every 3 seconds with: `deviceId`, `username`, `tcpPort`, `publicKey`
- Peers timeout after 7 seconds without beacon

**Messaging (TCP)**:
- Ports: 8888-8987 (auto-increment on collision)
- Protocol: **Newline-delimited JSON** with per-connection buffering
- Max message size: 10KB
- Message types: `message`, `sync_request`, `auth_request`, `auth_response`, `typing`, `name_change`

### 5. Database & Message Retention

- **Engine**: SQLite via `sqflite` package
- **Service**: `DatabaseService.instance` (singleton)
- **Retention**: Configurable 7-90 days (default 30), auto-cleanup on queries
- **Indexes**: On `timestamp`, `sender_id`, unique `(uuid, sender_id)`
- **Repository pattern**: `MessageRepository` wraps `DatabaseService` for message operations

## Development Workflows

### Building

```bash
# Desktop platforms
flutter run -d macos     # or windows, linux
flutter build macos --release --no-codesign

# Mobile platforms  
flutter run -d <device-id>
flutter build ios --release --no-codesign
flutter build apk --release
```

### Testing

```bash
flutter test                    # Run all tests
flutter test test/features/     # Run feature tests
```

**Test structure**: Mirrors `lib/` structure. Uses `mocktail` for mocking. See [test/README.md](test/README.md) for detailed patterns.

**Test helpers**: `test/helpers/test_helpers.dart` provides `setupMockSharedPreferences()` for service tests.

### Code Generation

**NOT used** - No `build_runner`, `freezed`, or Riverpod codegen. All providers are explicitly defined.

**Exception**: `json_serializable` is available for model serialization if needed, run: `flutter pub run build_runner build`

### Platform-Specific Setup

**Critical requirements**:
- **Android**: Multicast lock via platform channel (see `MulticastLockService`, `android/app/src/main/kotlin/`)
- **Linux**: Multicast routing configuration required (see [docs/setup/LINUX.md](docs/setup/LINUX.md))
- **iOS/macOS**: Network entitlements in `.entitlements` files
- **Windows**: Firewall configuration for UDP/TCP

See `docs/setup/` for detailed platform guides.

## Important Constraints & Design Decisions

1. **No web support** - Browser security restrictions prevent raw UDP/TCP sockets
2. **Serverless by design** - All communication is peer-to-peer on LAN
3. **No message history sync** - New devices don't receive past messages (retention is local only)
4. **Authentication ephemeral** - Must re-authenticate on every app launch (security by design)
5. **Shared AES key** - All authenticated peers use same encryption key (appropriate for trusted local networks)
6. **Broadcast only** - All messages go to all online peers (no direct messaging yet)

## Common Tasks

### Adding a New Feature

1. Create feature folder under `lib/features/<feature_name>/`
2. Add `domain/entities/` for core models (pure Dart)
3. Add `data/services/` for business logic (singleton pattern if stateful)
4. Add `providers/` for Riverpod state (NotifierProvider pattern)
5. Add `presentation/screens/` for UI (ConsumerWidget)
6. Mirror structure in `test/features/<feature_name>/`

### Adding a New Message Type

1. Add type constant to message protocol (e.g., in `Message` entity or protocol docs)
2. Update `TcpServerService._handleData()` with new message type handling
3. Add new `StreamController` in `TcpServerService` if needed
4. Update `MessageProvider` to listen/handle the new type
5. Add encryption/decryption if message contains sensitive data

### Modifying Network Constants

Edit [lib/core/constants/network_constants.dart](lib/core/constants/network_constants.dart). Key values:
- Multicast address/port (must match across all devices)
- TCP port range
- Timing values (beacon interval, peer timeout, typing timeout)

### Debugging Network Issues

1. Check `TcpServerService.errorStream` for TCP errors
2. Check `UdpDiscoveryService.errorStream` for discovery errors  
3. Verify multicast routing (especially on Linux)
4. Check firewall settings (see [docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md))
5. Use `flutter run --verbose` for detailed logs

## Code Style & Linting

- **Linter**: `flutter_lints` package (see [analysis_options.yaml](analysis_options.yaml))
- **Print statements allowed** for debugging (`avoid_print: false`)
- **Const constructors**: Use `const` wherever possible for performance
- **Riverpod**: Prefer `ref.read()` for one-time reads, `ref.watch()` for reactive updates
- **Early returns**: Prefer early returns over nested conditionals

## Key Files Reference

- [lib/main.dart](lib/main.dart) - App initialization, service setup order
- [README.md](README.md) - Project overview, quick start
- [IMPLEMENTATION.md](IMPLEMENTATION.md) - Detailed implementation notes, security architecture, edge cases
- [lib/core/constants/network_constants.dart](lib/core/constants/network_constants.dart) - Network protocol constants
- [lib/features/messaging/providers/message_provider.dart](lib/features/messaging/providers/message_provider.dart) - Message state management logic
- [lib/features/security/data/services/security_service.dart](lib/features/security/data/services/security_service.dart) - RSA/AES encryption implementation
