import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:naroo/data/models/category.dart';
import 'package:naroo/data/models/transaction.dart';
import 'package:naroo/data/supabase/supabase_transaction_repository.dart';

import 'support/supabase_test_server.dart';

NewTransaction _input(
  AttributionKind kind,
  String? memberId,
  CategoryType type,
) => NewTransaction(
  householdId: 'h',
  memberId: memberId,
  attributionKind: kind,
  type: type,
  amount: 100,
  categoryId: type.name,
  occurredOn: DateTime(2026, 12, 31),
);

void main() {
  for (final type in CategoryType.values) {
    test('공용 ${type.name} 생성·수정은 명시적 귀속과 null 구성원을 전송한다', () async {
      final client = await localSupabaseClient((request) async {
        final body = jsonDecode(
          await utf8.decoder.bind(request).join(),
        ) as Map<String, dynamic>;
        expect(body['attribution_kind'], 'shared');
        expect(body['member_id'], isNull);
        expect(body['type'], type.name);
        respond(request, {'id': 'tx', ...body});
      });
      final repo = SupabaseTransactionRepository(client);
      final input = _input(AttributionKind.shared, null, type);
      final created = await repo.create(input);
      final updated = await repo.update(transactionId: 'tx', input: input);
      expect(created.attributionKind, AttributionKind.shared);
      expect(updated.memberId, isNull);
      expect(
        TransactionListItem(
          transaction: updated,
          categoryName: '분류',
        ).attributionLabel,
        '공용',
      );
    });
  }

  test('귀속 누락과 공용/구성원 모순을 요청 전에 거부한다', () async {
    var calls = 0;
    final client = await localSupabaseClient((request) async {
      calls++;
      respond(request, {});
    });
    final repo = SupabaseTransactionRepository(client);
    for (final input in [
      _input(AttributionKind.member, null, CategoryType.expense),
      _input(AttributionKind.shared, 'me', CategoryType.income),
    ]) {
      await expectLater(repo.create(input), throwsArgumentError);
      await expectLater(
        repo.update(transactionId: 'tx', input: input),
        throwsArgumentError,
      );
    }
    expect(calls, 0);
  });
}
