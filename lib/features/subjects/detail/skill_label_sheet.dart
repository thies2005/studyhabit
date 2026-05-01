import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/app_database.dart';
import '../../../core/models/enums.dart';
import '../../../core/providers/database_provider.dart';
import '../../../core/services/xp_service.dart';

class SkillLabelSheet extends ConsumerStatefulWidget {
  const SkillLabelSheet({
    super.key,
    required this.subjectId,
    this.topicId,
    this.chapterId,
  });

  final String subjectId;
  final String? topicId;
  final String? chapterId;

  @override
  ConsumerState<SkillLabelSheet> createState() => _SkillLabelSheetState();
}

class _SkillLabelSheetState extends ConsumerState<SkillLabelSheet> {
  SkillLevel? _selected;
  SkillLevel? _previousLabel;

  static const _descriptions = {
    SkillLevel.beginner: 'Basic understanding of concepts',
    SkillLevel.intermediate: 'Can apply concepts in practice',
    SkillLevel.advanced: 'Deep understanding, can teach others',
    SkillLevel.expert: 'Mastery level, can innovate',
  };

  @override
  void initState() {
    super.initState();
    _loadCurrentLabel();
  }

  Future<void> _loadCurrentLabel() async {
    final db = ref.read(appDatabaseProvider);
    final query = db.select(db.skillLabels)
      ..where((t) => t.subjectId.equals(widget.subjectId));

    if (widget.topicId != null) {
      query.where((t) => t.topicId.equals(widget.topicId!));
    } else {
      query.where((t) => t.topicId.isNull());
    }
    if (widget.chapterId != null) {
      query.where((t) => t.chapterId.equals(widget.chapterId!));
    } else {
      query.where((t) => t.chapterId.isNull());
    }

    final rows = await query.get();
    if (rows.isNotEmpty) {
      rows.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      if (mounted) {
        setState(() {
          _selected = rows.first.label;
          _previousLabel = rows.first.label;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SafeArea(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Skill Level', style: theme.textTheme.titleLarge),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            RadioGroup<SkillLevel>(
              groupValue: _selected,
              onChanged: (v) { if (v != null) setState(() => _selected = v); },
              child: Column(
                children: SkillLevel.values.map((level) {
                  final (color, label) = _levelStyle(level, Theme.of(context).colorScheme);
                  return RadioListTile<SkillLevel>(
                    value: level,
                    title: Row(
                      children: [
                        CircleAvatar(radius: 6, backgroundColor: color),
                        const SizedBox(width: 8),
                        Text(label),
                      ],
                    ),
                    subtitle: Text(
                      _descriptions[level] ?? '',
                      style: theme.textTheme.bodySmall,
                    ),
                  );
                }).toList(),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: FilledButton(
                onPressed: _selected != null ? _save : null,
                child: const Text('Save'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  (Color, String) _levelStyle(SkillLevel level, ColorScheme colorScheme) => switch (level) {
    SkillLevel.beginner => (colorScheme.primary, 'Beginner'),
    SkillLevel.intermediate => (colorScheme.tertiary, 'Intermediate'),
    SkillLevel.advanced => (colorScheme.error, 'Advanced'),
    SkillLevel.expert => (colorScheme.primary, 'Expert'),
  };

  Future<void> _save() async {
    if (_selected == null) return;

    final shouldAwardXp =
        _previousLabel != null && _selected!.index > _previousLabel!.index;

    final db = ref.read(appDatabaseProvider);
    const uuid = Uuid();
    final existingQuery = db.select(db.skillLabels)
      ..where((t) => t.subjectId.equals(widget.subjectId));

    if (widget.topicId != null) {
      existingQuery.where((t) => t.topicId.equals(widget.topicId!));
    } else {
      existingQuery.where((t) => t.topicId.isNull());
    }
    if (widget.chapterId != null) {
      existingQuery.where((t) => t.chapterId.equals(widget.chapterId!));
    } else {
      existingQuery.where((t) => t.chapterId.isNull());
    }

    final existingRows = await existingQuery.get();
    existingRows.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    final existingRow = existingRows.isNotEmpty ? existingRows.first : null;

    if (existingRow != null) {
      await db.update(db.skillLabels).replace(
        existingRow.copyWith(label: _selected!, updatedAt: DateTime.now()),
      );
    } else {
      await db
          .into(db.skillLabels)
          .insertOnConflictUpdate(
            SkillLabelsCompanion.insert(
              id: uuid.v4(),
              subjectId: widget.subjectId,
              topicId: Value(widget.topicId),
              chapterId: Value(widget.chapterId),
              label: _selected!,
            ),
          );
    }

    if (shouldAwardXp) {
      try {
        await ref.read(xpServiceProvider).award(ref, XpReason.skillAdvance);
      } catch (e) {
        debugPrint('Error awarding skill advance XP: $e');
      }
    }

    if (mounted) {
      Navigator.of(context).pop();
    }
  }
}
