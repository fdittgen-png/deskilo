// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/time/clock.dart';
import '../../../../core/ui/inline_banner.dart';
import '../../domain/recapitulative_statement.dart';
import '../../providers/money_providers.dart';

/// #2354 — on Invoicing, while an EU sales list is due: something was
/// reverse-charged last month or this month, and the list (DES, ZM, 349)
/// must be filed for it (Directive art. 262(1)(c)). Nothing otherwise.
class RecapitulativeNotice extends ConsumerWidget {
  const RecapitulativeNotice({super.key, required this.enabled});

  /// Whether `recapitulativeStatement` is on (the screen knows its flags).
  final bool enabled;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!enabled) return const SizedBox.shrink();
    final invoices = ref.watch(invoicesProvider).value;
    if (invoices == null) return const SizedBox.shrink();
    final now = ref.watch(clockProvider).now();
    final lines = recapitulativeStatement(
      invoices,
      from: DateTime(now.year, now.month - 1),
      to: DateTime(now.year, now.month + 1),
    );
    if (lines.isEmpty) return const SizedBox.shrink();
    final l10n =
        context.l10n;
    final period = lines.first.period;
    final count = lines
        .where((l) => l.period == period)
        .fold(0, (sum, l) => sum + l.invoices);
    final month = DateFormat.yMMMM(
      Localizations.localeOf(context).toLanguageTag(),
    ).format(DateTime.parse('$period-01'));
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: InlineBanner(
        key: const ValueKey('recapitulative-notice'),
        icon: Icons.public_outlined,
        text: l10n.recapDue(month, count),
        severity: InlineBannerSeverity.info,
      ),
    );
  }
}
