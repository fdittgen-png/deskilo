// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/l10n/context_l10n.dart';
import '../../domain/supplier.dart';
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

/// The optional last date of a schedule; cleared, it runs until stopped.
class ScheduleEndsTile extends StatelessWidget {
  const ScheduleEndsTile({
    required this.startsOn,
    required this.endsOn,
    required this.dates,
    required this.onChanged,
    super.key,
  });

  final DateTime startsOn;
  final DateTime? endsOn;
  final DateFormat dates;
  final ValueChanged<DateTime?> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final ends = endsOn;
    return ListTile(
      key: const ValueKey('schedule-ends'),
      contentPadding: EdgeInsets.zero,
      title: Text(l10n.scheduleEndsOn),
      subtitle: Text(ends == null ? l10n.scheduleNoEnd : dates.format(ends)),
      trailing: ends == null
          ? const Icon(Icons.edit_calendar_outlined)
          : IconButton(
              key: const ValueKey('expense-schedule-sheet-a11y-clear-date'),
              tooltip: l10n.a11yClearDate,
              icon: const Icon(Icons.clear),
              onPressed: () => onChanged(null),
            ),
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: ends ?? startsOn.add(const Duration(days: 365)),
          firstDate: startsOn,
          lastDate: startsOn.add(const Duration(days: 3650)),
        );
        if (picked != null) onChanged(picked);
      },
    );
  }
}
