# Naroo

부부가 함께 쓰는 Flutter 가계부 앱입니다. 현재는 기능 추가와 유지보수 단계입니다.


## 실행

Flutter 3.47.5 stable을 사용합니다.

1. `flutter pub get`으로 의존성을 설치합니다.
2. `env/supabase.example.json`을 `env/supabase.json`으로 복사하고 Supabase URL과 공개 키를 입력합니다.
3. 아래 명령으로 실행합니다.

```bash
flutter run -d chrome --dart-define-from-file=env/supabase.json
```

## 검증과 CI

```bash
flutter analyze
flutter test
```

GitHub CI는 push·PR에서 정적 분석과 테스트를 실행합니다.

웹 릴리스 빌드가 필요할 때 실행합니다.

```bash
flutter build web --no-pub --dart-define-from-file=env/supabase.json
```

## DB와 운영

- 스키마: `supabase/migrations/`
- 새 환경의 초기 Household 연결: `supabase/bootstrap/` SQL 템플릿을 관리자 역할로 한 번 실행합니다. 기존 연결에 재실행하지 않습니다.
- RLS 검증: `supabase/tests/rls_shared_crud.sql`은 임시 데이터로 검사하고 rollback합니다.
- 웹 배포: Cloudflare Pages. 배포 상태는 CI와 별도로 확인합니다.
