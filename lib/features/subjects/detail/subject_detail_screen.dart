import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/enums.dart';
import '../../../core/models/subject.dart';
import '../subject_providers.dart';
import 'sources/sources_tab.dart';
import 'timeline/timeline_tab.dart';
import 'topics/topics_tab.dart';

class SubjectDetailScreen extends ConsumerWidget {
  const SubjectDetailScreen({super.key, required this.subjectId});

  final String subjectId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subjectAsync = ref.watch(subjectByIdProvider(subjectId));

    return subjectAsync.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (error, _) => Scaffold(
        body: Center(
          child: Text(
            'Failed to load subject',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ),
      ),
      data: (subject) {
        if (subject == null) {
          return Scaffold(
            body: Center(
              child: Text(
                'Subject not found',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ),
          );
        }
        return _SubjectDetailContent(subject: subject);
      },
    );
  }
}

class _SubjectDetailContent extends ConsumerWidget {
  const _SubjectDetailContent({required this.subject});

  final Subject subject;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final subjectColor = ColorScheme.fromSeed(
      seedColor: Color(subject.colorValue),
    );

    final showTopics = subject.hierarchyMode != HierarchyMode.flat;
    final tabs = [
      const Tab(text: 'Timeline'),
      const Tab(text: 'Sources'),
      if (showTopics) const Tab(text: 'Topics'),
    ];

    return DefaultTabController(
      length: tabs.length,
      child: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          SliverAppBar(
            expandedHeight: 200,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                subject.name,
                style: TextStyle(
                  color: colorScheme.onSurface,
                  fontWeight: FontWeight.w600,
                ),
              ),
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      subjectColor.primaryContainer,
                      subjectColor.surface,
                    ],
                  ),
                ),
              ),
            ),
            bottom: TabBar(tabs: tabs),
          ),
        ],
        body: TabBarView(
          children: [
            TimelineTab(subjectId: subject.id),
            SourcesTab(subjectId: subject.id),
            if (showTopics) TopicsTab(subjectId: subject.id),
          ],
        ),
      ),
    );
  }
}
