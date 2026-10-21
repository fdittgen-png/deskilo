// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/format/cents.dart';
import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/time/clock.dart';
import '../../../../core/trace/guarded.dart';
import '../../../../core/ui/form_kit.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/room_rental.dart';
import '../../domain/supplier.dart';
import '../../providers/room_rental_providers.dart';
import '../../providers/supplier_providers.dart';
import 'premises_lease_dialogs.dart';
import 'room_audience_fees.dart';
import 'room_audience_pickers.dart';

/// The word for a rental's status.
String roomRentalStatusLabel(AppLocalizations l10n, RoomRentalStatus s) =>
    switch (s) {
      RoomRentalStatus.draft => l10n.roomRentStatusDraft,
      RoomRentalStatus.active => l10n.roomRentStatusActive,
      RoomRentalStatus.ended => l10n.roomRentStatusEnded,
    };

/// Rents a room from a lessor, or changes [rental]. True once the server has
/// it; a refusal keeps the dialog and every entry.
Future<bool?> showRentedRoomDialog(
  BuildContext context,
  String workspaceId, {
  required String officeId,
  required String roomName,
  RoomRental? rental,
}) => showDialog<bool>(
  context: context,
  builder: (_) => _RentedRoomDialog(
    workspaceId: workspaceId,
    officeId: officeId,
    roomName: roomName,
    rental: rental,
  ),
);

class _RentedRoomDialog extends ConsumerStatefulWidget {
  const _RentedRoomDialog({
    required this.workspaceId,
    required this.officeId,
    required this.roomName,
    this.rental,
  });

  final String workspaceId;
  final String officeId;
  final String roomName;
  final RoomRental? rental;

  @override
  ConsumerState<_RentedRoomDialog> createState() => _RentedRoomDialogState();
}

class _RentedRoomDialogState extends ConsumerState<_RentedRoomDialog> {
  late final _cost = TextEditingController(
    text: centsToMajor(widget.rental?.costCents ?? 0),
  );
  late final _fee = TextEditingController(
    text: _generalFee(widget.rental) == null
        ? ''
        : centsToMajor(_generalFee(widget.rental)!),
  );
  late String? _supplierId = widget.rental?.supplierId;
  late DateTime? _from = widget.rental?.availableFrom;
  late DateTime? _until = widget.rental?.availableUntil;
  late var _status = widget.rental?.status ?? RoomRentalStatus.draft;
  late var _all = widget.rental?.audienceAll ?? false;
  late final Set<String> _roleIds = {
    for (final e in widget.rental?.audience ?? const <RoomAudienceEntry>[])
      if (e.roleId != null) e.roleId!,
  };
  late final Set<String> _planIds = {
    for (final e in widget.rental?.audience ?? const <RoomAudienceEntry>[])
      if (e.planId != null) e.planId!,
  };
  late final Set<String> _memberIds = {
    for (final e in widget.rental?.audience ?? const <RoomAudienceEntry>[])
      if (e.memberId != null) e.memberId!,
  };
  var _invalid = false;

  /// A half-day fee for one audience entry, by [roomAudienceFeeKey].
  late final Map<String, TextEditingController> _entryFees = {
    for (final f in widget.rental?.fees ?? const <RoomFee>[])
      if (f.unit == RoomFeeUnit.halfDay && f.audience.toJson().isNotEmpty)
        roomAudienceFeeKey(f.audience): TextEditingController(
          text: centsToMajor(f.feeCents),
        ),
  };

  TextEditingController _entryFee(String key) =>
      _entryFees.putIfAbsent(key, TextEditingController.new);

  List<RoomAudienceEntry> get _entries => [
    for (final id in _roleIds) RoomAudienceEntry(roleId: id),
    for (final id in _planIds) RoomAudienceEntry(planId: id),
    for (final id in _memberIds) RoomAudienceEntry(memberId: id),
  ];

  static int? _generalFee(RoomRental? r) {
    for (final f in r?.fees ?? const <RoomFee>[]) {
      if (f.unit == RoomFeeUnit.halfDay &&
          f.audience.roleId == null &&
          f.audience.planId == null &&
          f.audience.memberId == null) {
        return f.feeCents;
      }
    }
    return null;
  }

  void _edit(VoidCallback change) => setState(change);

  @override
  void dispose() {
    _cost.dispose();
    _fee.dispose();
    for (final c in _entryFees.values) {
      c.dispose();
    }
    super.dispose();
  }

