import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/naroo_spacing.dart';
import '../../app/theme/naroo_text.dart';
import '../../app/theme/naroo_widgets.dart';
import '../../data/models/household_member.dart';
import 'settings_controller.dart';

class MemberNameSheet extends ConsumerStatefulWidget {
  const MemberNameSheet({super.key, this.member});
  final HouseholdMember? member;

  @override
  ConsumerState<MemberNameSheet> createState() => _MemberNameSheetState();
}

class _MemberNameSheetState extends ConsumerState<MemberNameSheet> {
  late final _name = TextEditingController(
    text: widget.member?.displayName ?? '',
  );
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final route = ModalRoute.of(context);
    if (_name.text.trim().isEmpty) {
      setState(() => _error = '이름을 입력해 주세요.');
      return;
    }
    setState(() => _error = null);
    final saved = await ref
        .read(memberEditorProvider.notifier)
        .saveName(member: widget.member, name: _name.text);
    if (!mounted || route?.isCurrent != true) return;
    if (saved) {
      Navigator.of(context).pop();
    } else {
      setState(() => _error = '구성원을 저장하지 못했습니다. 다시 시도해 주세요.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final busy = ref.watch(memberEditorProvider);
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          20,
          24,
          20,
          24 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.member == null ? '구성원 추가' : '구성원 이름 변경',
              style: NarooText.section,
            ),
            const SizedBox(height: NarooSpacing.space16),
            TextField(
              controller: _name,
              autofocus: true,
              enabled: !busy,
              textInputAction: TextInputAction.done,
              onSubmitted: busy ? null : (_) => _save(),
              decoration: InputDecoration(labelText: '이름', errorText: _error),
            ),
            const SizedBox(height: NarooSpacing.space16),
            FilledButton(
              onPressed: busy ? null : _save,
              child: busy ? const NarooButtonProgress() : const Text('저장'),
            ),
          ],
        ),
      ),
    );
  }
}
