import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../core/services/app_logger.dart';

class DiagnosticLogsScreen extends StatefulWidget {
  const DiagnosticLogsScreen({super.key});

  @override
  State<DiagnosticLogsScreen> createState() => _DiagnosticLogsScreenState();
}

class _DiagnosticLogsScreenState extends State<DiagnosticLogsScreen> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final logs = AppLogger.logs;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Diagnostic Logs'),
        actions: [
          IconButton(
            icon: const Icon(Icons.copy_all),
            tooltip: 'Copy All Logs',
            onPressed: () async {
              final text = AppLogger.copyableText();
              await Clipboard.setData(ClipboardData(text: text));
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Logs copied to clipboard')),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Clear Logs',
            onPressed: () {
              setState(() {
                AppLogger.clear();
              });
            },
          ),
        ],
      ),
      body: logs.isEmpty
          ? const Center(child: Text('No logs captured yet'))
          : ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: logs.length,
              itemBuilder: (context, index) {
                final log = logs[index];
                final color = _getLogLevelColor(log.level, colorScheme);

                return ExpansionTile(
                  leading: Icon(Icons.label_important, color: color, size: 20),
                  title: Text(
                    log.message,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(
                    '${DateFormat('HH:mm:ss.SSS').format(log.timestamp)} • ${log.tag}',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  expandedCrossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (log.error != null) ...[
                      const Text(
                        'Error:',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                      Text(
                        log.error!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontFamily: 'monospace',
                          color: colorScheme.error,
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                    if (log.stackTrace != null) ...[
                      const Text(
                        'Stack Trace:',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                      Text(
                        log.stackTrace!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontFamily: 'monospace',
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ],
                );
              },
            ),
    );
  }

  Color _getLogLevelColor(LogLevel level, ColorScheme colorScheme) {
    switch (level) {
      case LogLevel.info:
        return Colors.blue;
      case LogLevel.warning:
        return Colors.orange;
      case LogLevel.error:
        return colorScheme.error;
    }
  }
}
