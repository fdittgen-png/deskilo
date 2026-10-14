// SPDX-License-Identifier: AGPL-3.0-or-later




import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/format/cents.dart';
import '../../../../core/i18n/money_format.dart';
import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/time/clock.dart';
import '../../../../core/trace/guarded.dart';
import '../../../../core/ui/app_sheet.dart';
import '../../../../core/ui/app_snack.dart';
import '../../../events/providers/event_providers.dart';
import '../../../workspace/domain/workspace_feature.dart';
import '../../../workspace/providers/workspace_providers.dart';
import '../../domain/package.dart';
import '../../providers/money_providers.dart';
import 'money_payment_forms.dart';

/// The money sheets of the Money tab that book something: a recorded
/// payment (#154), an extra-quota request (0031) and a package purchase
/// (0042). Each one opens a sheet, asks, then runs one guarded repository
/// call. Split out of `_MoneyScreenState` (#2494): it holds no screen state,
/// only the [State] it opens sheets for.
class MoneySheets {
  MoneySheets(this._state, this._ref);

  final State _state;
  final WidgetRef _ref;

  BuildContext get _context => _state.context;

  Future<void> recordPayment(MoneyFormat currency) async {
    final l10n = _context.l10n;
    final workspace = _ref.read(currentWorkspaceProvider).value;
    final member = _ref.read(myMemberProvider).value;
    if (workspace == null || member == null) return;

    final draft = MoneyPaymentDraft(_ref.read(clockProvider).now());
    final submitted = await showAppSheet<bool>(
      context: _context,
      isScrollControlled: true,
      builder: (_) => RecordPaymentSheet(draft: draft, currency: currency),
    );
    if (submitted != true || !_context.mounted) return;

    final cents = parseCentsInput(draft.amount.text);
    if (cents == null || cents <= 0) return;
    if (!await runGuarded(
      _context,
      domain: 'money',
      message: 'record payment failed',
      errorText: l10n.workspaceGenericError,
      action: () => _ref.read(moneyRepositoryProvider).recordPayment(
            workspaceId: workspace.id,
            memberId: member.id,
            amountCents: cents,
            note: draft.note.text.trim(),
            method: draft.method,
            paidOn: draft.paidOn,
            period: draft.period,
          ),
    )) {
      return;
    }
    if (!_context.mounted) return;
    AppSnack.success(
      _context,
      l10n.moneyPaymentPending,
    );
    _ref.invalidate(eventsProvider);
  }

  /// Request extra half-days beyond the subscription entitlement (0031):
  /// lands as a pending 'quota' event that owners/admins validate per the
  /// owner's policy; once confirmed the booking cap rises for [period].
  Future<void> requestQuota(String period) async {
    final l10n = _context.l10n;
    final workspace = _ref.read(currentWorkspaceProvider).value;
    if (workspace == null) return;
    final count = TextEditingController();
    final submitted = await showAppSheet<bool>(
      context: _context,
      isScrollControlled: true,
      builder: (context) => QuotaRequestSheet(count: count, period: period),
    );
    if (submitted != true || !_context.mounted) return;

    final halfDays = int.tryParse(count.text.trim());
    if (halfDays == null || halfDays < 1) return;
    if (!await runGuarded(
      _context,
      domain: 'money',
      message: 'quota request failed',
      errorText: l10n.workspaceGenericError,
      action: () => _ref.read(eventRepositoryProvider).requestQuotaExtension(
            workspace.id,
            period: period,
            halfDays: halfDays,
          ),
    )) {
      return;
    }
    if (!_context.mounted) return;
    AppSnack.success(
      _context,
      l10n.quotaRequestPending,
    );
    _ref.invalidate(eventsProvider);
  }

  /// Self-serve package purchase (0042): pick an owner-defined package; the
  /// cap rises immediately and the price posts to this month's bill.
  Future<void> buyPackage(MoneyFormat currency) async {
    final l10n = _context.l10n;
    final workspace = _ref.read(currentWorkspaceProvider).value;
    if (workspace == null) return;
    final packages = await _ref.read(packagesProvider.future);
    // #744 — my negotiated package prices, when I have a deal.
    final myId = _ref.read(myMemberProvider).value?.id;
    final myDeal = myId != null &&
            _ref
                .read(enabledFeaturesSyncProvider)
                .contains(WorkspaceFeature.priceNegotiations)
        ? _ref.read(priceNegotiationProvider(myId)).value?.active
        : null;
    if (!_context.mounted) return;
    if (packages.isEmpty) {
      AppSnack.info(
        _context,
        l10n.buyPackageNone,
      );
      return;
    }
    final chosen = await showAppSheet<Package>(
      context: _context,
      isScrollControlled: true,
      builder: (context) => BuyPackageSheet(
        packages: packages,
        currency: currency,
        deal: myDeal,
      ),
    );
    if (chosen == null || !_context.mounted) return;
    if (!await runGuarded(
      _context,
      domain: 'money',
      message: 'buy package failed',
      errorText: l10n.workspaceGenericError,
      action: () => _ref.read(moneyRepositoryProvider).buyPackage(
            workspace.id,
            chosen.id,
          ),
    )) {
      return;
    }
    if (!_context.mounted) return;
    AppSnack.success(
      _context,
      l10n.buyPackageDone,
    );
    // The bill (new charge + higher cap) and every booking surface (the
    // guard now allows more) must refresh.
    _ref
      ..invalidate(myStatementProvider)
      ..invalidate(myLedgerProvider);
    invalidateBookingData(_ref);
  }
}
