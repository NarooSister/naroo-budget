import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Exercises real SDK requests without credentials or production data.
Future<SupabaseClient> localSupabaseClient(
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
    authOptions: AuthClientOptions(
      autoRefreshToken: false,
      pkceAsyncStorage: _MemoryStorage(),
    ),
  );
  addTearDown(() async {
    await client.dispose();
    await server.close(force: true);
  });
  return client;
}

class _MemoryStorage extends GotrueAsyncStorage {
  final _values = <String, String>{};
  @override
  Future<String?> getItem({required String key}) async => _values[key];
  @override
  Future<void> setItem({required String key, required String value}) async {
    _values[key] = value;
  }

  @override
  Future<void> removeItem({required String key}) async {
    _values.remove(key);
  }
}

void respond(HttpRequest request, Object body, {int status = 200}) {
  request.response.statusCode = status;
  request.response.headers.contentType = ContentType.json;
  request.response.write(jsonEncode(body));
}
