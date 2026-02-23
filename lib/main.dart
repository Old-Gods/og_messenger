import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'features/rooms/presentation/screens/room_list_screen.dart';
import 'features/chat/presentation/screens/chat_screen.dart';
import 'features/settings/presentation/screens/settings_screen.dart';
import 'features/settings/presentation/screens/username_prompt_screen.dart';
import 'features/settings/data/services/settings_service.dart';
import 'features/settings/providers/settings_provider.dart';
import 'features/messaging/providers/message_provider.dart';
import 'features/notifications/data/services/notification_service.dart';
import 'features/security/data/services/security_service.dart';
import 'features/rooms/data/services/room_service.dart';
import 'features/rooms/providers/room_provider.dart';

/// Global navigator key for handling navigation from anywhere (e.g., notifications)
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize notification service
  await NotificationService.instance.initialize();
  await NotificationService.instance.requestPermissions();

  // Initialize security service (RSA keys persisted)
  await SecurityService.instance.initialize();

  // Initialize settings service
  await SettingsService.instance.initialize();

  // Initialize room service
  await RoomService.instance.initialize();

  runApp(const ProviderScope(child: OGMessengerApp()));
}

class OGMessengerApp extends ConsumerStatefulWidget {
  const OGMessengerApp({super.key});

  @override
  ConsumerState<OGMessengerApp> createState() => _OGMessengerAppState();
}

class _OGMessengerAppState extends ConsumerState<OGMessengerApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Set up notification tap handling
    NotificationService.instance.setNavigationCallback((roomId) {
      _navigateToRoom(roomId);
    });

    // Initialize settings provider (including network ID detection)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      print('🚀 Triggering settings provider initialization from main.dart');
      ref.read(settingsProvider.notifier).initialize();
    });
  }

  /// Navigate to a specific room
  void _navigateToRoom(String roomId) {
    // Get the room provider to switch active room
    final roomNotifier = ref.read(roomProvider.notifier);

    // Switch to the room
    roomNotifier.switchActiveRoom(roomId);

    // Navigate to chat screen using the global navigator key
    navigatorKey.currentState?.pushNamed('/chat');
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    // Update message provider with app state
    final isInForeground = state == AppLifecycleState.resumed;
    ref.read(messageProvider.notifier).setAppInForeground(isInForeground);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'OG Messenger',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          surface: Colors.white,
        ),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.dark,
          surface: Colors.black,
        ),
        useMaterial3: true,
      ),
      themeMode: ThemeMode.system,
      home: const UsernamePromptScreen(child: RoomListScreen()),
      routes: {
        '/chat': (context) => const ChatScreen(),
        '/settings': (context) => const SettingsScreen(),
      },
    );
  }
}

/// Router widget that handles navigation after username is set
/// (Kept for reference but no longer used)
class _AppRouter extends StatelessWidget {
  const _AppRouter();

  @override
  Widget build(BuildContext context) {
    return Navigator(
      onGenerateRoute: (settings) {
        switch (settings.name) {
          case '/chat':
            return MaterialPageRoute(builder: (_) => const ChatScreen());
          case '/settings':
            return MaterialPageRoute(builder: (_) => const SettingsScreen());
          default:
            return MaterialPageRoute(builder: (_) => const RoomListScreen());
        }
      },
    );
  }
}
