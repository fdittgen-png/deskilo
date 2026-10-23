// SPDX-License-Identifier: AGPL-3.0-or-later
//
// The setup guide's Grow step pages, from the feature that owns them: the
// step screen lives in the workspace feature, below money, so the router
// composes them here and hands them in.
import '../../features/money/presentation/widgets/setup_accounting_step.dart';
import '../../features/money/presentation/widgets/setup_documents_step.dart';
import '../../features/money/presentation/widgets/setup_einvoicing_step.dart';
import '../../features/money/presentation/widgets/setup_legal_identity_step.dart';
import '../../features/money/presentation/widgets/setup_numbering_step.dart';
import '../../features/money/presentation/widgets/setup_reminders_step.dart';
import '../../features/money/presentation/widgets/setup_vat_step.dart';
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
