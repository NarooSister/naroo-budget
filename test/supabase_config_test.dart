import 'package:flutter_test/flutter_test.dart';
import 'package:naroo/core/supabase/supabase_initializer.dart';

void main() {
  test('기본 빌드에서는 Supabase 환경값이 비어 있다', () {
    expect(SupabaseConfig.url, isEmpty);
    expect(SupabaseConfig.anonKey, isEmpty);
    expect(SupabaseConfig.isConfigured, isFalse);
  });
}
