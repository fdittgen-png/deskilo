// SPDX-License-Identifier: 0BSD
//
// #902 — Settings → Payment conditions: what THIS member's documents
// print, and who set them. Read-only by design: the workspace sets the
// default, an authorised admin changes a member's own through
// validation (#881) — the member reads.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/help/help_dot.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../workspace/providers/workspace_providers.dart';
import '../widgets/payment_terms_card.dart';

class MyPaymentTermsScreen extends ConsumerWidget {
  const MyPaymentTermsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final member = ref.watch(myMemberProvider).value;
    return Scaffold(
      appBar: AppBar(
        title: HelpDotTitle(
          l10n?.paymentTermsTitle ?? 'Payment conditions',
          l10n?.helpTopicSettings ?? 'Settings & profile',
        ),
      ),
      body: member == null
          ? const SizedBox.shrink()
          : SingleChildScrollView(
              padding: AppSpacing.gutterAll,
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: PaymentTermsCard(member: member, isSelf: true),
                ),
              ),
            ),
    );
  }
}
