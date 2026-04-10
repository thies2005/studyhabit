import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/projects/project_switcher_sheet.dart';

class AppShellScaffold extends StatelessWidget {
  const AppShellScaffold({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  void _onTap(BuildContext context, int index) {
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('StudyTracker'),
        leading: IconButton(
          onPressed: () {
            showModalBottomSheet<void>(
              context: context,
              isScrollControlled: true,
              builder: (context) => const ProjectSwitcherSheet(),
            );
          },
          icon: const Icon(Icons.menu_book),
        ),
        actions: [
          IconButton(
            onPressed: () => context.pushNamed('settings'),
            icon: const Icon(Icons.settings),
          ),
        ],
      ),
      body: navigationShell,
      bottomNavigationBar: ClipRRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainer.withValues(alpha: 0.8),
            ),
            child: NavigationBar(
              selectedIndex: navigationShell.currentIndex,
              onDestinationSelected: (index) => _onTap(context, index),
              backgroundColor: Colors.transparent,
              elevation: 0,
              destinations: const [
                NavigationDestination(icon: Icon(Icons.home), label: 'Home'),
                NavigationDestination(
                  icon: Icon(Icons.import_contacts),
                  label: 'Subjects',
                ),
                NavigationDestination(
                  icon: Icon(Icons.leaderboard),
                  label: 'Stats',
                ),
                NavigationDestination(
                  icon: Icon(Icons.emoji_events),
                  label: 'Achievements',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
