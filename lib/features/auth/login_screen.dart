import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/naroo_colors.dart';
import '../../app/theme/naroo_spacing.dart';
import '../../app/theme/naroo_text.dart';
import '../../app/theme/naroo_widgets.dart';
import '../../core/session/app_session.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  bool _isSubmitting = false;
  String? _errorMessage;

  Future<void> _signInWithGoogle() async {
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      await ref.read(appSessionProvider.notifier).signInWithGoogle();
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorMessage = '로그인을 시작하지 못했습니다. 잠시 후 다시 시도해 주세요.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            NarooSpacing.space20,
            NarooSpacing.space24,
            NarooSpacing.space20,
            NarooSpacing.space24,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              const NarooWordmark(),
              const SizedBox(height: NarooSpacing.space12),
              Text('부부가 함께 쓰는 심플한 가계부', style: NarooText.bodySecondary),
              const Spacer(),
              if (_errorMessage != null) ...[
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: NarooColors.errorSurface,
                    borderRadius: BorderRadius.circular(NarooRadius.input),
                    border: Border.all(color: NarooColors.error),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: NarooSpacing.space12,
                      vertical: NarooSpacing.space8,
                    ),
                    child: Text(
                      _errorMessage!,
                      style: NarooText.caption.copyWith(
                        color: NarooColors.error,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: NarooSpacing.space12),
              ],
              FilledButton(
                onPressed: _isSubmitting ? null : _signInWithGoogle,
                child: _isSubmitting
                    ? const NarooButtonProgress()
                    : const Text('Google로 계속하기'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
