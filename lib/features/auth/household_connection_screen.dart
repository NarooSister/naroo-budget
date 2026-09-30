import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/naroo_colors.dart';
import '../../app/theme/naroo_spacing.dart';
import '../../app/theme/naroo_text.dart';
import '../../app/theme/naroo_widgets.dart';
import '../../core/session/app_session.dart';

class HouseholdConnectionScreen extends ConsumerStatefulWidget {
  const HouseholdConnectionScreen({super.key});

  @override
  ConsumerState<HouseholdConnectionScreen> createState() =>
      _HouseholdConnectionScreenState();
}

class _HouseholdConnectionScreenState
    extends ConsumerState<HouseholdConnectionScreen> {
  bool _isSigningOut = false;

  Future<void> _signOut() async {
    setState(() {
      _isSigningOut = true;
    });

    try {
      await ref.read(appSessionProvider.notifier).signOut();
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
    final displayName = session?.profile?.displayName ?? session?.email ?? '';

    return Scaffold(
      appBar: AppBar(title: const Text('연결 필요')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            NarooSpacing.space20,
            NarooSpacing.space16,
            NarooSpacing.space20,
            NarooSpacing.space16,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Household에 아직 연결되지 않았어요.', style: NarooText.section),
              const SizedBox(height: NarooSpacing.space12),
              Text(
                '가계부를 사용하려면 관리자가 Household에 연결해 주어야 합니다.',
                style: NarooText.bodySecondary,
              ),
              if (displayName.isNotEmpty) ...[
                const SizedBox(height: NarooSpacing.space24),
                Text('현재 계정: $displayName', style: NarooText.bodySecondary),
              ],
              const Spacer(),
              OutlinedButton(
                onPressed: _isSigningOut ? null : _signOut,
                child: _isSigningOut
                    ? const NarooButtonProgress(color: NarooColors.primary)
                    : const Text('로그아웃'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
