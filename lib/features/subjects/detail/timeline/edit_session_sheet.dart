import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' show Value;
import 'package:intl/intl.dart';

import '../../../../core/database/daos/session_dao.dart';
import '../../../../core/models/study_session.dart';
import '../../../../core/providers/database_provider.dart';

class EditSessionSheet extends ConsumerStatefulWidget {
  const EditSessionSheet({super.key, required this.session});

  final StudySession session;

  static Future<void> show(BuildContext context, {required StudySession session}) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => EditSessionSheet(session: session),
    );
  }

  @override
  ConsumerState<EditSessionSheet> createState() => _EditSessionSheetState();
}

class _EditSessionSheetState extends ConsumerState<EditSessionSheet> {
  late TextEditingController _durationController;
  late TextEditingController _notesController;
  late DateTime _startedAt;
  int? _confidence;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _durationController = TextEditingController(
      text: widget.session.actualDurationMinutes.toString(),
    );
    _notesController = TextEditingController(text: widget.session.notes);
    _startedAt = widget.session.startedAt;
    _confidence = widget.session.confidenceRating;
  }

  @override
  void dispose() {
    _durationController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickDateTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _startedAt,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (date == null) return;

    if (!mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_startedAt),
    );
    if (time == null) return;

    setState(() {
      _startedAt = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
    });
  }

  Future<void> _save() async {
    final duration = int.tryParse(_durationController.text) ?? 0;
    
    setState(() => _isSaving = true);

    try {
      final db = ref.read(appDatabaseProvider);
      final dao = SessionDao(db);
      
      final row = await dao.getById(widget.session.id);
      if (row == null) throw Exception('Session not found');

      final updated = row.copyWith(
        actualDurationMinutes: duration,
        startedAt: _startedAt,
        confidenceRating: Value(_confidence),
        notes: Value(_notesController.text.trim().isEmpty ? null : _notesController.text.trim()),
      );

      await dao.update(updated);
      
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Edit Session',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const Divider(),
            const SizedBox(height: 16),
            TextField(
              controller: _durationController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Duration (minutes)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.timer),
              ),
            ),
            const SizedBox(height: 20),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.calendar_today),
              title: const Text('Start Time'),
              subtitle: Text(DateFormat('MMM d, y • HH:mm').format(_startedAt)),
              trailing: TextButton(
                onPressed: _pickDateTime,
                child: const Text('Change'),
              ),
            ),
            const SizedBox(height: 20),
            Text('Confidence Rating', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (index) {
                final val = index + 1;
                final isSelected = _confidence != null && _confidence! >= val;
                return IconButton(
                  iconSize: 32,
                  icon: Icon(
                    isSelected ? Icons.star : Icons.star_outline,
                    color: isSelected ? colorScheme.primary : colorScheme.outline,
                  ),
                  onPressed: () => setState(() => _confidence = (_confidence == val ? null : val)),
                );
              }),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _notesController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Notes',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _isSaving ? null : _save,
                child: _isSaving
                    ? SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: colorScheme.onPrimary))
                    : const Text('Save Changes'),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
