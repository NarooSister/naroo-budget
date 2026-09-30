import 'package:flutter_test/flutter_test.dart';

import 'package:naroo/core/amount_rules.dart';

void main() {
  test('거래 파싱은 정수와 올바른 쉼표만 허용하고 범위와 구분한다', () {
    for (final entry in {
      '1': 1,
      '0001': 1,
      ' 12,000 ': 12000,
      '2,147,483,647': 2147483647,
      '0': 0,
      '2147483648': 2147483648,
    }.entries) {
      expect(AmountRules.parseTransaction(entry.key), entry.value);
    }
    for (final raw in [
      '',
      '-100',
      '+100',
      '12.34',
      '1e3',
      '12,34',
      '1,0000',
      '1 000',
      '999999999999999999999999999999',
    ]) {
      expect(AmountRules.parseTransaction(raw), isNull, reason: raw);
    }
  });

  test('예산 파싱은 공백을 제외한 숫자만 허용한다', () {
    expect(AmountRules.parseBudget(' 0 '), 0);
    expect(AmountRules.parseBudget('2147483647'), 2147483647);
    for (final raw in ['', '-1', '+1', '1.5', '1,000', '1e3']) {
      expect(AmountRules.parseBudget(raw), isNull, reason: raw);
    }
  });

  test('거래는 0보다 큰 금액, 예산은 0부터 동일 상한을 적용한다', () {
    for (final amount in [-1, 0, 1, 2147483647, 2147483648]) {
      expect(
        AmountRules.isValidTransaction(amount),
        amount == 1 || amount == 2147483647,
      );
      expect(
        AmountRules.isValidBudget(amount),
        amount == 0 || amount == 1 || amount == 2147483647,
      );
    }
  });
}
