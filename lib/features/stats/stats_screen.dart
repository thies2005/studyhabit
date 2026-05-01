import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/models/enums.dart';
import 'heatmap_widget.dart' as heatmap_lib;
import 'stats_models.dart';
import 'stats_providers.dart';

class StatsScreen extends ConsumerWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final overview = ref.watch(statsOverviewProvider);
    final weekly = ref.watch(weeklyActivityProvider);
    final subjects = ref.watch(subjectDistributionProvider(30));
    final heatmap = ref.watch(heatmapDataProvider);
    final breakdown = ref.watch(subjectBreakdownProvider);

    return overview.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (overviewData) => Scaffold(
        body: CustomScrollView(
          slivers: [
            const SliverAppBar.large(title: Text('Statistics'), pinned: true),
            SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: SliverToBoxAdapter(
                child: _OverviewCards(overview: overviewData),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverToBoxAdapter(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'This Week',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          height: 200,
                          child: weekly.when(
                            loading: () => const Center(
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                            error: (e, _) => const SizedBox(),
                            data: (data) => _WeeklyBarChart(data: data),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SliverPadding(padding: EdgeInsets.only(top: 8)),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverToBoxAdapter(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Subject Distribution',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          height: 200,
                          child: subjects.when(
                            loading: () => const Center(
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                            error: (e, _) =>
                                const Center(child: Text('No subject data')),
                            data: (data) => data.isEmpty
                                ? const Center(child: Text('No data yet'))
                                : _SubjectPieChart(data: data),
                          ),
                        ),
                        if (subjects.hasValue &&
                            subjects.value!.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          _SubjectLegend(data: subjects.value!),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SliverPadding(padding: EdgeInsets.only(top: 8)),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverToBoxAdapter(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Activity Heatmap',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 16),
                        heatmap.when(
                          loading: () => const Center(
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          error: (e, _) => const SizedBox(),
                          data: (data) => SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: heatmap_lib.StudyHeatmap(
                              data: data
                                  .map(
                                    (d) => heatmap_lib.HeatmapDay(
                                      date: d.date,
                                      minutes: d.minutes,
                                    ),
                                  )
                                  .toList(),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SliverPadding(padding: EdgeInsets.only(top: 8)),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverToBoxAdapter(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'XP Over 30 Days',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          height: 200,
                          child: ref
                              .watch(xpLineChartDataProvider)
                              .when(
                                loading: () => const Center(
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                                error: (e, _) => const SizedBox(),
                                data: (data) => _XpLineChart(data: data),
                              ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SliverPadding(padding: EdgeInsets.only(top: 8)),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverToBoxAdapter(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Subject Breakdown',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        breakdown.when(
                          loading: () => const Center(
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          error: (e, _) => const SizedBox(),
                          data: (data) => data.isEmpty
                              ? const Center(
                                  child: Padding(
                                    padding: EdgeInsets.all(24),
                                    child: Text('No data yet'),
                                  ),
                                )
                              : _SubjectBreakdownTable(data: data),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SliverPadding(padding: EdgeInsets.only(bottom: 32)),
          ],
        ),
      ),
    );
  }
}

class _OverviewCards extends StatelessWidget {
  const _OverviewCards({required this.overview});

  final StatsOverview overview;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return GridView(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1.2,
      ),
      children: [
        _StatCard(
          icon: Icons.schedule,
          label: 'Total Hours',
          value: overview.totalHours.toStringAsFixed(1),
          color: colorScheme.primary,
        ),
        _StatCard(
          icon: Icons.today,
          label: 'This Week',
          value: '${overview.weekHours.toStringAsFixed(1)}h',
          color: colorScheme.tertiary,
        ),
        _StatCard(
          icon: Icons.local_fire_department,
          label: 'Streak',
          value: '${overview.currentStreak}d',
          color: colorScheme.error,
        ),
        _StatCard(
          icon: Icons.auto_awesome,
          label: 'Level',
          value: overview.levelName,
          subtitle: 'Lv ${overview.currentLevel}',
          color: colorScheme.secondary,
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    this.subtitle,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 24),
            const Spacer(),
            Text(
              value,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: colorScheme.onSurface,
              ),
            ),
            if (subtitle != null)
              Text(
                subtitle!,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WeeklyBarChart extends StatelessWidget {
  const _WeeklyBarChart({required this.data});

  final List<DailyActivity> data;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final maxHours = data.fold(0.0, (max, d) => d.hours > max ? d.hours : max);
    final maxY = (maxHours * 1.2).ceilToDouble();
    if (maxY == 0) return const Center(child: Text('No data this week'));

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: maxY,
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              final day = data[group.x.toInt()];
              return BarTooltipItem(
                '${DateFormat.E().format(day.date)}\n${day.hours.toStringAsFixed(1)}h',
                TextStyle(color: Theme.of(context).colorScheme.onPrimary, fontSize: 12),
              );
            },
          ),
        ),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 36,
              getTitlesWidget: (value, meta) {
                if (value == 0) return const SizedBox();
                return Text(
                  '${value.toInt()}h',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                );
              },
            ),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                final idx = value.toInt();
                if (idx < 0 || idx >= data.length) return const SizedBox();
                return Text(
                  DateFormat.E().format(data[idx].date),
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                );
              },
            ),
          ),
        ),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (value) => FlLine(
            color: colorScheme.outlineVariant.withValues(alpha: 0.5),
            strokeWidth: 1,
          ),
        ),
        borderData: FlBorderData(show: false),
        barGroups: List.generate(data.length, (i) {
          return BarChartGroupData(
            x: i,
            barRods: [
              BarChartRodData(
                toY: data[i].hours,
                borderRadius: BorderRadius.circular(6),
                color: colorScheme.primary,
                width: 28,
              ),
            ],
          );
        }),
      ),
    );
  }
}

class _SubjectPieChart extends StatelessWidget {
  const _SubjectPieChart({required this.data});

  final List<SubjectTime> data;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    // Cache subject colors to avoid repeated ColorScheme.fromSeed() calls
    final subjectColors = <int, Color>{};
    for (final item in data) {
      subjectColors[item.subject.colorValue] ??= ColorScheme.fromSeed(
        seedColor: Color(item.subject.colorValue),
      ).primary;
    }

    return PieChart(
      PieChartData(
        pieTouchData: PieTouchData(
          touchCallback: (FlTouchEvent event, pieTouchResponse) {},
        ),
        sectionsSpace: 2,
        centerSpaceRadius: 40,
        sections: data.map((item) {
          return PieChartSectionData(
            value: item.percentage,
            title: '${item.percentage.toStringAsFixed(0)}%',
            titleStyle: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onPrimary,
            ),
            color: subjectColors[item.subject.colorValue]!,
            radius: 60,
            borderSide: BorderSide(color: colorScheme.surface, width: 2),
          );
        }).toList(),
      ),
    );
  }
}

