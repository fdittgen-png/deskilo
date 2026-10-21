// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2504 — the requests an in-browser assistant may make only after the
// person confirms them in the page (`confirmation: native`): answering a
// validation, voiding or refunding an invoice, changing a member's status
// or share. Each runs the call the app's own screens make, after the
// screen's own right is checked; a request the workspace's validators
// hold answers its event, pending.
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/trace/trace_logger.dart';
import '../core/validation/pending_validation.dart';
import '../features/events/providers/event_providers.dart';
import '../features/money/domain/invoice.dart';
import '../features/money/domain/invoice_commands.dart';
import '../features/money/providers/money_providers.dart';
import '../features/workspace/application/set_member_subscription.dart';
import '../features/workspace/domain/member.dart';
import '../features/workspace/domain/workspace_permission.dart';
import '../features/workspace/providers/workspace_providers.dart';
import 'webmcp_writes.dart';

/// The writes that run only after the person confirms them in the page
/// (`confirmation: native`), each with the check that decides whether the
/// person is asked at all.
final Map<String, ({WebMcpWrite check, WebMcpWrite write})>
webMcpConfirmedWrites = {
  'respond_to_validation': (check: _canRespond, write: _respond),
  'request_invoice_void': (
    check: _invoiceCheck,
    write: (ref, input) =>
        _onInvoice(ref, input, (commands, id) => commands.voidInvoice(id)),
  ),
  'request_refund': (
    check: _invoiceCheck,
    write: (ref, input) => _onInvoice(
      ref,
      input,
      (commands, id) => commands.settleCreditInvoice(
        id,
        note: input['note'] is String ? input['note']! as String : '',
      ),
    ),
  ),
  'request_member_status_change': (check: _memberCheck, write: _memberStatus),
  'request_subscription_change': (check: _memberCheck, write: _memberShare),
};

Future<Map<String, Object?>> _canRespond(
  Ref ref,
  Map<String, Object?> input,
) async {
  final eventId = input['event_id'];
  final accept = input['accept'];
  if (eventId is! String || eventId.isEmpty || accept is! bool) {
    throw const WebMcpRefused(
      'validation_error',
      'event_id and accept (true or false) are required.',
    );
  }
  // The same rule as the person's pending list: only a request this person
  // decides, still pending, is offered for an answer.
  final pending = await ref.read(myPendingEventsProvider.future);
  if (!pending.any((e) => e.id == eventId)) {
    throw const WebMcpRefused(
      'not_found',
      'No pending request here that this person decides.',
    );
  }
  return const {};
}

Future<Map<String, Object?>> _respond(
  Ref ref,
  Map<String, Object?> input,
) async {
  await _canRespond(ref, input);
  final eventId = input['event_id']! as String;
  final events = ref.read(eventRepositoryProvider);
  await events.respond(eventId, accept: input['accept']! as bool);
  ref
    ..invalidate(myPendingEventsProvider)
    ..invalidate(eventsProvider);
  final after = await events.fetchEvent(eventId);
  final status = after?.status.name;
  return {
    'event_id': eventId,
    'decision_recorded': true,
    'event_status': status,
    'effect_applied': status == 'applied' || status == 'confirmed',
  };
}

void _need(Ref ref, WorkspacePermission permission) {
  if (!ref.read(myPermissionsProvider).contains(permission)) {
    throw const WebMcpRefused(
      'forbidden',
      "This person's role does not allow this request.",
    );
  }
}

Future<Invoice> _invoice(Ref ref, Map<String, Object?> input) async {
  final id = input['invoice_id'];
  if (id is! String || id.isEmpty) {
    throw const WebMcpRefused('validation_error', 'invoice_id is required.');
  }
  final invoices = await ref.read(invoicesProvider.future);
  return invoices.where((i) => i.id == id).firstOrNull ??
      (throw const WebMcpRefused('not_found', 'No such invoice here.'));
}

Future<Map<String, Object?>> _invoiceCheck(
  Ref ref,
  Map<String, Object?> input,
) async {
  _need(ref, WorkspacePermission.issueInvoices);
  await _invoice(ref, input);
  return const {};
}

