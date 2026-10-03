import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:naroo/data/models/category.dart';
import 'package:naroo/data/models/transaction.dart';
import 'package:naroo/data/supabase/supabase_transaction_repository.dart';

void main() {
  // Exercise the real PostgREST query and JSON mapping against an isolated HTTP
  // server. No Supabase credentials or real household data are used.
  Future<SupabaseTransactionRepository> repositoryFor(
    Future<void> Function(HttpRequest) handler,
  ) async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      try {
        await handler(request);
      } finally {
        await request.response.close();
      }
    });
    final client = SupabaseClient(
      'http://127.0.0.1:${server.port}',
      'test-key',
    );
    addTearDown(() async {
      await client.dispose();
      await server.close(force: true);
    });
    return SupabaseTransactionRepository(client);
  }

  for (final cap in [500, 137]) {
    test('월별 1201건을 서버 페이지 상한 $cap 에서 모두 조회한다', () async {
      final offsets = <int>[];
      final repository = await repositoryFor((request) async {
        final query = request.uri.queryParameters;
        expect(query['household_id'], 'eq.household-1');
        expect(query['type'], 'eq.expense');
        expect(request.uri.queryParametersAll['occurred_on'], [
          'gte.2024-02-01',
          'lte.2024-02-29',
        ]);
        expect(
          query['order'],
          'occurred_on.desc.nullslast,created_at.desc.nullslast,id.desc.nullslast',
        );
        final offset = int.parse(query['offset']!);
        final limit = min(int.parse(query['limit']!), cap);
        offsets.add(offset);
        await _respond(request, [
          for (var i = offset; i < min(offset + limit, 1201); i++) _row(i),
        ]);
      });
      final items = await repository.listByMonth(
        householdId: 'household-1',
        month: DateTime(2024, 2),
        type: CategoryType.expense,
      );
      expect(items, hasLength(1201));
      expect(items.map((item) => item.transaction.id).toSet(), hasLength(1201));
      expect(items.last.transaction.id, 'tx-1200');
      expect(offsets.last, 1201);
    });
  }

  test('다음 페이지 실패를 일부 목록 성공으로 숨기지 않는다', () async {
    var calls = 0;
    final repository = await repositoryFor((request) async {
      expect(request.uri.queryParameters.containsKey('type'), isFalse);
      calls++;
      if (calls == 1) {
        await _respond(request, [_row(0)]);
      } else {
        request.response.statusCode = 400;
        await _respond(request, {'message': 'page failed', 'code': 'TEST'});
      }
    });
    await expectLater(
      repository.listByMonth(
        householdId: 'household-1',
        month: DateTime(2024, 2),
      ),
      throwsA(isA<PostgrestException>()),
    );
    expect(calls, 2);
  });

  test('빈 월은 빈 목록으로 반환한다', () async {
    final repository = await repositoryFor((request) => _respond(request, []));
    expect(
      await repository.listByMonth(
        householdId: 'household-1',
        month: DateTime(2024, 2),
      ),
      isEmpty,
    );
  });

  test('대분류·소분류 이름을 FK를 구분해 조회한다', () async {
    final repository = await repositoryFor((request) async {
      final select = request.uri.queryParameters['select']!;
      expect(select, contains('categories!transactions_category_id_fkey(name)'));
      expect(
        select,
        contains('subcategory:categories!transactions_subcategory_id_fkey(name)'),
      );
      if (request.uri.queryParameters['offset'] != '0') {
        await _respond(request, []);
        return;
      }
      await _respond(request, [
        {
          ..._row(0),
          'subcategory_id': 'eating-out',
          'subcategory': {'name': '외식'},
        },
        _row(1),
      ]);
    });
    final items = await repository.listByMonth(
      householdId: 'household-1',
      month: DateTime(2024, 2),
    );
    expect(items.first.transaction.subcategoryId, 'eating-out');
    expect(items.first.categoryLabel, '식비 · 외식');
    expect(items.last.transaction.subcategoryId, isNull);
    expect(items.last.categoryLabel, '식비');
  });

  for (final exists in [false, true]) {
    test('삭제 결과가 ${exists ? '있을' : '없을'} 때 성공 여부를 구분한다', () async {
      final repository = await repositoryFor((request) async {
        expect(request.method, 'DELETE');
        expect(request.uri.queryParameters['id'], 'eq.tx-1');
        expect(request.uri.queryParameters['select'], 'id');
        await _respond(
          request,
          exists
              ? [
                  {'id': 'tx-1'},
                ]
              : [],
        );
      });
      if (exists) {
        await repository.delete('tx-1');
      } else {
        await expectLater(repository.delete('tx-1'), throwsStateError);
      }
    });
  }

  test('상한 초과 금액은 생성과 수정 모두 HTTP 요청 전에 거절한다', () async {
    var requests = 0;
    final repository = await repositoryFor((request) async {
      requests++;
      await _respond(request, _row(0));
    });
    final input = NewTransaction(
      householdId: 'household-1',
      memberId: 'member-1',
      type: CategoryType.expense,
      amount: NewTransaction.maxAmount + 1,
      categoryId: 'food',
      occurredOn: DateTime(2024, 2, 1),
    );
    await expectLater(repository.create(input), throwsArgumentError);
    await expectLater(
      repository.update(transactionId: 'tx-1', input: input),
      throwsArgumentError,
    );
    expect(requests, 0);
  });

  for (final update in [false, true]) {
    for (final memo in ['  메모  ', '   ', null]) {
      test('${update ? '수정' : '생성'} 요청과 반환값을 검사한다: memo=$memo', () async {
        var requests = 0;
        final repository = await repositoryFor((request) async {
          requests++;
          expect(request.method, update ? 'PATCH' : 'POST');
          expect(request.uri.path, '/rest/v1/transactions');
          expect(request.uri.queryParameters['id'], update ? 'eq.tx-1' : null);
          final body = jsonDecode(await utf8.decoder.bind(request).join());
          final expected = {
            'household_id': 'household-1',
            'member_id': 'member-1',
            'attribution_kind': 'member',
            'type': 'income',
            'amount': NewTransaction.maxAmount,
            'category_id': 'salary',
            'subcategory_id': null,
            'occurred_on': '2024-12-31',
            'memo': memo == null || memo.trim().isEmpty ? null : memo.trim(),
          };
          expect(body, expected);
          await _respond(request, {'id': 'tx-1', ...expected});
        });
        final input = NewTransaction(
          householdId: 'household-1',
          memberId: 'member-1',
          type: CategoryType.income,
          amount: NewTransaction.maxAmount,
          categoryId: 'salary',
          occurredOn: DateTime(2024, 12, 31),
          memo: memo,
        );
        final result = update
            ? await repository.update(transactionId: 'tx-1', input: input)
            : await repository.create(input);
        expect(result.id, 'tx-1');
        expect(result.householdId, 'household-1');
        expect(result.type, CategoryType.income);
        expect(result.amount, NewTransaction.maxAmount);
        expect(result.occurredOn, DateTime(2024, 12, 31));
        expect(result.memo, memo == null || memo.trim().isEmpty ? null : '메모');
        expect(requests, 1);
      });
    }
  }

  for (final exists in [false, true]) {
    test('단건 조회 ${exists ? '존재' : '없음'}을 구분한다', () async {
      final repository = await repositoryFor((request) async {
        expect(request.method, 'GET');
        expect(request.uri.queryParameters['id'], 'eq.tx-1');
        await _respond(request, exists ? [_row(1)] : []);
      });
      final result = await repository.findById('tx-1');
      expect(result?.id, exists ? 'tx-1' : null);
      if (exists) expect(result?.amount, 12000);
    });
  }

  for (final operation in ['create', 'update', 'find', 'delete']) {
    test('$operation 서버 오류를 성공으로 처리하지 않는다', () async {
      final repository = await repositoryFor((request) async {
        request.response.statusCode = 403;
        await _respond(request, {'message': 'denied', 'code': '42501'});
      });
      await expectLater(
        _operation(repository, operation),
        throwsA(isA<PostgrestException>()),
      );
    });
    test('$operation 설정이 없으면 저장/조회를 시작하지 않는다', () async {
      await expectLater(
        _operation(SupabaseTransactionRepository(null), operation),
        throwsStateError,
      );
    });
  }

  for (final input in [
    _input(amount: 0),
    _input(amount: -1),
    _input(categoryId: '  '),
    _input(memberId: '  '),
  ]) {
    test(
      '잘못된 입력은 생성/수정 요청 전에 거절한다: ${input.amount}/${input.categoryId}/${input.memberId}',
      () async {
        var requests = 0;
        final repository = await repositoryFor((request) async {
          requests++;
          await _respond(request, _row(1));
        });
        await expectLater(repository.create(input), throwsArgumentError);
        await expectLater(
          repository.update(transactionId: 'tx-1', input: input),
          throwsArgumentError,
        );
        expect(requests, 0);
      },
    );
  }
}

NewTransaction _input({
  int amount = 100,
  String categoryId = 'food',
  String memberId = 'member-1',
}) => NewTransaction(
  householdId: 'household-1',
  memberId: memberId,
  type: CategoryType.expense,
  amount: amount,
  categoryId: categoryId,
  occurredOn: DateTime(2024, 2, 29),
);

Future<Object?> _operation(
  SupabaseTransactionRepository repository,
  String operation,
) => switch (operation) {
  'create' => repository.create(_input()),
  'update' => repository.update(transactionId: 'tx-1', input: _input()),
  'find' => repository.findById('tx-1'),
  'delete' => repository.delete('tx-1'),
  _ => throw ArgumentError(operation),
};

Map<String, Object?> _row(int index) => {
  'id': 'tx-$index',
  'household_id': 'household-1',
  'member_id': 'member-1',
  'type': 'expense',
  'amount': 12000,
  'category_id': 'food',
  'occurred_on': '2024-02-29',
  'memo': null,
  'categories': {'name': '식비'},
  'household_members': {'display_name': '사용자'},
};

Future<void> _respond(HttpRequest request, Object body) async {
  request.response.headers.contentType = ContentType.json;
  request.response.write(jsonEncode(body));
  await request.response.close();
}
