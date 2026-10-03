# 아키텍처

**MVP 개발과 구조 정리를 완료했다.** 현재 규모에 맞는 경계를 유지하고, 실제로 기능이 커지는 부분만 확장한다.

## 기술과 흐름

- Flutter Web/PWA, Dart, Riverpod
- Supabase Auth·PostgreSQL·RLS, Cloudflare Pages
- 기본 흐름: UI → Riverpod Notifier/Provider → Repository → Supabase

| 책임 | 위치와 규칙 |
| --- | --- |
| 앱 구성 | `app/`: 라우터·경로·탭·테마 |
| UI와 상태 | `features/`: 기능별 화면·Controller·전용 계산/위젯 |
| 공유 규칙 | `core/`: 실제 여러 기능이 사용하는 금액·날짜·세션·변경 알림 |
| 데이터 모델 | `data/models/`: 앱 모델과 JSON 변환 |
| 데이터 계약 | `data/repositories/`: 거래·카테고리·구성원·월 예산 인터페이스 |
| 외부 구현 | `data/supabase/`: Supabase 쿼리·직렬화 |
| 의존성 조립 | `data/repository_providers.dart`: 구현 선택과 Provider 생성만 담당 |

UI는 Supabase 쿼리와 주요 업무 계산을 하지 않는다. Repository 계약과 구현은 Riverpod에 의존하지 않는다. Auth/Profile은 현재 작은 구체 클래스로 유지하며 SDK 의존은 데이터 접근·공통 세션 해석에 한정한다.

## 기능 경계

- 입력 원문·포커스·펼침 상태는 화면 로컬에 둔다. 공유 상태만 Provider로 관리한다.
- 한 기능에서만 쓰는 계산·위젯은 해당 feature에 둔다. 다른 feature의 내부 Controller를 직접 호출하지 않는다.
- 금액 규칙은 `core/amount_rules.dart`, 홈 계산은 `features/home/home_summary.dart`에 둔다.
- 세션은 `core/session/app_session.dart`, 경로 상수는 `app/app_routes.dart`를 사용한다.
- 세션은 로그인 없음 → 로그인/Household 미연결 → 연결 완료를 구분한다. 로그인 후 Profile을 확인/생성하고 HouseholdMember를 확인한다. `AppSession.needsName`이면 라우터가 연결 상태보다 먼저 이름 설정으로 보낸다.

## 데이터와 갱신

