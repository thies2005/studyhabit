import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/services/account_prompt_service.dart';

class AccountPromptDialog extends StatelessWidget {
  final PromptType type;

  const AccountPromptDialog({
    super.key,
    required this.type,
  });

  static Future<void> show(BuildContext context, PromptType type) {
    return showDialog(
      context: context,
      barrierDismissible: type == PromptType.soft, // Soft prompt is dismissible, strong prompt is more persistent
      builder: (context) => AccountPromptDialog(type: type),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isSoft = type == PromptType.soft;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      icon: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.colorScheme.primaryContainer.withValues(alpha: 0.4),
          shape: BoxShape.circle,
        ),
        child: Icon(
          isSoft ? Icons.cloud_outlined : Icons.security_outlined,
          size: 40,
          color: theme.colorScheme.primary,
        ),
      ),
      title: Text(
        isSoft ? 'Track Across Devices' : 'Protect Your Progress! 🛡️',
        textAlign: TextAlign.center,
        style: theme.textTheme.headlineSmall?.copyWith(
          fontWeight: FontWeight.bold,
        ),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            isSoft
                ? "You've studied for over 5 hours! 🎉 Create a free account to sync your study habit across devices and never lose your progress."
                : "Wow, over 20 hours of hard work! 🚀 Don't risk losing your study history, streaks, and achievements. Secure them to the cloud right now.",
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(height: 1.4),
          ),
          const SizedBox(height: 12),
          Text(
            'It takes less than a minute.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.secondary,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
      actionsAlignment: MainAxisAlignment.spaceEvenly,
      actionsPadding: const EdgeInsets.only(bottom: 20, left: 16, right: 16),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(
            isSoft ? 'Maybe Later' : 'Not Now',
            style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
          ),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: theme.colorScheme.primary,
            foregroundColor: theme.colorScheme.onPrimary,
            elevation: 2,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
          onPressed: () {
            Navigator.of(context).pop();
            context.push('/settings/login');
          },
          child: const Text(
            'Create Account',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }
}
