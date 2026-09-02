// SPDX-License-Identifier: 0BSD
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/time/clock.dart';
import '../../../../core/trace/guarded.dart';
import '../../../../core/ui/app_snack.dart';
import '../../../../core/ui/form_sheet.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../events/providers/event_providers.dart';
import '../../../reservations/providers/reservation_providers.dart';
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
  final done = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
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
  late DateTime _paidOn = ref.read(clockProvider).now();
  bool _busy = false;

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  int? get _cents {
    final raw = _amount.text.trim().replaceAll(',', '.');
    final value = double.tryParse(raw);
    if (value == null || value <= 0) return null;
    return (value * 100).round();
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context);
    final workspace = ref.read(currentWorkspaceProvider).value;
    final memberId = _memberId;
    final cents = _cents;
    if (workspace == null || memberId == null || cents == null) return;
    setState(() => _busy = true);
    final period =
        '${_paidOn.year}-${_paidOn.month.toString().padLeft(2, '0')}';
    final ok = await runGuarded(
      context,
      domain: 'money',
      message: 'register payment failed',
      errorText: l10n?.workspaceGenericError ??
          'Something went wrong. Please try again.',
      action: () => ref.read(moneyRepositoryProvider).recordPayment(
            workspaceId: workspace.id,
            memberId: memberId,
            amountCents: cents,
            note: _note.text.trim(),
            method: _method,
            paidOn: _paidOn,
            period: period,
          ),
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (!ok) return;
    ref.invalidate(eventsProvider);
    Navigator.of(context).pop(true);
    AppSnack.success(
      context,
      l10n?.registerPaymentDone ??
          'Payment registered — the member confirms it from their side.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final members = (ref.watch(workspaceMembersProvider).value ?? const [])
        .where((m) => m.status == MemberStatus.active && !m.isKiosk)
        .toList();
    final names = ref.watch(memberNamesProvider).value ?? const {};
    final currency = ref.watch(currentWorkspaceProvider).value?.currencyCode ?? '';
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom),
        child: SheetShell(
          title: l10n?.registerPaymentTitle ?? 'Register a payment',
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    l10n?.registerPaymentHint ??
                        'A payment that reached the workspace — the member '
                            'confirms it, then it can be matched to an invoice.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  DropdownButtonFormField<String>(
                    key: const ValueKey('register-payment-member'),
                    initialValue: _memberId,
                    decoration: InputDecoration(
                        labelText: l10n?.registerPaymentMember ?? 'Member'),
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
                  TextField(
                    key: const ValueKey('register-payment-amount'),
                    controller: _amount,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      labelText: l10n?.registerPaymentAmount ?? 'Amount',
                      suffixText: currency,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  DropdownButtonFormField<PaymentMethod>(
                    key: const ValueKey('register-payment-method'),
                    initialValue: _method,
                    decoration: InputDecoration(
                        labelText: l10n?.registerPaymentMethod ?? 'Method'),
                    items: [
                      for (final m in PaymentMethod.values)
                        DropdownMenuItem(value: m, child: Text(m.name)),
                    ],
                    onChanged: (v) =>
                        setState(() => _method = v ?? PaymentMethod.other),
                  ),
                  ListTile(
                    key: const ValueKey('register-payment-date'),
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.event_outlined),
                    title: Text(l10n?.registerPaymentDate ?? 'Paid on'),
                    subtitle: Text(DateFormat.yMMMd().format(_paidOn)),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _paidOn,
                        firstDate: DateTime(_paidOn.year - 1),
                        lastDate: _paidOn.add(const Duration(days: 1)),
                      );
                      if (picked != null) setState(() => _paidOn = picked);
                    },
                  ),
                  TextField(
                    key: const ValueKey('register-payment-note'),
                    controller: _note,
                    decoration: InputDecoration(
                        labelText: l10n?.registerPaymentNote ?? 'Note'),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  FilledButton(
                    key: const ValueKey('register-payment-submit'),
                    onPressed:
                        _busy || _memberId == null || _cents == null
                            ? null
                            : _submit,
                    child: Text(l10n?.registerPaymentSubmit ?? 'Register'),
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
