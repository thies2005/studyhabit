import 'package:flutter/material.dart';

class StudyHeatmap extends StatelessWidget {
  const StudyHeatmap({super.key, required this.data});

  final List<HeatmapDay> data;

  static const _cellSize = 12.0;
  static const _cellGap = 3.0;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textStyle = Theme.of(context).textTheme.labelSmall;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final startDate = today.subtract(const Duration(days: 83));

    final firstDayOfWeek = startDate.weekday % 7;
    final daysBefore = firstDayOfWeek;
    final paddedStart = startDate.subtract(Duration(days: daysBefore));

    final totalDays = 84 + daysBefore;
    final weeks = (totalDays / 7).ceil();

    final minutesMap = <String, int>{};
    for (final d in data) {
      final key = '${d.date.year}-${d.date.month}-${d.date.day}';
      minutesMap[key] = d.minutes;
    }

    Color cellColor(int minutes) {
      if (minutes == 0) return colorScheme.surfaceContainerHighest;
      if (minutes < 30) return colorScheme.primary.withValues(alpha: 0.25);
      if (minutes < 60) return colorScheme.primary.withValues(alpha: 0.5);
      if (minutes < 120) return colorScheme.primary.withValues(alpha: 0.75);
      return colorScheme.primary;
    }

    String tooltipText(DateTime day) {
      final key = '${day.year}-${day.month}-${day.day}';
      final mins = minutesMap[key] ?? 0;
      final dateStr = _formatDate(day);
      return mins > 0 ? '$dateStr: ${mins}m' : '$dateStr: No study';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const SizedBox(width: 20),
            ...List.generate(weeks, (weekIdx) {
              final weekDate = paddedStart.add(
                const Duration(days: 7) * weekIdx,
              );
              if (weekDate.day <= 7 && weekIdx > 0) {
                return SizedBox(
                  width: (_cellSize + _cellGap) * 1,
                  child: Text(
                    _monthAbbr(weekDate.month),
                    style: textStyle?.copyWith(
                      fontSize: 9,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                );
              }
              return const SizedBox(width: _cellSize + _cellGap);
            }),
          ],
        ),
        const SizedBox(height: 4),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(
              children: ['M', '', 'W', '', 'F', '', 'S'].map((label) {
                return SizedBox(
                  height: _cellSize,
                  width: 18,
                  child: label.isNotEmpty
                      ? Align(
                          alignment: Alignment.centerRight,
                          child: Text(
                            label,
                            style: textStyle?.copyWith(
                              fontSize: 9,
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        )
                      : null,
                );
              }).toList(),
            ),
            const SizedBox(width: 2),
            Column(
              children: List.generate(7, (dayOfWeek) {
                return SizedBox(
                  height: _cellSize + _cellGap,
                  child: Row(
                    children: List.generate(weeks, (weekIdx) {
                      final cellIndex = weekIdx * 7 + dayOfWeek;
                      final cellDate = paddedStart.add(
                        Duration(days: cellIndex),
                      );

                      if (cellDate.isBefore(startDate) ||
                          cellDate.isAfter(today)) {
                        return const SizedBox(
                          width: _cellSize,
                          height: _cellSize,
                        );
                      }

                      final key =
                          '${cellDate.year}-${cellDate.month}-${cellDate.day}';
                      final minutes = minutesMap[key] ?? 0;
                      final color = cellColor(minutes);

                      return Padding(
                        padding: const EdgeInsets.only(
                          right: _cellGap,
                          bottom: _cellGap,
                        ),
                        child: Tooltip(
                          message: tooltipText(cellDate),
                          child: Container(
                            width: _cellSize,
                            height: _cellSize,
                            decoration: BoxDecoration(
                              color: color,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                );
              }),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            const SizedBox(width: 20),
            Text('Less', style: textStyle?.copyWith(fontSize: 9)),
            const SizedBox(width: 4),
            Container(
              width: _cellSize,
              height: _cellSize,
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 2),
            Container(
              width: _cellSize,
              height: _cellSize,
              decoration: BoxDecoration(
                color: colorScheme.primary.withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 2),
            Container(
              width: _cellSize,
              height: _cellSize,
              decoration: BoxDecoration(
                color: colorScheme.primary.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 2),
            Container(
              width: _cellSize,
              height: _cellSize,
              decoration: BoxDecoration(
                color: colorScheme.primary.withValues(alpha: 0.75),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 2),
            Container(
              width: _cellSize,
              height: _cellSize,
              decoration: BoxDecoration(
                color: colorScheme.primary,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 4),
            Text('More', style: textStyle?.copyWith(fontSize: 9)),
          ],
        ),
      ],
    );
  }

  String _monthAbbr(int month) {
    const months = [
      '',
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return months[month];
  }

  String _formatDate(DateTime day) {
    const months = [
      '',
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[day.month]} ${day.day}';
  }
}

class HeatmapDay {
  const HeatmapDay({required this.date, required this.minutes});

  final DateTime date;
  final int minutes;
}
