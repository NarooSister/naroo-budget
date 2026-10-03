import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/session/app_session.dart';
import '../../core/household_member_changes.dart';
import '../../data/models/household_member.dart';
import '../../data/models/payment_method.dart';
import '../../data/repository_providers.dart';

final settingsMembersProvider =
    FutureProvider.autoDispose<List<HouseholdMember>>((ref) async {
      ref.listen(
        householdMemberChangesProvider,
        (_, _) => ref.invalidateSelf(),
      );
      final session = await ref.watch(appSessionProvider.future);
      final id = session.member?.householdId;
      if (id == null) return [];
      return ref.read(householdMemberRepositoryProvider).listByHousehold(id);
    });

/// Holds the method being saved so the control does not jump back meanwhile.
final defaultPaymentMethodEditorProvider =
    NotifierProvider.autoDispose<DefaultPaymentMethodEditor, PaymentMethod?>(
      DefaultPaymentMethodEditor.new,
    );

class DefaultPaymentMethodEditor extends Notifier<PaymentMethod?> {
  @override
  PaymentMethod? build() => null;

  Future<bool> save(PaymentMethod method) async {
    if (state != null) return false;
    final link = ref.keepAlive();
    state = method;
    try {
      final session = await ref.read(appSessionProvider.future);
      final userId = session.userId;
      if (userId == null) throw StateError('로그인이 필요합니다.');
      await ref
          .read(profileRepositoryProvider)
          .saveDefaultPaymentMethod(userId: userId, method: method);
      if (ref.mounted) {
        ref.invalidate(appSessionProvider);
        // The save already succeeded; a failed reload is shown by the session.
        await ref
            .read(appSessionProvider.future)
            .then<void>((_) {}, onError: (_) {});
      }
      return true;
    } catch (_) {
      return false;
    } finally {
      if (ref.mounted) state = null;
      link.close();
    }
  }
}

final memberEditorProvider = NotifierProvider.autoDispose<MemberEditor, bool>(
  MemberEditor.new,
);

class MemberEditor extends Notifier<bool> {
  @override
  bool build() => false;

  Future<bool> saveName({HouseholdMember? member, required String name}) {
    return _write(() async {
      final repository = ref.read(householdMemberRepositoryProvider);
      if (member != null) {
        if (!member.isCustom) throw StateError('계정 구성원은 변경할 수 없습니다.');
        await repository.renameCustom(memberId: member.id, name: name);
      } else {
        final session = await ref.read(appSessionProvider.future);
        final householdId = session.member?.householdId;
        if (householdId == null) throw StateError('가계부 연결이 필요합니다.');
        await repository.createCustom(householdId: householdId, name: name);
      }
    });
  }

  Future<bool> setHidden(HouseholdMember member, bool hidden) {
    return _write(() async {
      if (!member.isCustom) throw StateError('계정 구성원은 변경할 수 없습니다.');
      await ref
          .read(householdMemberRepositoryProvider)
          .setCustomHidden(memberId: member.id, isHidden: hidden);
    });
  }

  Future<bool> _write(Future<void> Function() write) async {
    if (state) return false;
    final link = ref.keepAlive();
    state = true;
    try {
      await write();
      if (ref.mounted) {
        ref.read(householdMemberChangesProvider.notifier).changed();
      }
      return true;
    } catch (_) {
      return false;
    } finally {
      if (ref.mounted) state = false;
      link.close();
    }
  }
}