- 테이블: profiles, households, household_members, categories, transactions, monthly_budgets.
- 카테고리는 가계부별 독립 데이터이며 초기 추천값을 복사한다. 공통 분류 정의/사용 설정 테이블은 두지 않는다. 거래의 가계부·유형 중복은 접근 제어와 조회를 위한 의도적 중복이며 참조 트리거와 카테고리 식별자 불변 규칙으로 보호한다.
- `categories.is_uncategorized`와 가계부·유형별 부분 UNIQUE 인덱스로 미분류를 식별한다. 기존 가계부는 migration, 새 가계부는 생성 트리거로 수입·지출 미분류를 만든다. 미분류의 이름·식별자는 보호하고 카테고리 직접 DELETE는 허용하지 않는다.
- `delete_category` RPC는 로그인·가계부 가입을 검사하고 대상 행을 잠근 뒤 거래 재분류와 삭제를 원자적으로 처리한다. SECURITY DEFINER·빈 search_path·authenticated 전용 EXECUTE를 사용한다. 거래 ID·금액·날짜·메모·귀속은 유지한다. FK가 삭제 중 신규 참조의 고아화를 막으며 충돌한 저장은 실패 후 재조회한다.
- 소분류는 `categories.parent_id`(삭제 시 CASCADE), 거래의 소분류는 nullable `transactions.subcategory_id`다. `category_id`는 항상 대분류다. `validate_category_parent` 트리거가 같은 가계부·유형, 2단계, 미분류 부모/자식 금지를 검사하고, `validate_transaction_refs`가 대분류 여부와 소분류의 부모 일치를 검사한다. 같은 트리거는 authenticated/anon 역할이 미분류를 새로 선택하는 INSERT·category_id 변경을 막는다. 미분류 이동은 `delete_category`(SECURITY DEFINER)만 한다.
- `delete_category`는 소분류면 거래의 subcategory_id만 비우고 삭제한다. 대분류면 거래를 미분류로 옮기고 subcategory_id를 비운 뒤 소분류와 대분류를 삭제한다. 목록 조회는 FK 이름으로 대분류/소분류 embed를 구분한다.
- 카테고리는 생성 시 가계부·유형·이름·부모만, 수정 시 이름만 직접 쓸 수 있다. ID·소속·유형·부모·미분류 여부는 변경 불가하다. 기본/숨김 플래그는 제거했다. 조회는 미분류를 마지막에 두고 created_at·id로 동률을 해소한다. 사용자 정렬 순서는 별도 기능이다.
- 카테고리 변경 시 `categoryChangesProvider`로 입력 선택지를 갱신한다. 이름 변경·삭제는 `transactionChangesProvider`에도 알려 홈·내역을 다시 조회한다. 이름은 현재 카테고리/구성원에서 읽으며 과거 이름 스냅샷을 저장하지 않는다.
- `profiles.name_confirmed_at`이 이름 확인 여부이며 CHECK가 확인된 이름의 공백·1~30자(char_length)를 보장한다. 클라이언트는 프로필 INSERT(id, display_name)만 직접 하고 수정은 `set_profile_name` RPC만 쓴다. RPC는 프로필 upsert와 로그인 구성원 이름 동기화를 한 트랜잭션에서 처리하고, `household_members` 연결 트리거는 확인된 이름을 새 연결에 적용한다. 앱은 같은 기준을 `core/profile_name_rules.dart`(코드 포인트 수)로 검사하고 저장 후 세션을 다시 해석하며 구성원·거래 변경을 알린다.
- 계정 없는 구성원은 `household_members.user_id IS NULL`이며 가입 판정은 로그인 사용자 ID로만 한다. 구성원 직접 쓰기는 차단하고 임의 구성원 전용 RPC로 이름·숨김만 관리한다. `transactions.attribution_kind`는 member/shared이며 member_id와 CHECK로 일관성을 유지한다.
- 구성원 RPC는 `SECURITY DEFINER`·`search_path = ''`로 만들고 `auth.uid()`와 가계부 가입을 검사한다. 대상은 `user_id IS NULL`인 구성원뿐이며 user_id·household_id는 바꾸지 않는다. EXECUTE는 authenticated에만 허용한다. 구성원은 삭제하지 않고 숨긴다. 로그인 구성원은 숨길 수 없다.
- `validate_transaction_refs` 트리거가 거래의 구성원·카테고리가 같은 가계부인지 검사하고, 숨긴 구성원을 새로 지정하는 것을 막는다.
- 구성원 쓰기 성공 시 `householdMemberChangesProvider`로 설정·입력 선택지·홈·내역을 갱신한다. 숨김은 기존 거래와 합계에 영향을 주지 않는다.
- 거래 날짜는 PostgreSQL DATE, 서울 기준이다. created_at/updated_at은 거래 날짜 계산에 사용하지 않는다.
- 월 예산의 유일 키는 household_id + year + month다.
- 금액·월·Household 규칙은 [제품 문서](docs/PRODUCT.md)를 따른다. 접근 제어는 RLS로 보장하며 클라이언트에 service role key를 넣지 않는다.
- 거래 쓰기 성공 시 `transactionChangesProvider`에 알리고 홈·내역이 각자 갱신한다. 실패 시 성공 알림을 보내지 않는다.
- 쓰기 중 화면을 떠나도 완료·알림을 처리하고 중복 저장을 막는다. 수정 대상의 조회 실패/없음 상태에서는 쓰기를 막는다.
- 탭 재진입·홈 앱 복귀·수동 새로고침으로 외부 변경을 확인한다. 홈은 현재 서울 월, 내역은 독립적인 선택 월·필터를 유지한다.
- schema는 migration으로 관리하고 초기 사용자 연결 SQL은 bootstrap으로 분리한다.

## 확장 기준

- 작은 기능은 기존 화면/Controller/Repository 흐름을 사용한다.
- 독립적인 사용자 목적은 새 feature로 추가한다.
- 복잡한 계산·검증은 해당 feature의 순수 Dart 코드로 분리한다. 실제 여러 기능에서 쓰이면 core로 옮긴다.
- 여러 Repository를 조합하거나 여러 화면에서 재사용하는 복잡한 흐름이 생기면 해당 기능에 application 책임을 추가한다.
- 풍부한 업무 규칙이 필요해지면 해당 기능의 domain을 분리한다. 단순 위임 UseCase, Entity/DTO 이중 모델과 빈 계층은 미리 만들지 않는다.
- 외부 API·캐시·오프라인 저장은 Repository 구현으로 확장한다. 여러 데이터 원천을 조합할 때 DataSource를 고려한다.

현재 별도 API 서버, Realtime, 오프라인 동기화 엔진은 사용하지 않는다. 완료 상태는 [MVP 완료 요약](docs/MVP.md), 작업 규칙은 [AGENTS.md](AGENTS.md)를 따른다.
