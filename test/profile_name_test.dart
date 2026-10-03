import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show User;

import 'package:naroo/app/app.dart';
import 'package:naroo/core/profile_name_rules.dart';
import 'package:naroo/core/session/app_session.dart';
import 'package:naroo/data/models/household_member.dart';
import 'package:naroo/data/models/payment_method.dart';
import 'package:naroo/data/models/profile.dart';
import 'package:naroo/data/repositories/profile_repository.dart';
import 'package:naroo/data/repository_providers.dart';

import 'fake_household_member_repository.dart';

void main() {
  test('이름은 앞뒤 공백 제거 후 1~30자(코드 포인트)다', () {
    expect(ProfileNameRules.validate('   '), '이름을 입력해 주세요.');
    expect(ProfileNameRules.validate(' ${'가' * 30} '), isNull);
    expect(ProfileNameRules.validate('가' * 31), '이름은 30자 이하로 입력해 주세요.');
    expect(ProfileNameRules.validate('😀' * 30), isNull);
    expect(ProfileNameRules.validate('😀' * 31), isNotNull);
  });

  test('이름 확인 전이면 가계부 연결 여부와 관계없이 이름 설정이 필요하다', () {
    const unconfirmed = Profile(id: 'u1', isNameConfirmed: false);
    expect(
      const AppSession.needsHousehold(
        userId: 'u1',
        profile: unconfirmed,
      ).needsName,
      isTrue,
    );
    expect(
      const AppSession.ready(
        userId: 'u1',
        profile: unconfirmed,
        member: _member,
      ).needsName,
      isTrue,
    );
    expect(const AppSession.signedOut().needsName, isFalse);
    expect(
      const AppSession.ready(
        userId: 'u1',
        profile: Profile(id: 'u1', displayName: '나루'),
        member: _member,
      ).needsName,
      isFalse,
    );
  });

  testWidgets('첫 로그인에서 이름을 확인하면 홈으로 이동한다', (tester) async {
    final profiles = _FakeProfileRepository(name: '구글 이름', confirmed: false);
    await _pump(tester, profiles);

    expect(find.widgetWithText(AppBar, '이름 설정'), findsOneWidget);
    expect(_nameField(tester).controller?.text, '구글 이름');

    await tester.enterText(find.byType(TextField), '   ');
    await tester.tap(find.text('시작하기'));
    await tester.pumpAndSettle();
    expect(find.text('이름을 입력해 주세요.'), findsOneWidget);
    expect(profiles.savedNames, isEmpty);

    profiles.fail = true;
    await tester.enterText(find.byType(TextField), ' 나루 ');
    await tester.tap(find.text('시작하기'));
    await tester.pumpAndSettle();
    expect(find.text('이름을 저장하지 못했습니다. 다시 시도해 주세요.'), findsOneWidget);
    expect(_nameField(tester).controller?.text, ' 나루 ');

    profiles.fail = false;
    await tester.tap(find.text('시작하기'));
    await tester.pumpAndSettle();
    expect(profiles.savedNames, [' 나루 ']);
    expect(find.text('NAROO.'), findsOneWidget);
  });

  testWidgets('이메일 대체 이름은 이름 후보로 채우지 않는다', (tester) async {
    await _pump(
      tester,
      _FakeProfileRepository(name: 'user@example.com', confirmed: false),
    );
    expect(_nameField(tester).controller?.text, '');
  });

  testWidgets('설정에서 사용자별 기본 결제 수단을 저장하고 실패를 알린다', (tester) async {
    final profiles = _FakeProfileRepository(name: '나루', confirmed: true);
    await _pump(tester, profiles);
    await tester.tap(find.widgetWithText(NavigationDestination, '설정'));
    await tester.pumpAndSettle();
    expect(_settingsPayment(tester), {PaymentMethod.debitCard});

    await tester.tap(find.text('현금'));
    await tester.pumpAndSettle();
    expect(profiles.savedPaymentMethods, [PaymentMethod.cash]);
    expect(_settingsPayment(tester), {PaymentMethod.cash});

    profiles.fail = true;
    await tester.tap(find.text('신용카드'));
    await tester.pumpAndSettle();
    expect(find.text('기본 결제 수단을 저장하지 못했습니다. 다시 시도해 주세요.'), findsOneWidget);
    expect(_settingsPayment(tester), {PaymentMethod.cash});
  });

  testWidgets('설정에서 이름을 바꾸면 설정 화면에 반영된다', (tester) async {
    final profiles = _FakeProfileRepository(name: '나루', confirmed: true);
    await _pump(tester, profiles);

    await tester.tap(find.widgetWithText(NavigationDestination, '설정'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('이름 변경'));
    await tester.pumpAndSettle();
    expect(find.text('이름 변경'), findsWidgets);
    expect(_nameField(tester).controller?.text, '나루');

    await tester.enterText(find.byType(TextField), '새 이름');
    await tester.tap(find.text('저장'));
    await tester.pumpAndSettle();
    expect(profiles.savedNames, ['새 이름']);
    expect(find.byType(BottomSheet), findsNothing);
    expect(find.text('새 이름'), findsOneWidget);
  });
}

Set<PaymentMethod> _settingsPayment(WidgetTester tester) => tester
    .widget<SegmentedButton<PaymentMethod>>(
      find.byType(SegmentedButton<PaymentMethod>),
    )
    .selected;

TextField _nameField(WidgetTester tester) =>
    tester.widget<TextField>(find.byType(TextField));

const _member = HouseholdMember(
  id: 'm1',
  householdId: 'h1',
  userId: 'u1',
  displayName: '나루',
);

Future<void> _pump(WidgetTester tester, _FakeProfileRepository profiles) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        profileRepositoryProvider.overrideWithValue(profiles),
        householdMemberRepositoryProvider.overrideWithValue(
          FakeHouseholdMemberRepository([_member]),
        ),
        appSessionProvider.overrideWith(() => _ProfileSession(profiles)),
      ],
      child: const NarooApp(),
    ),
  );
  await tester.pumpAndSettle();
}

