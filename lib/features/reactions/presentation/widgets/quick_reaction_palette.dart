import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import '../../../settings/providers/settings_provider.dart';

/// Quick reaction palette widget with customizable emoji and full picker
class QuickReactionPalette extends ConsumerStatefulWidget {
  final Function(String emoji) onEmojiSelected;

  const QuickReactionPalette({super.key, required this.onEmojiSelected});

  @override
  ConsumerState<QuickReactionPalette> createState() =>
      _QuickReactionPaletteState();
}

class _QuickReactionPaletteState extends ConsumerState<QuickReactionPalette> {
  bool _showFullPicker = false;

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final quickEmojis = settings.reactionEmojis;

    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!_showFullPicker) ...[
            // Title
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Quick Reactions',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Quick emoji grid
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                // Quick emoji buttons
                ...quickEmojis.map((emoji) => _buildEmojiButton(emoji)),
                // "+" button to open full picker
                _buildMoreButton(),
              ],
            ),
          ] else ...[
            // Full emoji picker
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () {
                    setState(() {
                      _showFullPicker = false;
                    });
                  },
                ),
                const Text(
                  'All Emojis',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 300,
              child: EmojiPicker(
                onEmojiSelected: (category, emoji) {
                  widget.onEmojiSelected(emoji.emoji);
                  Navigator.of(context).pop();
                },
                config: Config(
                  height: 300,
                  checkPlatformCompatibility: true,
                  emojiViewConfig: EmojiViewConfig(
                    columns: 7,
                    emojiSizeMax: 28,
                    verticalSpacing: 0,
                    horizontalSpacing: 0,
                    gridPadding: EdgeInsets.zero,
                    backgroundColor: Theme.of(context).scaffoldBackgroundColor,
                  ),
                  skinToneConfig: const SkinToneConfig(),
                  categoryViewConfig: const CategoryViewConfig(),
                  bottomActionBarConfig: const BottomActionBarConfig(
                    enabled: false,
                  ),
                  searchViewConfig: const SearchViewConfig(),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEmojiButton(String emoji) {
    return InkWell(
      onTap: () {
        widget.onEmojiSelected(emoji);
        Navigator.of(context).pop();
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Theme.of(context).dividerColor, width: 1),
        ),
        child: Center(child: Text(emoji, style: const TextStyle(fontSize: 28))),
      ),
    );
  }

  Widget _buildMoreButton() {
    return InkWell(
      onTap: () {
        setState(() {
          _showFullPicker = true;
        });
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primaryContainer,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Theme.of(context).colorScheme.primary,
            width: 1,
          ),
        ),
        child: Center(
          child: Icon(
            Icons.add,
            size: 28,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
      ),
    );
  }
}

/// Helper function to show the quick reaction palette
Future<void> showQuickReactionPalette({
  required BuildContext context,
  required Function(String emoji) onEmojiSelected,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => Container(
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: QuickReactionPalette(onEmojiSelected: onEmojiSelected),
    ),
  );
}
