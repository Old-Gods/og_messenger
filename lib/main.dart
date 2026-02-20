import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'features/setup/presentation/screens/setup_screen.dart';
import 'features/chat/presentation/screens/chat_screen.dart';
import 'features/settings/presentation/screens/settings_screen.dart';
import 'features/settings/providers/settings_provider.dart';
import 'features/settings/data/services/settings_service.dart';
import 'features/messaging/providers/message_provider.dart';
import 'features/notifications/data/services/notification_service.dart';
import 'features/security/data/services/security_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize notification service
  await NotificationService.instance.initialize();
  await NotificationService.instance.requestPermissions();

  // Initialize security service
  await SecurityService.instance.initialize();

  // Initialize settings service
  await SettingsService.instance.initialize();

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
    final settings = ref.watch(settingsProvider);

    return MaterialApp(
      title: 'OG Messenger',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      themeMode: ThemeMode.system,
      initialRoute: settings.hasUserName ? '/chat' : '/setup',
      routes: {
        '/setup': (context) => const SetupScreen(),
        '/chat': (context) => const ChatScreen(),
        '/settings': (context) => const SettingsScreen(),
      },
    );
  }
}
