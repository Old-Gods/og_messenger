import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/settings_provider.dart';

/// Screen to prompt user for username on first launch
class UsernamePromptScreen extends ConsumerStatefulWidget {
  final Widget child;

  const UsernamePromptScreen({required this.child, super.key});

  @override
  ConsumerState<UsernamePromptScreen> createState() =>
      _UsernamePromptScreenState();
}

class _UsernamePromptScreenState extends ConsumerState<UsernamePromptScreen> {
  final _controller = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submitUsername() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    final username = _controller.text.trim();
    await ref.read(settingsProvider.notifier).setUserName(username);

    if (mounted) {
      setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);

    // If username is set, show the child widget
    if (settings.userName != null && settings.userName!.isNotEmpty) {
      return widget.child;
    }

    // Otherwise, show username prompt dialog
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Card(
            elevation: 8,
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.person_add,
                        size: 64,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'Welcome to OG Messenger',
                        style: Theme.of(context).textTheme.headlineSmall,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Please enter your display name to get started',
                        style: Theme.of(context).textTheme.bodyMedium,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 32),
                      TextFormField(
                        controller: _controller,
                        decoration: const InputDecoration(
                          labelText: 'Display Name',
                          hintText: 'Enter your name',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.person),
                        ),
                        maxLength: 30,
                        textCapitalization: TextCapitalization.words,
                        autofocus: true,
                        enabled: !_isSubmitting,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter a display name';
                          }
                          if (value.trim().length < 2) {
                            return 'Name must be at least 2 characters';
                          }
                          return null;
                        },
                        onFieldSubmitted: (_) => _submitUsername(),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _isSubmitting ? null : _submitUsername,
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          child: _isSubmitting
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text(
                                  'Continue',
                                  style: TextStyle(fontSize: 16),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