  RoomRentalCommand? _command() {
    final cost = parseCentsInput(_cost.text.isEmpty ? '0' : _cost.text);
    final fee = _fee.text.trim().isEmpty ? null : parseCentsInput(_fee.text);
    final supplier = _supplierId;
    final from = _from;
    final entryFees = <RoomFee>[];
    for (final e in _all ? const <RoomAudienceEntry>[] : _entries) {
      final text = _entryFees[roomAudienceFeeKey(e)]?.text.trim() ?? '';
      if (text.isEmpty) continue;
      final cents = parseCentsInput(text);
      if (cents == null) return null;
      entryFees.add(
        RoomFee(unit: RoomFeeUnit.halfDay, feeCents: cents, audience: e),
      );
    }
    if (cost == null ||
        (_fee.text.trim().isNotEmpty && fee == null) ||
        supplier == null ||
        from == null) {
      return null;
    }
    final r = widget.rental;
    return RoomRentalCommand(
      officeId: widget.officeId,
      supplierId: supplier,
      availableFrom: from,
      availableUntil: _until,
      status: _status,
      costCents: cost,
      revision: r?.revision ?? 0,
      audienceAll: _all,
      // The roles, plans and members are the pickers'; a half-day fee for
      // one of them is its field's; other units are kept as they are.
      audience: _entries,
      fees: [
        ...?r?.fees.where((f) => f.unit != RoomFeeUnit.halfDay),
        if (fee != null) RoomFee(unit: RoomFeeUnit.halfDay, feeCents: fee),
        ...entryFees,
      ],
    );
  }

  Future<void> _save() async {
    final command = _command();
    if (command == null) {
      _edit(() => _invalid = true);
      return;
    }
    final navigator = Navigator.of(context);
    var accepted = false;
    final ok = await runGuarded(
      context,
      domain: 'reservations',
      message: 'room rental save failed',
      errorText: context.l10n.roomRentRefused,
      action: () async {
        accepted =
            await ref
                .read(roomRentalCommandProvider)
                .save(widget.workspaceId, command) !=
            null;
      },
    );
    if (ok && accepted && mounted) {
      navigator.pop(true);
    } else if (ok && mounted) {
      _edit(() => _invalid = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final material = MaterialLocalizations.of(context);
    final suppliers = ref.watch(suppliersProvider(widget.workspaceId));
    final now = ref.read(clockProvider).now();
    return AlertDialog(
      title: Text(l10n.roomRentFormTitle(widget.roomName)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DropdownButtonFormField<String>(
              key: const ValueKey('room-rent-lessor'),
              initialValue: _supplierId,
              decoration: InputDecoration(labelText: l10n.roomRentFieldLessor),
              items: [
                for (final s in suppliers.value ?? const <Supplier>[])
                  if (s.isActive || s.id == _supplierId)
                    DropdownMenuItem(value: s.id, child: Text(s.name)),
              ],
              onChanged: (v) => _edit(() => _supplierId = v),
            ),
            if ((suppliers.value ?? const <Supplier>[]).isEmpty)
              Text(
                l10n.roomRentNeedSupplier,
                key: const ValueKey('room-rent-need-supplier'),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            LeaseDateButton(
              fieldKey: 'room-rent-from',
              label: l10n.roomRentFieldFrom,
              value: _from,
              first: DateTime(now.year - 5),
              last: DateTime(now.year + 30),
              onPicked: (d) => _edit(() => _from = d),
            ),
            LeaseDateButton(
              fieldKey: 'room-rent-until',
              label: l10n.roomRentFieldUntil,
              value: _until,
              first: _from ?? DateTime(now.year - 5),
              last: DateTime(now.year + 40),
              onPicked: (d) => _edit(() => _until = d),
            ),
            DropdownButtonFormField<RoomRentalStatus>(
              key: const ValueKey('room-rent-status'),
              initialValue: _status,
              decoration: InputDecoration(labelText: l10n.roomRentFieldStatus),
              items: [
                for (final s in RoomRentalStatus.values)
                  DropdownMenuItem(
                    value: s,
                    child: Text(roomRentalStatusLabel(l10n, s)),
                  ),
              ],
              onChanged: (v) => _edit(() => _status = v ?? _status),
            ),
            AppTextField(
              key: const ValueKey('room-rent-cost'),
              controller: _cost,
              label: l10n.roomRentFieldCost,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
            ),
            AppTextField(
              key: const ValueKey('room-rent-fee'),
              controller: _fee,
              label: l10n.roomRentFieldFee,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
            ),
            SwitchListTile(
              key: const ValueKey('room-rent-all'),
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.roomRentFieldAll),
              value: _all,
              onChanged: (v) => _edit(() => _all = v),
            ),
            if (!_all)
              RoomAudiencePickers(
                workspaceId: widget.workspaceId,
                roleIds: _roleIds,
                planIds: _planIds,
                memberIds: _memberIds,
                onEdited: () => _edit(() {}),
              ),
            if (!_all)
              RoomAudienceFees(
                workspaceId: widget.workspaceId,
                entries: _entries,
                controllerFor: _entryFee,
              ),
            if (_invalid)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.sm),
                child: Text(
                  l10n.roomRentInvalid,
                  key: const ValueKey('room-rent-invalid'),
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          key: const ValueKey('room-rent-cancel'),
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(material.cancelButtonLabel),
        ),
        FilledButton(
          key: const ValueKey('room-rent-save'),
          onPressed: _save,
          child: Text(l10n.roomRentSave),
        ),
      ],
    );
  }
}
