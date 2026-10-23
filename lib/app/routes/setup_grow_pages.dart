// SPDX-License-Identifier: AGPL-3.0-or-later
//
// The setup guide's Grow step pages, from the feature that owns them: the
// step screen lives in the workspace feature, below money, so the router
// composes them here and hands them in, with the money read the basics
// page needs.
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/money/presentation/widgets/setup_accounting_step.dart';
import '../../features/money/presentation/widgets/setup_documents_step.dart';
import '../../features/money/presentation/widgets/setup_einvoicing_step.dart';
import '../../features/money/presentation/widgets/setup_legal_identity_step.dart';
import '../../features/money/presentation/widgets/setup_numbering_step.dart';
import '../../features/money/presentation/widgets/setup_reminders_step.dart';
import '../../features/money/presentation/widgets/setup_vat_step.dart';
import '../../features/money/providers/money_queries_providers.dart';
import '../../features/workspace/presentation/widgets/setup_grow_pages.dart';

const SetupGrowPages setupGrowPages = SetupGrowPages(
  legalIdentity: SetupLegalIdentityStep.new,
  vat: SetupVatStep.new,
  numbering: SetupNumberingStep.new,
  documents: SetupDocumentsStep.new,
  einvoicing: SetupEInvoicingStep.new,
  accounting: SetupAccountingStep.new,
  reminders: SetupRemindersStep.new,
);

/// Whether the space has issued a document or recorded money (0399): its
/// country and currency are fixed from then on. Unknown while it loads.
bool setupMoneyRecorded(WidgetRef ref, String workspaceId) =>
    ref.watch(moneyRecordedProvider(workspaceId)).value ?? false;
