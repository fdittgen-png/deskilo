// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';

import '../../../../core/l10n/context_l10n.dart';

/// The reason and the length of an operator's approval; null on cancel.
class InstanceGrantDialog extends StatefulWidget {
  const InstanceGrantDialog({super.key, required this.name});

  final String name;

  @override
  State<InstanceGrantDialog> createState() => _InstanceGrantDialogState();
}

class _InstanceGrantDialogState extends State<InstanceGrantDialog> {
  final _reason = TextEditingController();
  double _days = 30;

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final days = _days.round();
    final reason = _reason.text.trim();
    return AlertDialog(
      title: Text(
        l10n.instanceGrantTitle(widget.name),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            key: const ValueKey('instance-grant-reason'),
            controller: _reason,
            maxLength: 500,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              labelText: l10n.instanceGrantReason,
            ),
          ),
          Text(
            l10n.instanceGrantDaysLabel(days),
            key: const ValueKey('instance-grant-days'),
          ),
          Slider(
            key: const ValueKey('instance-grant-days-slider'),
            value: _days,
            min: 1,
            max: 30,
            divisions: 29,
            label: '$days',
            onChanged: (v) => setState(() => _days = v),
          ),
        ],
      ),
      actions: [
        TextButton(
          key: const ValueKey('instance-grant-cancel'),
          onPressed: () => Navigator.pop(context),
          child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
        ),
        FilledButton(
          key: const ValueKey('instance-grant-confirm'),
          onPressed: reason.isEmpty
              ? null
              : () => Navigator.pop(context, (reason: reason, days: days)),
          child: Text(l10n.instanceGrant),
        ),
      ],
    );
  }
}
