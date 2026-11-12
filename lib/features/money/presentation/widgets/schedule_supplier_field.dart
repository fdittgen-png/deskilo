// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:deskilo_accounting_interchange/deskilo_accounting_interchange.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/i18n/format_controller.dart';
import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/ui/form_kit.dart';
import '../../providers/expense_schedule_providers.dart';
import '../../providers/supplier_providers.dart';

/// The supplier a new schedule pays: the workspace's ACTIVE suppliers, or
/// none. Nothing is shown while the suppliers are switched off or when no
/// active supplier can be offered (a member who may not read the
/// suppliers reads none).
class ScheduleSupplierField extends ConsumerWidget {
  const ScheduleSupplierField({
    required this.workspaceId,
    required this.value,
    required this.onChanged,
    super.key,
  });

  final String workspaceId;
  final String? value;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final active =
        ref.watch(scheduleSuppliersProvider(workspaceId)).value ??
        const <Supplier>[];
    if (active.isEmpty) return const SizedBox.shrink();
    final l10n = context.l10n;
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: DropdownButtonFormField<String?>(
        key: const ValueKey('schedule-supplier'),
        initialValue: active.any((s) => s.id == value) ? value : null,
        isExpanded: true,
        decoration: InputDecoration(labelText: l10n.scheduleSupplierLabel),
        items: [
          DropdownMenuItem<String?>(child: Text(l10n.scheduleNoSupplier)),
          for (final s in active)
            DropdownMenuItem<String?>(
              value: s.id,
              child: Text('${s.number} · ${s.name}'),
            ),
        ],
        onChanged: onChanged,
      ),
    );
  }
}

/// The name of the supplier [supplierId] among [workspaceId]'s suppliers,
/// archived ones included: a schedule keeps reading who it pays.
String? scheduleSupplierName(
  WidgetRef ref,
  String workspaceId,
  String? supplierId,
) {
  if (supplierId == null) return null;
  for (final s
      in ref.watch(suppliersProvider(workspaceId)).value ??
          const <Supplier>[]) {
    if (s.id == supplierId) return s.name;
  }
  return null;
}

/// The optional last date of a schedule; left empty, it runs until
/// stopped. [onChanged] receives what the typed or picked text reads as.
class ScheduleEndsTile extends StatelessWidget {
  const ScheduleEndsTile({
    required this.startsOn,
    required this.endsOn,
    required this.onChanged,
    this.showProblem = false,
    super.key,
  });

  final DateTime startsOn;
  final DateTime? endsOn;
  final ValueChanged<DateRead> onChanged;
  final bool showProblem;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AppDateField(
      key: const ValueKey('schedule-ends'),
      label: l10n.scheduleEndsOn,
      helper: l10n.scheduleNoEnd,
      value: endsOn,
      first: startsOn,
      last: startsOn.add(const Duration(days: 3650)),
      showProblem: showProblem,
      onChanged: onChanged,
    );
  }
}

/// The first date of a new schedule: from a year back to two years ahead.
class ScheduleStartsField extends StatelessWidget {
  const ScheduleStartsField({
    required this.now,
    required this.value,
    required this.showProblem,
    required this.onChanged,
    super.key,
  });

  final DateTime now;
  final DateTime? value;
  final bool showProblem;
  final ValueChanged<DateRead> onChanged;

  @override
  Widget build(BuildContext context) => AppDateField(
    label: context.l10n.scheduleStartsOn,
    value: value,
    first: now.subtract(const Duration(days: 366)),
    last: now.add(const Duration(days: 730)),
    isRequired: true,
    showProblem: showProblem,
    // recorder-key-exempt: the sheet keys this field (`schedule-starts`).
    onChanged: onChanged,
  );
}

/// Closes the new-schedule sheet with its entries, unless a date or the
/// amount could not be read: then [onUnread], and the sheet stays open with
/// each field saying why under itself.
void submitScheduleEntries(
  BuildContext context, {
  required DateRead starts,
  required DateRead ends,
  required String amount,
  required String currency,
  required VoidCallback onUnread,
}) {
  final unread =
      starts.date == null ||
      ends.problem != null ||
      appFormatOf(context)
              .readAmount(amount, currency: currency, allowNegative: false)
              .problem !=
          null;
  unread ? onUnread() : Navigator.of(context).pop(true);
}
