import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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

  for (final amount in [null, 0, 2147483647]) {
    test('예산 $amount 조회는 Household/연도/월로 제한한다', () async {
      final repo = await repositoryFor((request) async {
        expect(request.uri.path, '/rest/v1/monthly_budgets');
        expect(request.uri.queryParameters['household_id'], 'eq.h');
        expect(request.uri.queryParameters['year'], 'eq.2027');
        expect(request.uri.queryParameters['month'], 'eq.1');
        request.response.headers.contentType = ContentType.json;
        request.response.write(
          jsonEncode(
            amount == null
                ? []
                : [
                    {'amount': amount},
                  ],
          ),
        );
      });
      expect(await repo.find('h', DateTime(2027, 1)), amount);
    });
  }
  test('예산 생성과 수정은 월 unique key로 upsert한다', () async {
    final repo = await repositoryFor((request) async {
      expect(request.method, 'POST');
      expect(
        request.uri.queryParameters['on_conflict'],
        'household_id,year,month',
      );
      expect(
        request.headers.value('prefer'),
        contains('resolution=merge-duplicates'),
      );
      final body = jsonDecode(await utf8.decoder.bind(request).join());
      expect(body, {
        'household_id': 'h',
        'year': 2026,
        'month': 12,
        'amount': 0,
      });
      request.response.headers.contentType = ContentType.json;
      request.response.write(jsonEncode({'amount': 0}));
    });
    await repo.save('h', DateTime(2026, 12), 0);
  });
  test('잘못된 금액은 요청 전에 거부한다', () async {
    final repo = SupabaseMonthlyBudgetRepository(null);
    for (final value in [-1, 2147483648]) {
      await expectLater(
        repo.save('h', DateTime(2026, 12), value),
        throwsArgumentError,
      );
    }
  });
  test('예산 권한/서버 오류를 미설정이나 저장 성공으로 처리하지 않는다', () async {
    final repo = await repositoryFor((request) async {
      request.response.statusCode = 403;
      request.response.headers.contentType = ContentType.json;
      request.response.write(
        jsonEncode({'message': 'denied', 'code': '42501'}),
      );
    });
    await expectLater(
      repo.find('h', DateTime(2026, 12)),
      throwsA(isA<PostgrestException>()),
    );
    await expectLater(
      repo.save('h', DateTime(2026, 12), 0),
      throwsA(isA<PostgrestException>()),
    );
  });
}
