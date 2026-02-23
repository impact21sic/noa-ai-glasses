import 'package:flutter/material.dart';
import '../constants/app_constants.dart';

class ActionButtons extends StatelessWidget {
  final VoidCallback onVoice;
  final VoidCallback onPhoto;
  final VoidCallback onClear;
  final bool isLoading;

  const ActionButtons({
    super.key,
    required this.onVoice,
    required this.onPhoto,
    required this.onClear,
    required this.isLoading,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: isLoading ? null : onVoice,
            icon: const Icon(Icons.mic),
            label: Text(AppConstants.strings['voiceTestButton'] ?? 'Voice'),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: isLoading ? null : onPhoto,
            icon: const Icon(Icons.camera_alt),
            label: Text(AppConstants.strings['photoTestButton'] ?? 'Photo'),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: isLoading ? null : onClear,
            icon: const Icon(Icons.delete),
            label: Text(AppConstants.strings['clearButton'] ?? 'Clear'),
          ),
        ),
      ],
    );
  }
}
