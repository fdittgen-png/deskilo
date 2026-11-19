// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3556/#4218 — what My finances does when a row is opened: the invoice or the
// payment is opened in the Money screen of the business it belongs to, on its
// own host. A host that cannot be reached or verified is said in words, naming
// the business, with a way to try again.
import 'dart:async';

import 'package:deskilo_money_kernel/deskilo_money_kernel.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/backend/operation_context.dart' show WorkspaceTarget;
import '../../../core/i18n/format_controller.dart';
import '../domain/money_face.dart';
import '../providers/finance_overview_provider.dart';
import '../providers/finance_selection_provider.dart';
import '../providers/money_face_controller.dart';
import '../providers/money_focus_controller.dart';
import 'finance_host_unavailable.dart';

/// Opens [invoiceId] itself, in the Money screen of the space it belongs to
/// — a development space's invoice opens in that development space.
Future<void> openMyInvoice(
  BuildContext context,
  WidgetRef ref,
  WorkspaceTarget? target,
  String invoiceId,
  String business,
) async {
  final router = GoRouter.of(context);
  if (target == null) return;
  final captured = await ref.read(financeWorkspaceEntryProvider)(target);
  if (captured == null) {
    // #4218 — a host that cannot be reached or verified is said, with a way
    // to try again.
    if (context.mounted) {
      showFinanceHostUnavailable(context, business, opening: true,
          retry: () => unawaited(openMyInvoice(context, ref, target, invoiceId, business)));
    }
    return;
  }
  try {
    if (!await captured.open() || !context.mounted || !captured.isCurrent()) return;
  } finally {
    captured.release();
  }
  ref.read(invoiceFocusProvider.notifier).request(target.financeKey, invoiceId);
  router.go('/money');
}

/// Opens the Payments face of [workspaceId] on the month of [at].
Future<void> openMyPayment(
  BuildContext context,
  WidgetRef ref,
  WorkspaceTarget? target,
  DateTime at,
  String business,
) async {
  final router = GoRouter.of(context);
  if (target == null) return;
  final captured = await ref.read(financeWorkspaceEntryProvider)(target);
  if (captured == null) {
    if (context.mounted) {
      showFinanceHostUnavailable(context, business, opening: true,
          retry: () => unawaited(openMyPayment(context, ref, target, at, business)));
    }
    return;
  }
  try {
    if (!await captured.open() || !context.mounted || !captured.isCurrent()) return;
  } finally {
    captured.release();
  }
  if (!context.mounted) return;
  ref.read(moneyFaceControllerProvider.notifier).show(MoneyFace.payments);
  final local = personalFormatOf(context).wall(at);
  ref
      .read(moneyFocusControllerProvider.notifier)
      .setPeriod(yearMonth(local.year, local.month));
  router.go('/money');
}
