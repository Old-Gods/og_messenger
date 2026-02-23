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

    // Initialize settings provider (including network ID detection)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      print('🚀 Triggering settings provider initialization from main.dart');
      ref.read(settingsProvider.notifier).initialize();
    });
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
      home: const UsernamePromptScreen(child: _AppRouter()),
    );
  }
}

/// Router widget that handles navigation after username is set
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
