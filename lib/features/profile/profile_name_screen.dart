import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/naroo_colors.dart';
import '../../app/theme/naroo_spacing.dart';
import '../../app/theme/naroo_text.dart';
import '../../app/theme/naroo_widgets.dart';
import '../../core/session/app_session.dart';
import 'profile_name_form.dart';

/// First-login name check. The router leaves this screen once the name is saved.
class ProfileNameScreen extends ConsumerStatefulWidget {
  const ProfileNameScreen({super.key});

  @override
  ConsumerState<ProfileNameScreen> createState() => _ProfileNameScreenState();
}

class _ProfileNameScreenState extends ConsumerState<ProfileNameScreen> {
  bool _isSigningOut = false;

  Future<void> _signOut() async {
    setState(() => _isSigningOut = true);
    try {
      await ref.read(appSessionProvider.notifier).signOut();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('로그아웃하지 못했습니다. 다시 시도해 주세요.')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSigningOut = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(appSessionProvider).value;
    final current = session?.profile?.displayName ?? '';
    // The email fallback is not a name suggestion.
    final initialName = current == session?.email ? '' : current;

    return Scaffold(
      appBar: AppBar(title: const Text('이름 설정')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            NarooSpacing.space20,
            NarooSpacing.space16,
            NarooSpacing.space20,
            NarooSpacing.space16,
          ),
          children: [
            Text('가계부에 표시할 이름을 확인해 주세요.', style: NarooText.section),
            const SizedBox(height: NarooSpacing.space8),
            Text('나중에 설정에서 바꿀 수 있어요.', style: NarooText.bodySecondary),
            const SizedBox(height: NarooSpacing.space24),
            ProfileNameForm(initialName: initialName, submitLabel: '시작하기'),
            const SizedBox(height: NarooSpacing.space32),
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
