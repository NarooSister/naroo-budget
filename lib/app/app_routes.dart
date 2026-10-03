import '../core/seoul_date.dart';

abstract final class AppRoutes {
  static const loading = '/loading';
  static const login = '/login';
  static const householdRequired = '/household-required';
  static const profileName = '/profile-name';
  static const home = '/home';
  static const budget = '/home/budget';
  static const transactions = '/transactions';
  static const transactionNew = '/transactions/new';
  static const settings = '/settings';
  static const categories = '/settings/categories';

  static String transactionNewOn(DateTime date) =>
      '$transactionNew?date=${SeoulDate.format(date)}';

  static String transactionEdit(String transactionId) =>
      '/transactions/$transactionId/edit';
}