class _ProfileSession extends AppSessionNotifier {
  _ProfileSession(this._profiles);

  final _FakeProfileRepository _profiles;

  @override
  Future<AppSession> build() async => AppSession.ready(
    userId: 'u1',
    email: 'user@example.com',
    profile: Profile(
      id: 'u1',
      displayName: _profiles.name,
      isNameConfirmed: _profiles.confirmed,
      defaultPaymentMethod: _profiles.paymentMethod,
    ),
    member: _member,
  );

  @override
  Future<void> signInWithGoogle() async {}

  @override
  Future<void> signOut() async {}
}

class _FakeProfileRepository extends ProfileRepository {
  _FakeProfileRepository({required this.name, required this.confirmed})
    : super(null);

  String name;
  bool confirmed;
  bool fail = false;
  final savedNames = <String>[];

  @override
  Future<Profile> ensureProfile(User user) async =>
      Profile(id: user.id, displayName: name, isNameConfirmed: confirmed);

  PaymentMethod paymentMethod = PaymentMethod.debitCard;
  final savedPaymentMethods = <PaymentMethod>[];

  @override
  Future<Profile> saveDefaultPaymentMethod({
    required String userId,
    required PaymentMethod method,
  }) async {
    if (fail) throw StateError('save failed');
    expect(userId, 'u1');
    savedPaymentMethods.add(method);
    paymentMethod = method;
    return Profile(id: userId, displayName: name, defaultPaymentMethod: method);
  }

  @override
  Future<Profile> saveName(String value) async {
    if (fail) throw StateError('save failed');
    savedNames.add(value);
    name = value.trim();
    confirmed = true;
    return Profile(id: 'u1', displayName: name);
  }
}
