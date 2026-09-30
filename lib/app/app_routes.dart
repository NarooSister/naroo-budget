abstract final class AppRoutes {
  static const loading = '/loading';
  static const login = '/login';
  static const householdRequired = '/household-required';
  static const home = '/home';
  static const transactions = '/transactions';
  static const transactionNew = '/transactions/new';
  static const settings = '/settings';
  static const categories = '/settings/categories';

  static String transactionEdit(String transactionId) =>
      '/transactions/$transactionId/edit';
}
