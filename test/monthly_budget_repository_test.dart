import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:naroo/data/models/monthly_budget.dart';
import 'package:naroo/data/supabase/supabase_monthly_budget_repository.dart';

void main() {
  Future<SupabaseMonthlyBudgetRepository> repositoryFor(
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
    return SupabaseMonthlyBudgetRepository(client);
  }

  void writeJson(HttpRequest request, Object body, {int status = 200}) {
    request.response.statusCode = status;
    request.response.headers.contentType = ContentType.json;
    request.response.write(jsonEncode(body));
  }

  test('미설정 예산은 null이다', () async {
    final repo = await repositoryFor((request) async => writeJson(request, []));
    expect(await repo.find('h', DateTime(2027, 1)), isNull);
  });

  test('예산 조회는 Household/연도/월로 제한하고 배분과 버전을 읽는다', () async {
    final repo = await repositoryFor((request) async {
      expect(request.uri.path, '/rest/v1/monthly_budgets');
      expect(request.uri.queryParameters['household_id'], 'eq.h');
      expect(request.uri.queryParameters['year'], 'eq.2027');
      expect(request.uri.queryParameters['month'], 'eq.1');
      expect(
        request.uri.queryParameters['select'],
        'amount,revision,budget_allocations(category_id,amount)',
      );
      writeJson(request, [
        {
          'amount': 2147483647,
          'revision': '7d1c0b9e-0000-4000-8000-000000000001',
          'budget_allocations': [
            {'category_id': 'food', 'amount': 0},
            {'category_id': 'bus', 'amount': 1000},
          ],
        },
      ]);
    });
    final budget = (await repo.find('h', DateTime(2027, 1)))!;
    expect(budget.amount, 2147483647);
    expect(budget.version, '7d1c0b9e-0000-4000-8000-000000000001');
    expect(budget.allocations, {'food': 0, 'bus': 1000});
    expect(budget.unallocated, 2147482647);
  });

  test('저장은 총예산·배분·불러온 버전을 RPC 하나로 보낸다', () async {
    final repo = await repositoryFor((request) async {
      expect(request.method, 'POST');
      expect(request.uri.path, '/rest/v1/rpc/save_monthly_budget');
      final body = jsonDecode(await utf8.decoder.bind(request).join());
      expect(body, {
        'target_household_id': 'h',
        'target_year': 2026,
        'target_month': 12,
        'total_amount': 1000,
        'allocations': [
          {'category_id': 'food', 'amount': 600},
          {'category_id': 'bus', 'amount': 0},
        ],
        'expected_revision': null,
      });
      writeJson(request, '7d1c0b9e-0000-4000-8000-000000000002');
    });
    await repo.save(
      'h',
      DateTime(2026, 12),
      amount: 1000,
      allocations: const {'food': 600, 'bus': 0},
      expectedVersion: null,
    );
  });

  test('초기화는 버전과 함께 RPC로 보낸다', () async {
    final repo = await repositoryFor((request) async {
      expect(request.uri.path, '/rest/v1/rpc/reset_monthly_budget');
      final body = jsonDecode(await utf8.decoder.bind(request).join());
      expect(body, {
        'target_household_id': 'h',
        'target_year': 2027,
        'target_month': 1,
        'expected_revision': '7d1c0b9e-0000-4000-8000-000000000001',
      });
      request.response.statusCode = 204;
    });
    await repo.reset(
      'h',
      DateTime(2027, 1),
      expectedVersion: '7d1c0b9e-0000-4000-8000-000000000001',
    );
  });

  test('다른 사람이 먼저 바꾼 경우 충돌 예외로 알린다', () async {
    final repo = await repositoryFor((request) async {
      writeJson(request, {
        'code': 'PT409',
        'message': 'Budget was changed by someone else',
      }, status: 409);
    });
    await expectLater(
      repo.save(
        'h',
        DateTime(2026, 12),
        amount: 0,
        allocations: const {},
        expectedVersion: 'old',
      ),
      throwsA(isA<BudgetConflictException>()),
    );
    await expectLater(
      repo.reset('h', DateTime(2026, 12), expectedVersion: 'old'),
      throwsA(isA<BudgetConflictException>()),
    );
  });

  test('잘못된 금액과 총예산을 넘는 배분은 요청 전에 거부한다', () async {
    final repo = SupabaseMonthlyBudgetRepository(null);
    for (final (amount, allocations) in [
      (-1, <String, int>{}),
      (2147483648, <String, int>{}),
      (100, {'food': -1}),
      (100, {'food': 60, 'bus': 41}),
    ]) {
      await expectLater(
        repo.save(
          'h',
          DateTime(2026, 12),
          amount: amount,
          allocations: allocations,
          expectedVersion: null,
        ),
        throwsArgumentError,
      );
    }
  });

  test('예산 권한/서버 오류를 미설정이나 저장 성공으로 처리하지 않는다', () async {
    final repo = await repositoryFor((request) async {
      writeJson(request, {'message': 'denied', 'code': '42501'}, status: 403);
    });
    await expectLater(
      repo.find('h', DateTime(2026, 12)),
      throwsA(isA<PostgrestException>()),
    );
    await expectLater(
      repo.save(
        'h',
        DateTime(2026, 12),
        amount: 0,
        allocations: const {},
        expectedVersion: null,
      ),
      throwsA(isA<PostgrestException>()),
    );
  });
}
