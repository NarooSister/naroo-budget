enum PaymentMethod {
  debitCard('debit_card', '체크카드'),
  creditCard('credit_card', '신용카드'),
  cash('cash', '현금');

  const PaymentMethod(this.dbValue, this.label);

  final String dbValue;
  final String label;

  static PaymentMethod? fromDb(String? value) {
    if (value == null) return null;
    return PaymentMethod.values.firstWhere(
      (method) => method.dbValue == value,
      orElse: () => throw FormatException('Unknown payment method: $value'),
    );
  }

  /// The user's preferred method first, then the base order.
  static List<PaymentMethod> orderedFor(PaymentMethod preferred) => [
    preferred,
    ...PaymentMethod.values.where((method) => method != preferred),
  ];
}
