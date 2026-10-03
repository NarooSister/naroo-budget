import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/naroo_spacing.dart';
import '../../app/theme/naroo_widgets.dart';
import '../../core/profile_name_rules.dart';
import 'profile_name_controller.dart';

class ProfileNameForm extends ConsumerStatefulWidget {
  const ProfileNameForm({
    super.key,
    required this.initialName,
    required this.submitLabel,
    this.onSaved,
  });

  final String initialName;
  final String submitLabel;
  final VoidCallback? onSaved;

  @override
  ConsumerState<ProfileNameForm> createState() => _ProfileNameFormState();
}

class _ProfileNameFormState extends ConsumerState<ProfileNameForm> {
  late final _name = TextEditingController(text: widget.initialName);
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final error = ProfileNameRules.validate(_name.text);
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    setState(() => _error = null);
    final saved = await ref
        .read(profileNameEditorProvider.notifier)
        .save(_name.text);
    if (!mounted) return;
    if (saved) {
      widget.onSaved?.call();
    } else {
      setState(() => _error = '이름을 저장하지 못했습니다. 다시 시도해 주세요.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final busy = ref.watch(profileNameEditorProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(
          controller: _name,
          autofocus: true,
          enabled: !busy,
          maxLength: ProfileNameRules.maxLength,
          textInputAction: TextInputAction.done,
          onSubmitted: busy ? null : (_) => _save(),
          decoration: InputDecoration(labelText: '이름', errorText: _error),
        ),
        const SizedBox(height: NarooSpacing.space16),
        FilledButton(
          onPressed: busy ? null : _save,
          child: busy ? const NarooButtonProgress() : Text(widget.submitLabel),
        ),
      ],
    );
  }
}
