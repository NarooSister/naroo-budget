import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/app_routes.dart';
import '../../app/theme/naroo_colors.dart';
import '../../app/theme/naroo_icons.dart';
import '../../app/theme/naroo_spacing.dart';
import '../../app/theme/naroo_text.dart';
import '../../app/theme/naroo_widgets.dart';
import '../../core/session/app_session.dart';
import '../../data/models/household_member.dart';
import 'member_name_sheet.dart';
import 'settings_controller.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _isSigningOut = false;

  Future<void> _editMember([HouseholdMember? member]) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => MemberNameSheet(member: member),
    );
  }

  Future<void> _setHidden(HouseholdMember member) async {
    final saved = await ref
        .read(memberEditorProvider.notifier)
        .setHidden(member, !member.isHidden);
    if (mounted && !saved) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('구성원을 변경하지 못했습니다. 다시 시도해 주세요.')),
      );
    }
  }

  Future<void> _signOut() async {
    setState(() {
      _isSigningOut = true;
    });

    try {
      await ref.read(appSessionProvider.notifier).signOut();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('로그아웃하지 못했습니다. 다시 시도해 주세요.')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSigningOut = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(appSessionProvider).value;
    final displayName = session?.profile?.displayName ?? '사용자';
    final email = session?.email;
    final memberBusy = ref.watch(memberEditorProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('설정')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            NarooSpacing.space20,
            NarooSpacing.space16,
            NarooSpacing.space20,
            NarooSpacing.space24,
          ),
          children: [
            Text(displayName, style: NarooText.section),
            if (email != null && email.isNotEmpty) ...[
              const SizedBox(height: NarooSpacing.space4),
              Text(email, style: NarooText.bodySecondary),
            ],
            const SizedBox(height: NarooSpacing.space32),
            Text('가계부 구성원', style: NarooText.section),
            ref
                .watch(settingsMembersProvider)
                .when(
                  data: (members) => Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: members.isEmpty
                        ? [const Text('연결된 구성원이 없어요.')]
                        : [
                            for (final member in members)
                              ListTile(
                                contentPadding: EdgeInsets.zero,
                                title: Text(member.displayName),
                                subtitle: member.isCustom
                                    ? Text(
                                        member.isHidden
                                            ? '숨김 · 기존 기록은 유지돼요'
                                            : '계정 없는 구성원',
                                      )
                                    : null,
                                trailing: member.userId == session?.userId
                                    ? const Text('나')
                                    : member.isCustom
                                    ? PopupMenuButton<String>(
                                        tooltip: '${member.displayName} 관리',
                                        enabled: !memberBusy,
                                        onSelected: (action) {
                                          if (action == 'rename') {
                                            _editMember(member);
                                          } else {
                                            _setHidden(member);
                                          }
                                        },
                                        itemBuilder: (_) => [
                                          const PopupMenuItem(
                                            value: 'rename',
                                            child: Text('이름 변경'),
                                          ),
                                          PopupMenuItem(
                                            value: 'hidden',
                                            child: Text(
                                              member.isHidden ? '복원' : '숨김',
                                            ),
                                          ),
                                        ],
                                      )
                                    : const Text('계정 연결'),
                              ),
                          ],
                  ),
                  loading: () => const LinearProgressIndicator(),
                  error: (_, _) => TextButton.icon(
                    onPressed: () => ref.invalidate(settingsMembersProvider),
                    icon: const Icon(
                      NarooIcons.refresh,
                      size: NarooIcons.inline,
                    ),
                    label: const Text('구성원을 불러오지 못했습니다. 다시 시도'),
                  ),
                ),
            TextButton(
              onPressed: memberBusy || session?.member == null
                  ? null
                  : () => _editMember(),
              child: const Text('구성원 추가'),
            ),
            const SizedBox(height: NarooSpacing.space24),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('카테고리 관리'),
              trailing: const Icon(NarooIcons.forward, size: NarooIcons.action),
              onTap: () => context.push(AppRoutes.categories),
            ),
            const SizedBox(height: NarooSpacing.space16),
            OutlinedButton(
              onPressed: _isSigningOut ? null : _signOut,
              child: _isSigningOut
                  ? const NarooButtonProgress(color: NarooColors.primary)
                  : const Text('로그아웃'),
            ),
          ],
        ),
      ),
    );
  }
}
