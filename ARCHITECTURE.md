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
- 세션은 로그인 없음 → 로그인/Household 미연결 → 연결 완료를 구분한다. 로그인 후 Profile을 확인/생성하고 HouseholdMember를 확인한다.

## 데이터와 갱신

- 테이블: profiles, households, household_members, categories, transactions, monthly_budgets.
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
