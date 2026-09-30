import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:naroo/data/repositories/auth_repository.dart';

import 'support/supabase_test_server.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final outcome in ['success', 'false', 'exception']) {
    test('Google 인증 URL 실행 $outcome 결과를 전달한다', () async {
      final client = await localSupabaseClient((request) async {
        fail('OAuth 시작은 서버 요청 없이 URL을 실행해야 한다');
      });
      final repository = AuthRepository(client);
      var calls = 0;
      const channel = MethodChannel('plugins.flutter.io/url_launcher');
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls++;
        expect(call.method, 'launch');
        final url = Uri.parse((call.arguments as Map)['url'] as String);
        expect(url.path, '/auth/v1/authorize');
        expect(url.queryParameters['provider'], 'google');
        expect(url.queryParameters.containsKey('redirect_to'), false);
        if (outcome == 'exception') {
          throw PlatformException(code: 'launch_failed');
        }
        return outcome == 'success';
      });
      addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
      if (outcome == 'success') {
        await repository.signInWithGoogle();
      } else {
        await expectLater(
          repository.signInWithGoogle(),
          throwsA(
            outcome == 'false' ? isA<StateError>() : isA<PlatformException>(),
          ),
        );
      }
      expect(calls, 1);
    });
  }
}
