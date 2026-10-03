import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/session/app_session.dart';
import '../../core/household_member_changes.dart';
import '../../core/transaction_changes.dart';
import '../../core/category_changes.dart';
import '../../data/models/category.dart';
import '../../data/models/household_member.dart';
import '../../data/models/transaction.dart';
import '../../data/repository_providers.dart';

final transactionMembersProvider =
    FutureProvider.autoDispose<List<HouseholdMember>>((ref) async {
      ref.listen(
        householdMemberChangesProvider,
        (_, _) => ref.invalidateSelf(),
      );
      final session = await ref.watch(appSessionProvider.future);
      final householdId = session.member?.householdId;
      if (householdId == null) {
        return const [];
      }
      return ref
          .read(householdMemberRepositoryProvider)
          .listByHousehold(householdId);
    });

final transactionCategoriesProvider = FutureProvider.autoDispose
    .family<List<Category>, CategoryType>((ref, type) async {
      ref.watch(categoryChangesProvider);
      final session = await ref.watch(appSessionProvider.future);
      final householdId = session.member?.householdId;
      if (householdId == null) {
        return const [];
      }

      return ref
          .read(categoryRepositoryProvider)
          .listByHousehold(householdId, type: type);
    });

enum TransactionEditorAction { idle, loading, saving, deleting }

class TransactionEditorState {
  const TransactionEditorState({
    this.action = TransactionEditorAction.idle,
    this.errorMessage,
    this.canWrite = true,
  });

  final TransactionEditorAction action;
  final String? errorMessage;
  final bool canWrite;

  bool get isBusy => action != TransactionEditorAction.idle;
}

final transactionEditorProvider = NotifierProvider.autoDispose
    .family<TransactionEditorController, TransactionEditorState, String?>(
      TransactionEditorController.new,
    );

class TransactionEditorController extends Notifier<TransactionEditorState> {
  TransactionEditorController(this.transactionId);

  final String? transactionId;
  Future<bool>? _pendingWrite;

  @override
  TransactionEditorState build() => TransactionEditorState(
    canWrite: transactionId == null,
    action: transactionId == null
        ? TransactionEditorAction.idle
        : TransactionEditorAction.loading,
  );

  Future<Transaction?> loadExisting() async {
    final id = transactionId;
    if (id == null) {
      return null;
    }
    final link = ref.keepAlive();
    try {
      // Reopening the same editor must not reset an in-flight write's busy
      // state or load the old server row before that write has completed.
      await _pendingWrite;
      if (!ref.mounted) {
        return null;
      }
      state = const TransactionEditorState(
        action: TransactionEditorAction.loading,
        canWrite: false,
      );
      final transaction = await ref
          .read(transactionRepositoryProvider)
          .findById(id);
      if (ref.mounted) {
        state = TransactionEditorState(
          canWrite: transaction != null,
          errorMessage: transaction == null ? '기록을 찾을 수 없습니다.' : null,
        );
      }
      return transaction;
    } catch (_) {
      if (ref.mounted) {
        state = const TransactionEditorState(
          canWrite: false,
          errorMessage: '기록을 불러오지 못했습니다.',
        );
      }
      return null;
    } finally {
      link.close();
    }
  }

  Future<bool> save(NewTransaction input) async {
    if (state.isBusy || !state.canWrite) {
      return false;
    }
    return _pendingWrite = _write(TransactionEditorAction.saving, () async {
      final repository = ref.read(transactionRepositoryProvider);
      final id = transactionId;
      if (id == null) {
        await repository.create(input);
      } else {
        await repository.update(transactionId: id, input: input);
      }
    });
  }

  Future<bool> delete() async {
    final id = transactionId;
    if (id == null || state.isBusy || !state.canWrite) {
      return false;
    }
    return _pendingWrite = _write(TransactionEditorAction.deleting, () async {
      await ref.read(transactionRepositoryProvider).delete(id);
    });
  }

  Future<bool> _write(
    TransactionEditorAction action,
    Future<void> Function() write,
  ) async {
    // Navigation can dispose the screen while a write is in flight. Keep the
    // controller alive until the write and its change notification both finish.
    final link = ref.keepAlive();
    state = TransactionEditorState(action: action);
    try {
      await write();
      if (ref.mounted) {
        ref.read(transactionChangesProvider.notifier).changed();
        state = const TransactionEditorState();
      }
      return true;
    } catch (_) {
      if (ref.mounted) {
        state = TransactionEditorState(
          errorMessage: action == TransactionEditorAction.deleting
              ? '기록을 삭제하지 못했습니다.'
              : '기록을 저장하지 못했습니다.',
        );
      }
      return false;
    } finally {
      _pendingWrite = null;
      link.close();
    }
  }
}
