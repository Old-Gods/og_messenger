import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../../../settings/providers/settings_provider.dart';
import '../../../messaging/providers/message_provider.dart';
import '../../../discovery/providers/discovery_provider.dart';
import '../../../security/data/services/security_service.dart';
import '../../../settings/data/services/settings_service.dart';

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
          const SnackBar(content: Text('Name updated successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to update name: $e')));
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

  Future<void> _showClearMessagesDialog() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear All Messages'),
        content: const Text(
          'Are you sure you want to delete all messages? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Clear'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref.read(messageProvider.notifier).clearAllMessages();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('All messages cleared')));
      }
    }
  }

  Future<void> _showClearAuthDataDialog() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Auth Data'),
        content: const Text(
          'This will clear all authentication data including password, encryption keys, and messages.\n\nYou will need to set up the app again. This is useful after app reinstalls or updates that cause authentication issues.\n\nAre you sure you want to continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Clear All'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        // Clear all auth and app data
        await SecurityService.instance.clearSecurityData();
        await SettingsService.instance.clearUserData();
        await ref.read(messageProvider.notifier).clearAllMessages();

        if (mounted) {
          // Navigate back to setup screen
          Navigator.of(
            context,
            rootNavigator: true,
          ).pushReplacementNamed('/setup');
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to clear auth data: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
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
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: ElevatedButton.icon(
              onPressed: _showClearMessagesDialog,
              icon: const Icon(Icons.delete_sweep),
              label: const Text('Clear All Messages'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
            ),
          ),
          const Divider(),

          // Security
          const ListTile(
            title: Text(
              'Security',
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: ElevatedButton.icon(
              onPressed: _showClearAuthDataDialog,
              icon: const Icon(Icons.delete_forever),
              label: const Text('Clear Auth Data'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepOrange,
                foregroundColor: Colors.white,
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Clears all authentication data, encryption keys, and messages. Use this after reinstalls or updates if you have authentication issues.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
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
