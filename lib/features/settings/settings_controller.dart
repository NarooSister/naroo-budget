import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/session/app_session.dart';
import '../../data/models/household_member.dart';
import '../../data/repository_providers.dart';

final settingsMembersProvider =
    FutureProvider.autoDispose<List<HouseholdMember>>((ref) async {
      final session = await ref.watch(appSessionProvider.future);
      final id = session.member?.householdId;
      if (id == null) return [];
      return ref.read(householdMemberRepositoryProvider).listByHousehold(id);
    });
