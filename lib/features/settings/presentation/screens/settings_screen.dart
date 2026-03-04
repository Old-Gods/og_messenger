import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../../../settings/providers/settings_provider.dart';
import '../../../messaging/providers/message_provider.dart';
import '../../../discovery/providers/discovery_provider.dart';

/// Settings screen
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _nameController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  String _version = 'Loading...';

  @override
  void initState() {
    super.initState();
    final settings = ref.read(settingsProvider);
    _nameController.text = settings.userName ?? '';
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    final packageInfo = await PackageInfo.fromPlatform();
    if (mounted) {
      setState(() {
        _version = packageInfo.version;
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _saveName() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final newName = _nameController.text.trim();
      await ref.read(settingsProvider.notifier).setUserName(newName);

      // Update discovery service with new name
      ref.read(discoveryProvider.notifier).updateDeviceName(newName);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: const Text('Name updated successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update name: $e'),
            action: SnackBarAction(label: 'Dismiss', onPressed: () {}),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _showRetentionDialog() async {
    final settings = ref.read(settingsProvider);
    final controller = TextEditingController(
      text: settings.retentionDays.toString(),
    );

    final newDays = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Message Retention'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Days to keep messages',
            helperText: 'Enter 0 for unlimited retention',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              final days =
                  int.tryParse(controller.text) ?? settings.retentionDays;
              Navigator.of(context).pop(days);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (newDays != null && newDays != settings.retentionDays) {
      await ref.read(settingsProvider.notifier).setRetentionDays(newDays);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Retention updated to $newDays days')),
        );
      }
    }
  }

  String _getThemeLabel(String mode) {
    switch (mode) {
      case 'light':
        return 'Light';
      case 'dark':
        return 'Dark';
      case 'system':
      default:
        return 'System (Auto)';
    }
  }

  Future<void> _showThemeDialog() async {
    final settings = ref.read(settingsProvider);
    final selectedMode = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Choose Theme'),
        content: RadioGroup<String>(
          groupValue: settings.themeMode,
          onChanged: (value) => Navigator.of(context).pop(value),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              RadioListTile<String>(title: const Text('Light'), value: 'light'),
              RadioListTile<String>(title: const Text('Dark'), value: 'dark'),
              RadioListTile<String>(
                title: const Text('System (Auto)'),
                subtitle: const Text('Follow system theme'),
                value: 'system',
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );

    if (selectedMode != null && selectedMode != settings.themeMode) {
      await ref.read(settingsProvider.notifier).setThemeMode(selectedMode);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Theme changed to ${_getThemeLabel(selectedMode)}'),
          ),
        );
      }
    }
  }

  Future<void> _showEmojiCustomizationDialog() async {
    final settings = ref.read(settingsProvider);
    final currentEmojis = List<String>.from(settings.reactionEmojis);

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Customize Quick Reactions'),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Tap an emoji to remove it. Add button to add new emojis.',
                  style: TextStyle(fontSize: 12),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    // Existing emojis
                    ...currentEmojis.map((emoji) {
                      return InkWell(
                        onTap: () {
                          setState(() {
                            currentEmojis.remove(emoji);
                          });
                        },
                        child: Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.surface,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Theme.of(context).dividerColor,
                            ),
                          ),
                          child: Stack(
                            children: [
                              Center(
                                child: Text(
                                  emoji,
                                  style: const TextStyle(fontSize: 28),
                                ),
                              ),
                              Positioned(
                                top: 2,
                                right: 2,
                                child: Container(
                                  width: 20,
                                  height: 20,
                                  decoration: BoxDecoration(
                                    color: Colors.red,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.close,
                                    size: 14,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                    // Add button
                    if (currentEmojis.length < 10)
                      InkWell(
                        onTap: () async {
                          // Show emoji picker to add new emoji
                          final emoji = await showDialog<String>(
                            context: context,
                            builder: (context) => Dialog(
                              child: SizedBox(
                                height: 400,
                                child: Column(
                                  children: [
                                    AppBar(
                                      title: const Text('Select Emoji'),
                                      automaticallyImplyLeading: false,
                                      actions: [
                                        IconButton(
                                          icon: const Icon(Icons.close),
                                          onPressed: () =>
                                              Navigator.of(context).pop(),
                                        ),
                                      ],
                                    ),
                                    Expanded(
                                      child: Container(), // Placeholder for now
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                          if (emoji != null && !currentEmojis.contains(emoji)) {
                            setState(() {
                              currentEmojis.add(emoji);
                            });
                          }
                        },
                        child: Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            color: Theme.of(
                              context,
                            ).colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                          child: Icon(
                            Icons.add,
                            size: 28,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ),
                  ],
                ),
                if (currentEmojis.length >= 10)
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Text(
                      'Maximum 10 emojis reached',
                      style: TextStyle(fontSize: 12, color: Colors.orange),
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                if (currentEmojis.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Please keep at least one emoji'),
                    ),
                  );
                  return;
                }
                await ref
                    .read(settingsProvider.notifier)
                    .setReactionEmojis(currentEmojis);
                if (context.mounted) {
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Quick reactions updated')),
                  );
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final discoveryState = ref.watch(discoveryProvider);
    final messageState = ref.watch(messageProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          // User Information
          const ListTile(
            title: Text(
              'User Information',
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'Display Name',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.person),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter your name';
                      }
                      if (value.trim().length < 2) {
                        return 'Name must be at least 2 characters';
                      }
                      if (value.trim().length > 50) {
                        return 'Name must be less than 50 characters';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _saveName,
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Save Name'),
                  ),
                ],
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.fingerprint),
            title: const Text('Device ID'),
            subtitle: Text(
              settings.deviceId ?? 'Not set',
              style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
            ),
          ),
          const Divider(),

          // Appearance
          const ListTile(
            title: Text(
              'Appearance',
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.palette),
            title: const Text('Theme'),
            subtitle: Text(_getThemeLabel(settings.themeMode)),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showThemeDialog(),
          ),
          const Divider(),

          // Reactions
          const ListTile(
            title: Text(
              'Reactions',
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.emoji_emotions),
            title: const Text('Quick Reaction Emojis'),
            subtitle: Text(settings.reactionEmojis.join(' ')),
            trailing: const Icon(Icons.edit),
            onTap: _showEmojiCustomizationDialog,
          ),
          const Divider(),

          // Network Information
          const ListTile(
            title: Text(
              'Network Status',
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue),
            ),
          ),
          ListTile(
            leading: Icon(
              discoveryState.isRunning ? Icons.wifi : Icons.wifi_off,
              color: discoveryState.isRunning ? Colors.green : Colors.red,
            ),
            title: const Text('Discovery Service'),
            subtitle: Text(discoveryState.isRunning ? 'Running' : 'Stopped'),
          ),
          ListTile(
            leading: const Icon(Icons.people),
            title: const Text('Connected Peers'),
            subtitle: Text('${discoveryState.peers.length} peers discovered'),
          ),
          if (discoveryState.peers.isNotEmpty)
            ...discoveryState.peers.values.map((peer) {
              return ListTile(
                leading: const Icon(Icons.device_hub, size: 20),
                title: Text(peer.deviceName),
                subtitle: Text('${peer.ipAddress}:${peer.tcpPort}'),
                dense: true,
                contentPadding: const EdgeInsets.only(left: 72, right: 16),
              );
            }),
          const Divider(),

          // Storage Information
          const ListTile(
            title: Text(
              'Storage',
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.storage),
            title: const Text('Message Retention'),
            subtitle: Text(
              settings.retentionDays == 0
                  ? 'Unlimited (messages never deleted)'
                  : '${settings.retentionDays} days',
            ),
            trailing: const Icon(Icons.edit),
            onTap: _showRetentionDialog,
          ),
          ListTile(
            leading: const Icon(Icons.message),
            title: const Text('Total Messages'),
            subtitle: Text('${messageState.messages.length} messages'),
          ),
          const Divider(),

          // About
          const ListTile(
            title: Text(
              'About',
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.info),
            title: const Text('OG Messenger'),
            subtitle: Text('Serverless LAN Messenger\nVersion $_version'),
          ),
        ],
      ),
    );
  }
}
