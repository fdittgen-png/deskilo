// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2354 — the money tiles a member's page shows in its billing group:
// the member page imports this one file.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/trace/guarded.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/vies_check.dart';
import '../../providers/vies_providers.dart';

export 'member_carnet_tile.dart';
export 'member_tax_certificates.dart';

/// #2354 — on a member's page, for whoever issues invoices: the last
/// check of the member's VAT number against VIES, and checking it again.
/// A valid answer with its consultation number is the evidence a
/// reverse-charged invoice needs; the server refuses one without it.
class ViesCheckTile extends ConsumerWidget {
  const ViesCheckTile({
    super.key,
    required this.workspaceId,
    required this.memberId,
  });

  final String workspaceId;
  final String memberId;

  static String statusText(
    AppLocalizations l10n,
    ViesCheck check,
    String locale,
  ) {
    final date = check.checkedAt == null
        ? ''
        : DateFormat.yMMMd(locale).format(check.checkedAt!);
    return switch (check.status) {
      ViesStatus.none => l10n.viesStatusNone,
      ViesStatus.valid => l10n.viesStatusValid(check.consultation, date),
      ViesStatus.invalid => l10n.viesStatusInvalid(date),
      ViesStatus.unavailable => l10n.viesStatusUnavailable(date),
    };
  }

  Future<void> _open(BuildContext context, WidgetRef ref) async {
    final l10n =
        context.l10n;
    final check = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.viesTileTitle),
        content: Text(l10n.viesCheckExplainer),
        actions: [
          TextButton(
            key: const ValueKey('vies-check-cancel'),
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(MaterialLocalizations.of(ctx).cancelButtonLabel),
          ),
          FilledButton(
            key: const ValueKey('vies-check-now'),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l10n.viesCheckNow),
          ),
        ],
      ),
    );
    if (check != true || !context.mounted) return;
    if (!await runGuarded(
      context,
      domain: 'money',
      message: 'vies check failed',
      errorText: l10n.viesCheckFailed,
      action: () => ref.read(checkViesProvider)(workspaceId, memberId),
    )) {
      return;
    }
    ref.invalidate(memberViesCheckProvider(memberId));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n =
        context.l10n;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final check = ref.watch(memberViesCheckProvider(memberId)).value;
    return ListTile(
      key: const ValueKey('member-page-vies-check'),
      leading: Icon(
        check?.status == ViesStatus.valid
            ? Icons.verified_outlined
            : Icons.fact_check_outlined,
      ),
      title: Text(l10n.viesTileTitle),
      subtitle: Text(statusText(l10n, check ?? ViesCheck.none, locale)),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => _open(context, ref),
    );
  }
}
