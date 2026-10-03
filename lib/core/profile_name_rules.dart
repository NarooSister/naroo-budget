abstract final class ProfileNameRules {
  static const maxLength = 30;

  /// Counts Unicode code points, matching PostgreSQL char_length.
  static String? validate(String raw) {
    final name = raw.trim();
    if (name.isEmpty) {
      return '이름을 입력해 주세요.';
    }
    if (name.runes.length > maxLength) {
      return '이름은 $maxLength자 이하로 입력해 주세요.';
    }
    return null;
  }
}
