import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'features/setup/presentation/screens/setup_screen.dart';
import 'features/chat/presentation/screens/chat_screen.dart';
import 'features/settings/presentation/screens/settings_screen.dart';
import 'features/settings/providers/settings_provider.dart';
import 'features/notifications/data/services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize notification service
  await NotificationService.instance.initialize();
  await NotificationService.instance.requestPermissions();

  runApp(const ProviderScope(child: OGMessengerApp()));
}

class OGMessengerApp extends ConsumerStatefulWidget {
  const OGMessengerApp({super.key});

  @override
  ConsumerState<OGMessengerApp> createState() => _OGMessengerAppState();
}

class _OGMessengerAppState extends ConsumerState<OGMessengerApp> {
  @override
  void initState() {
    super.initState();
    // Initialize settings
    Future.microtask(() async {
      await ref.read(settingsProvider.notifier).initialize();
    });
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
      home: settings.hasUserName ? const ChatScreen() : const SetupScreen(),
      routes: {
        '/setup': (context) => const SetupScreen(),
        '/chat': (context) => const ChatScreen(),
        '/settings': (context) => const SettingsScreen(),
      },
    );
  }
}