Map<String, Object?> _invoiceView(Invoice i) => {
  'invoice_id': i.id,
  'invoice_number': i.number,
  'period': i.period,
  'total_cents': i.totalCents,
  'currency': i.currency,
  'voided': i.isVoided,
};

/// Runs an invoice request the way the invoice screens do; a request the
/// workspace's validators hold answers its event, pending.
Future<Map<String, Object?>> _onInvoice(
  Ref ref,
  Map<String, Object?> input,
  Future<void> Function(InvoiceCommands commands, String id) act,
) async {
  _need(ref, WorkspacePermission.issueInvoices);
  final before = await _invoice(ref, input);
  String? eventId;
  try {
    await act(ref.read(invoiceCommandsProvider), before.id);
  } on PendingValidationException catch (pending, st) {
    // Held by the workspace's validators: the answer is its event.
    TraceLogger.instance.warn(
      'webmcp',
      'request pending ${pending.eventId}',
      stackTrace: st,
    );
    eventId = pending.eventId;
  }
  ref.invalidate(invoicesProvider);
  final after = (await ref.read(invoicesProvider.future))
      .where((i) => i.id == before.id)
      .firstOrNull;
  return {'event_id': ?eventId, ..._invoiceView(after ?? before)};
}

Future<Member> _member(Ref ref, Map<String, Object?> input) async {
  final id = input['member_id'];
  if (id is! String || id.isEmpty) {
    throw const WebMcpRefused('validation_error', 'member_id is required.');
  }
  final members = await ref.read(workspaceMembersProvider.future);
  return members.where((m) => m.id == id).firstOrNull ??
      (throw const WebMcpRefused('not_found', 'No such member here.'));
}

Future<Map<String, Object?>> _memberCheck(
  Ref ref,
  Map<String, Object?> input,
) async {
  _need(ref, WorkspacePermission.manageMembers);
  await _member(ref, input);
  final status = input['status'];
  if (status != null &&
      !const {'active', 'paused', 'exited'}.contains(status)) {
    throw const WebMcpRefused(
      'validation_error',
      'status must be active, paused or exited.',
    );
  }
  final pct = input['pct'];
  if (input.containsKey('pct') && (pct is! int || pct < 1 || pct > 100)) {
    throw const WebMcpRefused('validation_error', 'pct must be 1 to 100.');
  }
  return const {};
}

Future<Map<String, Object?>> _memberAnswer(
  Ref ref,
  Member before,
  Future<void> Function() act,
) async {
  String? eventId;
  try {
    await act();
  } on PendingValidationException catch (pending, st) {
    // Held by the workspace's validators: the answer is its event.
    TraceLogger.instance.warn(
      'webmcp',
      'request pending ${pending.eventId}',
      stackTrace: st,
    );
    eventId = pending.eventId;
  }
  ref.invalidate(workspaceMembersProvider);
  final after =
      (await ref.read(workspaceMembersProvider.future))
          .where((m) => m.id == before.id)
          .firstOrNull ??
      before;
  return {
    'event_id': ?eventId,
    'member_id': after.id,
    'member_status': after.status.name,
    'subscription_pct': after.subscriptionPct,
    'unchanged':
        after.status == before.status &&
        after.subscriptionPct == before.subscriptionPct &&
        eventId == null,
  };
}

Future<Map<String, Object?>> _memberStatus(
  Ref ref,
  Map<String, Object?> input,
) async {
  await _memberCheck(ref, input);
  final before = await _member(ref, input);
  final status = MemberStatus.values.byName(input['status']! as String);
  return _memberAnswer(
    ref,
    before,
    () => ref
        .read(workspaceRepositoryProvider)
        .updateMemberStatus(before.id, status),
  );
}

Future<Map<String, Object?>> _memberShare(
  Ref ref,
  Map<String, Object?> input,
) async {
  await _memberCheck(ref, input);
  final before = await _member(ref, input);
  return _memberAnswer(ref, before, () async {
    // The members screen's own rule decides whether the share may be set.
    final change = await ref
        .read(memberSubscriptionsProvider)
        .set(before, input['pct']! as int);
    if (change != SubscriptionChange.saved) {
      throw WebMcpRefused(
        'validation_error',
        'The share cannot be set: ${change.name}.',
      );
    }
  });
}
