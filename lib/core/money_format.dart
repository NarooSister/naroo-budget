import '../data/models/category.dart';

abstract final class MoneyFormat {
  static String krw(int amount) {
    final digits = amount.abs().toString();
    final buffer = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      final reverseIndex = digits.length - i;
      buffer.write(digits[i]);
      if (reverseIndex > 1 && reverseIndex % 3 == 1) {
        buffer.write(',');
      }
    }
    return buffer.toString();
  }

  static String signed(CategoryType type, int amount) {
    final prefix = type == CategoryType.income ? '+' : '-';
    return '$prefix${krw(amount)}';
  }
}
