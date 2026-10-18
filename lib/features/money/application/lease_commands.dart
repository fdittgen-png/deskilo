// SPDX-License-Identifier: AGPL-3.0-or-later
import '../domain/premises_lease.dart';

/// #2569 — what is sent for the lease. A command sends nothing when the entry
/// cannot be right (the server decides again on every write); returning null
/// tells the caller nothing was sent.
class LeaseCommands {
  const LeaseCommands(this._repository);

  final PremisesLeaseRepository _repository;

  Future<PremisesLease?> save(String workspaceId, LeaseDraft draft) async {
    if (draft.premises.trim().isEmpty ||
        draft.supplierId.isEmpty ||
        draft.noticeMonths < 0 ||
        draft.depositCents < 0 ||
        (draft.fixedUntil != null &&
            draft.fixedUntil!.isBefore(draft.startsOn))) {
      return null;
    }
    return _repository.saveLease(workspaceId, draft);
  }

  /// A term is an amount from a date; another charge is named.
  Future<PremisesLease?> addTerm(
    String workspaceId,
    PremisesLease lease,
    LeaseTermCommand command,
  ) async {
    if (lease.terminated ||
        command.amountCents <= 0 ||
        command.effectiveFrom.isBefore(lease.startsOn) ||
        (command.kind == LeaseTermKind.other && command.label.trim().isEmpty)) {
      return null;
    }
    return _repository.addTerm(workspaceId, command);
  }

  /// Notice needs its reason and an end that is not before it was given.
  Future<PremisesLease?> giveNotice(
    String workspaceId,
    PremisesLease lease,
    LeaseNoticeCommand command,
  ) async {
    if (lease.status != LeaseStatus.active ||
        command.reason.trim().isEmpty ||
        command.effectiveEnd.isBefore(command.givenOn)) {
      return null;
    }
    return _repository.giveNotice(workspaceId, command);
  }

  /// A settlement closes a period that is over, bills a non-negative amount
  /// and falls due on or after the period's end.
  Future<PremisesLease?> settle(
    String workspaceId,
    PremisesLease lease,
    LeaseSettlementCommand command,
    DateTime today,
  ) async {
    if (lease.status == LeaseStatus.draft ||
        command.periodEnd.isBefore(command.periodStart) ||
        command.periodEnd.isAfter(today) ||
        command.periodEnd.difference(command.periodStart).inDays > 400 ||
        command.actualCents < 0 ||
        command.dueOn.isBefore(command.periodEnd)) {
      return null;
    }
    return _repository.settleCharges(workspaceId, command);
  }
}
