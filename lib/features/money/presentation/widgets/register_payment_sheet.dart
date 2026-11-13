// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/i18n/format_controller.dart';
import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/time/clock.dart';
import '../../../../core/trace/guarded.dart';
import '../../../../core/ui/adaptive/task_surface.dart';
import '../../../../core/ui/app_snack.dart';
import '../../../../core/ui/async_read_body.dart';
import '../../../../core/ui/form_kit.dart';
import '../../../../core/ui/form_sheet.dart';
import '../../../events/providers/event_providers.dart';
import '../../../workspace/domain/member.dart';
import '../../../workspace/providers/workspace_providers.dart';
import '../../domain/payment_method.dart';
import '../../providers/money_providers.dart';

/// #827 — an admin registers a payment that came in FOR a member (a
/// bank line, cash at the desk): the same `record_payment` RPC members
/// use for themselves, which files a pending payment event for the
/// member to confirm. Until now the server allowed it and no screen
/// offered it. Pops with true when a payment was registered.
Future<bool> showRegisterPaymentSheet(
  BuildContext context,
  WidgetRef ref, {
  String? memberId,
}) async {
  // #3614 — a standard task: a sheet on a phone, a side panel at the desk.
  final done = await showTask<bool>(
    context,
    size: TaskSize.standard,
    builder: (_) => _RegisterPaymentSheet(initialMemberId: memberId),
  );
  return done ?? false;
}

class _RegisterPaymentSheet extends ConsumerStatefulWidget {
  const _RegisterPaymentSheet({this.initialMemberId});

  final String? initialMemberId;

  @override
  ConsumerState<_RegisterPaymentSheet> createState() =>
      _RegisterPaymentSheetState();
}

class _RegisterPaymentSheetState extends ConsumerState<_RegisterPaymentSheet> {
  late String? _memberId = widget.initialMemberId;
  final _amount = TextEditingController();
  final _note = TextEditingController();
  PaymentMethod _method = PaymentMethod.bankTransfer;
  late final DateTime _today = _dayOf(ref.read(clockProvider).now());
  late DateRead _paidOn = (date: _today, problem: null);
  bool _busy = false;

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  static DateTime _dayOf(DateTime t) => DateTime(t.year, t.month, t.day);

  String get _currency =>
      ref.read(currentWorkspaceProvider).value?.currencyCode ?? '';

  int? get _cents {
    // The currency's own minor digits, never a literal 100.
    final c = appFormatOf(context)
        .readAmount(_amount.text, currency: _currency, allowNegative: false)
        .minor;
    return (c == null || c <= 0) ? null : c;
  }

  Future<void> _submit() async {
    final l10n = context.l10n;
    final workspace = ref.read(currentWorkspaceProvider).value;
    final memberId = _memberId;
    final cents = _cents;
    final paidOn = _paidOn.date;
    if (workspace == null ||
        memberId == null ||
        cents == null ||
        paidOn == null) {
      return;
    }
    setState(() => _busy = true);
    // The month a payment belongs to is the decision, and it lives in
    // application/record_payment.dart — not in this widget (#1449).
    final payments = ref.read(paymentsProvider);
    final ok = await runGuarded(
      context,
      domain: 'money',
      message: 'register payment failed',
      errorText: l10n.workspaceGenericError,
      action: () => payments.record(
        workspaceId: workspace.id,
        memberId: memberId,
        amountCents: cents,
        note: _note.text,
        method: _method,
        paidOn: paidOn,
      ),
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (!ok) return;
    ref.invalidate(eventsProvider);
    Navigator.of(context).pop(true);
    AppSnack.success(
      context,
      l10n.registerPaymentDone,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final membersRead = ref.watch(workspaceMembersProvider);
    // #3680 — the choices are offered only from a list that was read.
    final standIn = ReadsAnswer.of([membersRead]).standIn(
      onRetry: () => ref.invalidate(workspaceMembersProvider),
    );
    if (standIn != null) return SafeArea(child: standIn);
    final members = membersRead.requireValue
        .where((m) => m.status == MemberStatus.active && !m.isKiosk)
        .toList();
    final names = ref.watch(memberNamesProvider).value ?? const {}; // empty-ok: names are labels; an unread one is left blank, never a figure
    final currency = ref.watch(currentWorkspaceProvider).value?.currencyCode ?? '';
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom),
        child: SheetShell(
          title: l10n.registerPaymentTitle,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    l10n.registerPaymentHint,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  DropdownButtonFormField<String>(
                    key: const ValueKey('register-payment-member'),
                    initialValue: _memberId,
                    decoration: InputDecoration(
                        labelText: l10n.registerPaymentMember),
                    items: [
                      for (final m in members)
                        DropdownMenuItem(
                          key: ValueKey('register-payment-member-${m.id}'),
                          value: m.id,
                          child: Text(names[m.id] ?? m.id),
                        ),
                    ],
                    onChanged: (v) => setState(() => _memberId = v),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  AppAmountField(
                    key: const ValueKey('register-payment-amount'),
                    controller: _amount,
                    label: l10n.registerPaymentAmount,
                    currency: currency,
                    allowNegative: false,
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  DropdownButtonFormField<PaymentMethod>(
                    key: const ValueKey('register-payment-method'),
                    initialValue: _method,
                    decoration: InputDecoration(
                        labelText: l10n.registerPaymentMethod),
                    items: [
                      for (final m in PaymentMethod.values)
                        DropdownMenuItem(value: m, child: Text(m.name)),
                    ],
                    onChanged: (v) =>
                        setState(() => _method = v ?? PaymentMethod.other),
                  ),
                  AppDateField(
                    key: const ValueKey('register-payment-date'),
                    label: l10n.registerPaymentDate,
                    value: _paidOn.date,
                    first: DateTime(_today.year - 1),
                    last: _today.add(const Duration(days: 1)),
                    isRequired: true,
                    onChanged: (read) => setState(() => _paidOn = read),
                  ),
                  TextField(
                    key: const ValueKey('register-payment-note'),
                    controller: _note,
                    decoration: InputDecoration(
                        labelText: l10n.invoiceMatchNoteLabel),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  FilledButton(
                    key: const ValueKey('register-payment-submit'),
                    onPressed:
                        _busy ||
                                _memberId == null ||
                                _cents == null ||
                                _paidOn.date == null
                            ? null
                            : _submit,
                    child: Text(l10n.registerPaymentSubmit),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
