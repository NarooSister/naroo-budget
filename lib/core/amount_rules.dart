/// KRW integer limits shared by input validation and persistence boundaries.
abstract final class AmountRules {
  static const maxAmount = 2147483647;

  /// Transactions accept plain digits or correctly grouped thousands.
  /// Parsing never changes the user's text; range validation is separate.
  static int? parseTransaction(String text) {
    final raw = text.trim();
    if (!RegExp(r'^(?:[0-9]+|[0-9]{1,3}(?:,[0-9]{3})+)$').hasMatch(raw)) {
      return null;
    }
    return int.tryParse(raw.replaceAll(',', ''));
  }

  /// Budgets retain their existing digits-only input format.
  static int? parseBudget(String text) {
    final raw = text.trim();
    return RegExp(r'^\d+$').hasMatch(raw) ? int.tryParse(raw) : null;
  }

  static bool isValidTransaction(int amount) =>
      amount > 0 && amount <= maxAmount;

  static bool isValidBudget(int amount) => amount >= 0 && amount <= maxAmount;
}