class _SubjectLegend extends StatelessWidget {
  const _SubjectLegend({required this.data});

  final List<SubjectTime> data;

  @override
  Widget build(BuildContext context) {
    // Cache subject colors to avoid repeated ColorScheme.fromSeed() calls
    final subjectColors = <int, Color>{};
    for (final item in data) {
      subjectColors[item.subject.colorValue] ??= ColorScheme.fromSeed(
        seedColor: Color(item.subject.colorValue),
      ).primary;
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: data.map((item) {
          return Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: subjectColors[item.subject.colorValue]!,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  item.subject.name,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _SubjectBreakdownTable extends StatelessWidget {
  const _SubjectBreakdownTable({required this.data});

  final List<SubjectBreakdown> data;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    // Cache subject colors to avoid repeated ColorScheme.fromSeed() calls
    final subjectColors = <int, Color>{};
    for (final item in data) {
      subjectColors[item.subject.colorValue] ??= ColorScheme.fromSeed(
        seedColor: Color(item.subject.colorValue),
      ).primary;
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        sortColumnIndex: 1,
        sortAscending: false,
        columns: [
          DataColumn(
            label: Text(
              'Subject',
              style: Theme.of(context).textTheme.labelMedium,
            ),
          ),
          DataColumn(
            label: Text(
              'Hours',
              style: Theme.of(context).textTheme.labelMedium,
            ),
            numeric: true,
          ),
          DataColumn(
            label: Text(
              'Sessions',
              style: Theme.of(context).textTheme.labelMedium,
            ),
            numeric: true,
          ),
          DataColumn(
            label: Text(
              'Avg ★',
              style: Theme.of(context).textTheme.labelMedium,
            ),
            numeric: true,
          ),
          DataColumn(
            label: Text(
              'Skill',
              style: Theme.of(context).textTheme.labelMedium,
            ),
          ),
        ],
        rows: data.map((row) {
          return DataRow(
            cells: [
              DataCell(
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: subjectColors[row.subject.colorValue]!,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(row.subject.name),
                  ],
                ),
              ),
              DataCell(Text(row.totalHours.toStringAsFixed(1))),
              DataCell(Text('${row.sessionCount}')),
              DataCell(
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(5, (i) {
                    if (i < row.avgConfidence.floor()) {
                      return Icon(
                        Icons.star,
                        size: 14,
                        color: colorScheme.primary,
                      );
                    } else if (i < row.avgConfidence) {
                      return Icon(
                        Icons.star_half,
                        size: 14,
                        color: colorScheme.primary,
                      );
                    }
                    return Icon(
                      Icons.star_outline,
                      size: 14,
                      color: colorScheme.outline,
                    );
                  }),
                ),
              ),
              DataCell(
                Chip(
                  label: Text(
                    _skillLabel(row.skillLevel),
                    style: const TextStyle(fontSize: 11),
                  ),
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }

  String _skillLabel(SkillLevel level) {
    return switch (level) {
      SkillLevel.beginner => 'Beginner',
      SkillLevel.intermediate => 'Intermediate',
      SkillLevel.advanced => 'Advanced',
      SkillLevel.expert => 'Expert',
    };
  }
}

class _XpLineChart extends StatelessWidget {
  const _XpLineChart({required this.data});

  final List<XpDayData> data;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    if (data.isEmpty) {
      return const Center(child: Text('No XP data yet'));
    }

    final maxXp = data.fold(
      0,
      (max, d) => d.cumulativeXp > max ? d.cumulativeXp : max,
    );
    if (maxXp == 0) return const Center(child: Text('No XP data yet'));

    final spots = data.asMap().entries.map((e) {
      return FlSpot(e.key.toDouble(), e.value.cumulativeXp.toDouble());
    }).toList();

    final gradient = LinearGradient(
      colors: [colorScheme.primary, colorScheme.tertiary],
    );

    return LineChart(
      LineChartData(
        minX: 0,
        maxX: (data.length - 1).toDouble(),
        minY: 0,
        maxY: maxXp.toDouble() * 1.1,
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipItems: (touchedSpots) {
              return touchedSpots.map((spot) {
                final idx = spot.x.toInt();
                final dateStr = DateFormat.Md().format(data[idx].date);
                return LineTooltipItem(
                  '$dateStr\n${data[idx].cumulativeXp} XP',
                  TextStyle(color: Theme.of(context).colorScheme.onPrimary, fontSize: 12),
                );
              }).toList();
            },
          ),
        ),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              getTitlesWidget: (value, meta) {
                if (value == 0) return const SizedBox();
                return Text(
                  '${value.toInt()}',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                );
              },
            ),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: 7,
              getTitlesWidget: (value, meta) {
                final idx = value.toInt();
                if (idx < 0 || idx >= data.length) return const SizedBox();
                return Text(
                  DateFormat.Md().format(data[idx].date),
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontSize: 9,
                  ),
                );
              },
            ),
          ),
        ),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (value) => FlLine(
            color: colorScheme.outlineVariant.withValues(alpha: 0.5),
            strokeWidth: 1,
          ),
        ),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            curveSmoothness: 0.3,
            color: colorScheme.primary,
            barWidth: 2.5,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                colors: [
                  colorScheme.primaryContainer.withValues(alpha: 0.3),
                  colorScheme.primaryContainer.withValues(alpha: 0.05),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            gradient: gradient,
          ),
        ],
      ),
    );
  }
}
