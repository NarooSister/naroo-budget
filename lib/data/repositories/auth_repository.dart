import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthRepository {
  AuthRepository(this._client);

  final SupabaseClient? _client;

  bool get isConfigured => _client != null;

  Session? get currentSession => _client?.auth.currentSession;

  Stream<Session?> authSessionChanges() {
    final client = _client;
    if (client == null) {
      return Stream<Session?>.value(null);
    }

    return client.auth.onAuthStateChange.map((event) => event.session);
  }

  Future<void> signInWithGoogle() async {
    final client = _requireClient();

    final launched = await client.auth.signInWithOAuth(
      OAuthProvider.google,
      redirectTo: _oauthRedirectTo,
    );

    if (!launched) {
      throw StateError('Google 로그인을 시작하지 못했습니다.');
    }
  }

  Future<void> signOut() async {
    final client = _requireClient();
    await client.auth.signOut();
  }

  String? get _oauthRedirectTo {
    // MVP targets Flutter Web / PWA first.
    if (kIsWeb) {
      return Uri.base.origin;
    }
    return null;
  }

  SupabaseClient _requireClient() {
    final client = _client;
    if (client == null) {
      throw StateError(
        'Supabase가 설정되지 않았습니다. '
        'SUPABASE_URL / SUPABASE_ANON_KEY를 전달하세요.',
      );
    }
    return client;
  }
}
