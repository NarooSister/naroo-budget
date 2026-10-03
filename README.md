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
- Supabase GitHub 연동으로 main 브랜치에 반영된 새 migration은 DB에 자동 적용됩니다. 스키마 변경은 새 migration 파일로 추가하고, 이미 적용된 파일은 수정하지 않습니다. 적용 결과는 Supabase 대시보드에서 확인합니다.
- RLS 검증: `supabase/tests/rls_shared_crud.sql`은 임시 데이터로 검사하고 rollback합니다. 자동 실행되지 않으므로 권한 관련 migration이 반영된 뒤 SQL Editor에서 실행합니다.
- 카테고리 검증: `supabase/tests/category_management.sql`에서 미분류 보호·삭제 원자성·다른 가계부 차단·예산 권한을 검사하고 rollback합니다. 동시 저장/삭제는 별도 두 세션에서 확인합니다.
- 카테고리 전환: `20261003090000_category_management.sql`은 기존 ID/거래를 보존하고 숨겼던 카테고리를 다시 표시합니다. 수입·지출 미분류를 별도로 만들며 기존 동명 카테고리를 병합하지 않습니다. 기존 거래와 분류의 소속/유형이 불일치하면 migration을 중단하므로 먼저 데이터를 확인합니다.
- 이번 migration은 카테고리의 is_default/is_hidden을 제거하므로 구버전 앱과 호환되지 않습니다. DB migration과 새 웹 배포를 같은 배포 창에 적용하고 기존 브라우저/PWA를 새로고침합니다. 롤백 시에는 컬럼·앱 호환성을 함께 복구해야 합니다. 운영 DB 적용·RLS 실행 결과는 배포 시 별도로 확인합니다.
- 웹 배포: Cloudflare Pages. 배포 상태는 CI와 별도로 확인합니다.
