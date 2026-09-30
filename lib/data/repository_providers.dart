import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/supabase/supabase_initializer.dart';
import 'repositories/auth_repository.dart';
import 'repositories/category_repository.dart';
import 'repositories/household_member_repository.dart';
import 'repositories/monthly_budget_repository.dart';
import 'repositories/profile_repository.dart';
import 'repositories/transaction_repository.dart';
import 'supabase/supabase_category_repository.dart';
import 'supabase/supabase_household_member_repository.dart';
import 'supabase/supabase_monthly_budget_repository.dart';
import 'supabase/supabase_transaction_repository.dart';

// Composition only: features consume these providers, while repository
// contracts and implementations remain independent of Riverpod.
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(ref.watch(supabaseClientProvider));
});

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  return ProfileRepository(ref.watch(supabaseClientProvider));
});

final householdMemberRepositoryProvider = Provider<HouseholdMemberRepository>((
  ref,
) {
  return SupabaseHouseholdMemberRepository(ref.watch(supabaseClientProvider));
});

final categoryRepositoryProvider = Provider<CategoryRepository>((ref) {
  return SupabaseCategoryRepository(ref.watch(supabaseClientProvider));
});

final transactionRepositoryProvider = Provider<TransactionRepository>((ref) {
  return SupabaseTransactionRepository(ref.watch(supabaseClientProvider));
});

final monthlyBudgetRepositoryProvider = Provider<MonthlyBudgetRepository>((
  ref,
) {
  return SupabaseMonthlyBudgetRepository(ref.watch(supabaseClientProvider));
});
