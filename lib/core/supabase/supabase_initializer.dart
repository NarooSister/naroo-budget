import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Reads Supabase credentials from compile-time environment values.
///
/// Preferred local usage (secrets stay out of git):
/// 1. `cp env/supabase.example.json env/supabase.json`
/// 2. fill in real values
/// 3. `./scripts/run_web.sh`
///    or `flutter run --dart-define-from-file=env/supabase.json`
///
/// Values can also be passed directly:
/// `--dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...`
abstract final class SupabaseConfig {
  static const url = String.fromEnvironment('SUPABASE_URL');

  /// Public anon / publishable key. Never put the service role key here.
  static const anonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  static bool get isConfigured => url.isNotEmpty && anonKey.isNotEmpty;
}

bool _supabaseReady = false;

bool get isSupabaseReady => _supabaseReady;

/// Initializes Supabase when credentials are provided.
Future<void> initializeSupabase() async {
  if (!SupabaseConfig.isConfigured) {
    _supabaseReady = false;
    return;
  }

  await Supabase.initialize(
    url: SupabaseConfig.url,
    publishableKey: SupabaseConfig.anonKey,
  );
  _supabaseReady = true;
}

final supabaseClientProvider = Provider<SupabaseClient?>((ref) {
  if (!_supabaseReady) {
    return null;
  }
  return Supabase.instance.client;
});
