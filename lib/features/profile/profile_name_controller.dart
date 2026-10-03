import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/household_member_changes.dart';
import '../../core/session/app_session.dart';
import '../../core/transaction_changes.dart';
import '../../data/repository_providers.dart';

final profileNameEditorProvider =
    NotifierProvider.autoDispose<ProfileNameEditor, bool>(
      ProfileNameEditor.new,
    );

class ProfileNameEditor extends Notifier<bool> {
  @override
  bool build() => false;

  Future<bool> save(String name) async {
    if (state) return false;
    final link = ref.keepAlive();
    state = true;
    try {
      await ref.read(profileRepositoryProvider).saveName(name);
      if (ref.mounted) {
        // The linked member name changes with the profile on the server.
        ref.read(householdMemberChangesProvider.notifier).changed();
        ref.read(transactionChangesProvider.notifier).changed();
        ref.invalidate(appSessionProvider);
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
