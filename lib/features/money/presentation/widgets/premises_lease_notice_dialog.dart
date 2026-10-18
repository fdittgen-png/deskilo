// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/ids/request_id.dart';
import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/time/clock.dart';
import '../../../../core/trace/guarded.dart';
import '../../../../core/ui/form_kit.dart';
import '../../domain/premises_lease.dart';
import '../../providers/premises_lease_providers.dart';
import 'premises_lease_dialogs.dart';

/// Records notice on [lease]: who gave it, when, why, and the day it ends.
Future<bool?> showLeaseNoticeDialog(
  BuildContext context,
  String workspaceId,
  PremisesLease lease,
) => showDialog<bool>(
  context: context,
  builder: (_) => _NoticeDialog(workspaceId: workspaceId, lease: lease),
);

class _NoticeDialog extends ConsumerStatefulWidget {
  const _NoticeDialog({required this.workspaceId, required this.lease});

  final String workspaceId;
  final PremisesLease lease;

  @override
  ConsumerState<_NoticeDialog> createState() => _NoticeDialogState();
}

class _NoticeDialogState extends ConsumerState<_NoticeDialog> {
  final _reason = TextEditingController();
  DateTime? _given;
  DateTime? _end;
  var _invalid = false;
  var _requestId = newRequestId();
  String? _attempted;

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final given = _given ?? ref.read(clockProvider).now();
    final end = _end;
    if (end == null || end.isBefore(given) || _reason.text.trim().isEmpty) {
      setState(() => _invalid = true);
      return;
    }
    final entries = '$given|$end|${_reason.text.trim()}';
    if (_attempted != null && _attempted != entries) {
      _requestId = newRequestId();
    }
    _attempted = entries;
    final sent = LeaseNoticeCommand(
      leaseId: widget.lease.id,
      revision: widget.lease.revision,
      givenOn: given,
      effectiveEnd: end,
      reason: _reason.text.trim(),
      requestId: _requestId,
    );
    final navigator = Navigator.of(context);
    final ok = await runGuarded(
      context,
      domain: 'money',
      message: 'lease notice failed',
      errorText: context.l10n.leaseNoticeRefused,
      action: () async {
        await ref
            .read(leaseCommandProvider)
            .giveNotice(widget.workspaceId, widget.lease, sent);
      },
    );
    if (ok && mounted) navigator.pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final material = MaterialLocalizations.of(context);
    final now = ref.read(clockProvider).now();
    return AlertDialog(
      title: Text(l10n.leaseNoticeTitle),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.leaseNoticeHint,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: AppSpacing.sm),
            LeaseDateButton(
              fieldKey: 'notice-given',
              label: l10n.leaseNoticeGivenOn,
              value: _given ?? now,
              first: widget.lease.startsOn,
              last: DateTime(now.year + 5),
              onPicked: (d) => setState(() => _given = d),
            ),
            LeaseDateButton(
              fieldKey: 'notice-end',
              label: l10n.leaseNoticeEnd,
              value: _end,
              first: widget.lease.startsOn,
              last: DateTime(now.year + 30),
              onPicked: (d) => setState(() => _end = d),
            ),
            AppTextField(
              key: const ValueKey('notice-reason'),
              controller: _reason,
              label: l10n.leaseNoticeReason,
              maxLength: 500,
            ),
            if (_invalid)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.sm),
                child: Text(
                  l10n.leaseNoticeInvalid,
                  key: const ValueKey('notice-invalid'),
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          key: const ValueKey('notice-cancel'),
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(material.cancelButtonLabel),
        ),
        FilledButton(
          key: const ValueKey('notice-save'),
          onPressed: _save,
          child: Text(l10n.leaseNoticeSave),
        ),
      ],
    );
  }
}
