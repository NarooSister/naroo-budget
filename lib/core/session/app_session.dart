import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/models/household_member.dart';
import '../../data/models/profile.dart';
import '../../data/repository_providers.dart';

enum AppSessionStatus { signedOut, needsHousehold, ready }

class AppSession {
  const AppSession._({
    required this.status,
    this.userId,
    this.email,
    this.profile,
    this.member,
  });

  const AppSession.signedOut() : this._(status: AppSessionStatus.signedOut);

  const AppSession.needsHousehold({
    required String userId,
    String? email,
    required Profile profile,
  }) : this._(
         status: AppSessionStatus.needsHousehold,
         userId: userId,
         email: email,
         profile: profile,
       );

  const AppSession.ready({
    required String userId,
    String? email,
    required Profile profile,
    required HouseholdMember member,
  }) : this._(
         status: AppSessionStatus.ready,
         userId: userId,
         email: email,
         profile: profile,
         member: member,
       );

  final AppSessionStatus status;
  final String? userId;
  final String? email;
  final Profile? profile;
  final HouseholdMember? member;

  bool get isSignedIn => status != AppSessionStatus.signedOut;
}

final authSessionProvider = StreamProvider<Session?>((ref) {
  return ref.watch(authRepositoryProvider).authSessionChanges();
});

final appSessionProvider =
    AsyncNotifierProvider<AppSessionNotifier, AppSession>(
      AppSessionNotifier.new,
    );

class AppSessionNotifier extends AsyncNotifier<AppSession> {
  @override
  Future<AppSession> build() async {
    ref.listen<AsyncValue<Session?>>(authSessionProvider, (previous, next) {
      final previousUserId = previous?.asData?.value?.user.id;
      final nextUserId = next.asData?.value?.user.id;
      if (previousUserId != nextUserId) {
        ref.invalidateSelf();
      }
    });

    return _resolve();
  }

  Future<AppSession> _resolve() async {
    final authRepository = ref.read(authRepositoryProvider);
    final session = authRepository.currentSession;

    if (session == null) {
      return const AppSession.signedOut();
    }

    final profile = await ref
        .read(profileRepositoryProvider)
        .ensureProfile(session.user);

    final member = await ref
        .read(householdMemberRepositoryProvider)
        .findByUserId(session.user.id);

    if (member == null) {
      return AppSession.needsHousehold(
        userId: session.user.id,
        email: session.user.email,
        profile: profile,
      );
    }

    return AppSession.ready(
      userId: session.user.id,
      email: session.user.email,
      profile: profile,
      member: member,
    );
  }

  Future<void> signInWithGoogle() {
    return ref.read(authRepositoryProvider).signInWithGoogle();
  }

  Future<void> signOut() {
    return ref.read(authRepositoryProvider).signOut();
  }
}
