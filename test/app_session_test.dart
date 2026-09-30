import 'package:flutter_test/flutter_test.dart';

import 'package:naroo/core/session/app_session.dart';
import 'package:naroo/data/models/household_member.dart';
import 'package:naroo/data/models/profile.dart';

void main() {
  test('signedOut 상태는 로그인되지 않은 것으로 본다', () {
    const session = AppSession.signedOut();
    expect(session.isSignedIn, isFalse);
    expect(session.status, AppSessionStatus.signedOut);
  });

  test('needsHousehold와 ready는 로그인된 상태로 본다', () {
    const profile = Profile(id: 'u1', displayName: 'A');
    const needsHousehold = AppSession.needsHousehold(
      userId: 'u1',
      profile: profile,
    );
    const ready = AppSession.ready(
      userId: 'u1',
      profile: profile,
      member: HouseholdMember(
        id: 'm1',
        householdId: 'h1',
        userId: 'u1',
        displayName: 'A',
      ),
    );

    expect(needsHousehold.isSignedIn, isTrue);
    expect(ready.isSignedIn, isTrue);
    expect(ready.member?.householdId, 'h1');
  });
}
