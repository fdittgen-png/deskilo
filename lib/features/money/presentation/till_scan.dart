// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4366 -- the till's scan: a hardware scanner types the code and presses Enter into this field, which stays ready for
// the next one (a repeat scan adds one more). What a code names is the stock's to resolve; the till only rings up the
// item it names, or says in words why it cannot.
import 'package:flutter/material.dart';

import '../../../core/l10n/context_l10n.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/ui/form_kit.dart';

class TillScanField extends StatefulWidget {
  const TillScanField({super.key, required this.onScan});

  /// Handles a scanned code; the field is emptied and kept focused afterwards.
  final Future<void> Function(String code) onScan;

  @override
  State<TillScanField> createState() => _TillScanFieldState();
}

class _TillScanFieldState extends State<TillScanField> {
  final _text = TextEditingController();
  /// Counts the scans: a new field is built after each one, so it takes the focus again for the next code.
  int _scans = 0;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _submit(String value) async {
    final code = value.trim();
    _text.clear();
    if (code.isEmpty) return;
    await widget.onScan(code);
    if (mounted) setState(() => _scans++);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.md, 0),
      child: KeyedSubtree(
        key: ValueKey('till-scan-$_scans'),
        child: AppTextField(
          key: const ValueKey('till-scan'),
          controller: _text,
          label: l10n.tillScanLabel,
          autofocus: true,
          textInputAction: TextInputAction.done,
          onSubmitted: _submit,
        ),
      ),
    );
  }
}
