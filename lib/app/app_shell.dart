import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/selected_month.dart';
import '../features/home/home_controller.dart';
import '../features/settings/settings_controller.dart';
import '../features/statistics/statistics_controller.dart';
import '../features/transaction/transaction_list_controller.dart';
import 'theme/naroo_colors.dart';
import 'theme/naroo_icons.dart';
import 'theme/naroo_spacing.dart';

class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: DecoratedBox(
        decoration: const BoxDecoration(
          color: NarooColors.surface,
          boxShadow: NarooShadows.overlay,
        ),
        child: NavigationBar(
          selectedIndex: navigationShell.currentIndex,
          onDestinationSelected: (index) {
            if (index == 0) {
              ref.invalidate(currentMonthProvider);
              ref.invalidate(homeSummaryProvider);
            }
            if (index == 1) {
              ref.invalidate(currentMonthProvider);
              ref.invalidate(monthTransactionsProvider);
            }
            if (index == 2) {
              ref.invalidate(currentMonthProvider);
              ref.invalidate(statisticsProvider);
            }
            if (index == 3) ref.invalidate(settingsMembersProvider);
            navigationShell.goBranch(index);
          },
          destinations: const [
            NavigationDestination(
              icon: Icon(NarooIcons.home, size: NarooIcons.nav),
              selectedIcon: Icon(NarooIcons.home, size: NarooIcons.nav),
              label: '홈',
            ),
            NavigationDestination(
              icon: Icon(NarooIcons.transactions, size: NarooIcons.nav),
              selectedIcon: Icon(NarooIcons.transactions, size: NarooIcons.nav),
              label: '내역',
            ),
            NavigationDestination(
              icon: Icon(NarooIcons.statistics, size: NarooIcons.nav),
              selectedIcon: Icon(NarooIcons.statistics, size: NarooIcons.nav),
              label: '통계',
            ),
            NavigationDestination(
              icon: Icon(NarooIcons.settings, size: NarooIcons.nav),
              selectedIcon: Icon(NarooIcons.settings, size: NarooIcons.nav),
              label: '설정',
            ),
          ],
        ),
      ),
    );
  }
}
