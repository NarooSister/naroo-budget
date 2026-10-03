import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:naroo/data/models/category.dart';
import 'package:naroo/data/supabase/supabase_category_repository.dart';

void main() {
  Future<SupabaseCategoryRepository> repositoryFor(
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
    return SupabaseCategoryRepository(client);
  }

  test('실제 카테고리 조회는 Household/타입으로 제한하고 응답을 변환한다', () async {
    final repository = await repositoryFor((request) async {
      expect(request.method, 'GET');
      expect(request.uri.path, '/rest/v1/categories');
      final query = request.uri.queryParameters;
      expect(query['household_id'], 'eq.h1');
      expect(query['type'], 'eq.expense');
      expect(query.containsKey('is_hidden'), false);
      expect(
        query['order'],
        'is_uncategorized.asc.nullslast,created_at.asc.nullslast,id.asc.nullslast',
      );
      _respond(request, [_row()]);
    });
    final items = await repository.listByHousehold(
      'h1',
      type: CategoryType.expense,
    );
    expect(items.single.id, 'c1');
    expect(items.single.householdId, 'h1');
    expect(items.single.name, '식비');
    expect(items.single.type, CategoryType.expense);
    expect(items.single.isUncategorized, false);
  });

  test('전체 카테고리 조회는 타입/숨김 필터를 붙이지 않는다', () async {
    final repository = await repositoryFor((request) async {
      final query = request.uri.queryParameters;
      expect(query['household_id'], 'eq.h1');
      expect(query.containsKey('type'), false);
      expect(query.containsKey('is_hidden'), false);
      _respond(request, []);
    });
    expect(await repository.listByHousehold('h1'), isEmpty);
  });

  test('사용자 카테고리 생성은 공백을 제거하고 시스템 필드를 전송하지 않는다', () async {
    final repository = await repositoryFor((request) async {
      expect(request.method, 'POST');
      expect(await _body(request), {
        'household_id': 'h1',
        'type': 'income',
        'name': '용돈',
      });
      _respond(request, _row(name: '용돈', type: 'income'));
    });
    final item = await repository.create(
      householdId: 'h1',
      type: CategoryType.income,
      name: ' 용돈 ',
    );
    expect(item.name, '용돈');
    expect(item.type, CategoryType.income);
  });

  test('미분류 이름 수정은 조회 후 쓰기 요청 없이 거부한다', () async {
    var calls = 0;
    final repository = await repositoryFor((request) async {
      calls++;
      expect(request.method, 'GET');
      expect(request.uri.queryParameters['id'], 'eq.c1');
      _respond(request, _row(isUncategorized: true));
    });
    await expectLater(
      repository.rename(categoryId: 'c1', name: '식비 수정'),
      throwsStateError,
    );
    expect(calls, 1);
  });

  test('사용자 카테고리 이름 수정은 동일 ID를 조회하고 수정한다', () async {
    final methods = <String>[];
    final repository = await repositoryFor((request) async {
      methods.add(request.method);
      expect(request.uri.queryParameters['id'], 'eq.c1');
      if (request.method == 'GET') {
        _respond(request, _row());
      } else {
        expect(request.method, 'PATCH');
        expect(await _body(request), {'name': '구독'});
        _respond(request, _row(name: '구독'));
      }
    });
    expect(
      (await repository.rename(categoryId: 'c1', name: ' 구독 ')).name,
      '구독',
    );
    expect(methods, ['GET', 'PATCH']);
  });

  test('삭제는 건수 조회 없이 RPC 한 번으로 요청한다', () async {
    var calls = 0;
    final repository = await repositoryFor((request) async {
      calls++;
      expect(request.method, 'POST');
      expect(request.uri.path, '/rest/v1/rpc/delete_category');
      expect(await _body(request), {'target_category_id': 'c1'});
      request.response.statusCode = 204;
    });
    await repository.delete('c1');
    expect(calls, 1);
  });

  test('빈 이름은 생성/수정 모두 HTTP 요청 전에 거부한다', () async {
    var calls = 0;
    final repository = await repositoryFor((request) async {
      calls++;
      _respond(request, _row());
    });
    await expectLater(
      repository.create(
        householdId: 'h1',
        type: CategoryType.expense,
        name: '  ',
      ),
      throwsArgumentError,
    );
    await expectLater(
      repository.rename(categoryId: 'c1', name: '  '),
      throwsArgumentError,
    );
    expect(calls, 0);
  });

  test('실제 조회/생성/수정/삭제의 서버 오류를 성공으로 처리하지 않는다', () async {
    final repository = await repositoryFor((request) async {
      request.response.statusCode = 403;
      _respond(request, {'message': 'denied', 'code': '42501'});
    });
    final error = throwsA(isA<PostgrestException>());
    await expectLater(repository.listByHousehold('h1'), error);
    await expectLater(
      repository.create(
        householdId: 'h1',
        type: CategoryType.expense,
        name: '구독',
      ),
      error,
    );
    await expectLater(repository.rename(categoryId: 'c1', name: '구독'), error);
    await expectLater(repository.delete('c1'), error);
  });
}

Map<String, Object?> _row({
  String name = '식비',
  String type = 'expense',
  bool isUncategorized = false,
}) => {
  'id': 'c1',
  'household_id': 'h1',
  'type': type,
  'name': name,
  'is_uncategorized': isUncategorized,
};

Future<Map<String, dynamic>> _body(HttpRequest request) async =>
    jsonDecode(await utf8.decoder.bind(request).join()) as Map<String, dynamic>;

void _respond(HttpRequest request, Object body) {
  request.response.headers.contentType = ContentType.json;
  request.response.write(jsonEncode(body));
}
