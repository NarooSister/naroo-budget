import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/seoul_date.dart';
import '../core/session/app_session.dart';
import '../features/auth/household_connection_screen.dart';
import '../features/auth/login_screen.dart';
import '../features/auth/session_loading_screen.dart';
import '../features/home/budget_screen.dart';
import '../features/home/home_screen.dart';
import '../features/profile/profile_name_screen.dart';
import '../features/settings/category_management_screen.dart';
import '../features/settings/settings_screen.dart';
import '../features/transaction/transaction_create_screen.dart';
import '../features/transaction/transaction_list_screen.dart';
import 'app_routes.dart';
import 'app_shell.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final refresh = ValueNotifier<int>(0);
  ref.listen<AsyncValue<AppSession>>(appSessionProvider, (previous, next) {
    if (previous != next) {
      refresh.value++;
    }
  });
  ref.onDispose(refresh.dispose);

  return GoRouter(
    initialLocation: AppRoutes.home,
    refreshListenable: refresh,
    redirect: (context, state) {
      final sessionAsync = ref.read(appSessionProvider);
      final location = state.matchedLocation;
      final isLogin = location == AppRoutes.login;
      final isLoadingRoute = location == AppRoutes.loading;
      final isHouseholdRequired = location == AppRoutes.householdRequired;
      final isProfileName = location == AppRoutes.profileName;

      // Keep previous session during refresh to avoid login flicker.
      if (!sessionAsync.hasValue) {
        if (sessionAsync.hasError) {
          return isLogin ? null : AppRoutes.login;
        }
        return isLoadingRoute ? null : AppRoutes.loading;
      }

      final session = sessionAsync.requireValue;
      if (session.needsName) {
        return isProfileName ? null : AppRoutes.profileName;
      }

      switch (session.status) {
        case AppSessionStatus.signedOut:
          return isLogin ? null : AppRoutes.login;
        case AppSessionStatus.needsHousehold:
          return isHouseholdRequired ? null : AppRoutes.householdRequired;
        case AppSessionStatus.ready:
          if (isLogin ||
              isHouseholdRequired ||
              isLoadingRoute ||
              isProfileName) {
            return AppRoutes.home;
          }
          return null;
      }
    },
    routes: [
      GoRoute(
        path: AppRoutes.loading,
        builder: (context, state) => const SessionLoadingScreen(),
      ),
      GoRoute(
        path: AppRoutes.login,
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: AppRoutes.householdRequired,
        builder: (context, state) => const HouseholdConnectionScreen(),
      ),
      GoRoute(
        path: AppRoutes.profileName,
        builder: (context, state) => const ProfileNameScreen(),
      ),
      GoRoute(
        path: AppRoutes.transactionNew,
        builder: (context, state) => TransactionCreateScreen(
          initialDate: SeoulDate.tryParse(state.uri.queryParameters['date']),
        ),
      ),
      GoRoute(
        path: '/transactions/:transactionId/edit',
        builder: (context, state) => TransactionCreateScreen(
          transactionId: state.pathParameters['transactionId'],
        ),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return AppShell(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.home,
                builder: (context, state) => const HomeScreen(),
                routes: [
                  GoRoute(
                    path: 'budget',
                    builder: (context, state) => const BudgetScreen(),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.transactions,
                builder: (context, state) => const TransactionListScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.settings,
                builder: (context, state) => const SettingsScreen(),
                routes: [
                  GoRoute(
                    path: 'categories',
                    builder: (context, state) =>
                        const CategoryManagementScreen(),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    ],
  );
});
