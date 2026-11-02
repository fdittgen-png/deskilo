// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2519 — why a PLATFORM feature ("asked for, never assumed") still starts
// ON in a new workspace.
//
// A platform entry with `defaultOn: true` is the registry's exception to
// its own tier: a new workspace stores it on, an existing one does not
// (#2566). docs/AGENT_RULES.md allows it for a feature that is neither risky
// nor in need of owner setup, and the epic asks that the reason be written
// down. Each entry here is that reason in one sentence, taken from what the
// feature's own code or issue states: what OFF does (so that starting on
// costs nothing to undo), or the fact the manifest itself proves.
//
// Developer documentation, not user text. `platform_default_reason_test.dart`
// counts the platform default-on entries WITHOUT a reason and lets that
// count only fall: a new platform default-on entry has to come with its
// reason (or raise the count and be refused), and a reason is never invented
// for the sake of the count — an entry nobody can state a reason for stays
// counted.
import 'workspace_feature.dart';

/// The stated reasons, by feature. Only platform entries with `defaultOn:
/// true` may appear here; the test refuses any other, and an empty text.
const Map<WorkspaceFeature, String> platformDefaultReasons = {
  WorkspaceFeature.dataAccessLog:
      'Off hides the row; the server-written log is still written, because '
      'the record is not optional (#719).',
  WorkspaceFeature.configurableSettings:
      'The stored values apply whether or not the editor shows (#2484).',
  WorkspaceFeature.vatManagement:
      'Off hides the configuration surfaces only: a VAT-registered '
      'workspace keeps taxing at its stored or default rates, because the '
      'legal arithmetic is never toggleable (#544).',
  WorkspaceFeature.dunning:
      'Off keeps the manual per-invoice reminder untouched (#472, #502).',
  WorkspaceFeature.demoMode:
      'Off hides the switch and nothing is invented (#970).',
  WorkspaceFeature.instanceWizard:
      'Off leaves the manual how-to alone (#977).',
  WorkspaceFeature.environmentPairs:
      'Off leaves two unrelated entries, as before (#987).',
  WorkspaceFeature.deployments:
      'Off leaves the twins as separate hands (#988, #990).',
  WorkspaceFeature.subscriptionInvoices:
      'Off keeps the fee on the whole-month invoice, as it always was (#802).',
  WorkspaceFeature.usageInvoices:
      'Off keeps the extras on the whole-month invoice (#802).',
  WorkspaceFeature.settlementFold:
      'Documentation only: a stamped PDF is the one affordance (#831).',
  WorkspaceFeature.supplyClassification:
      'Off hides the choice, and every new charge stays property-connected, '
      'the default (#2354).',
  WorkspaceFeature.recapitulativeStatement:
      'Available only where the manifest says (availableIn: the EU), and '
      'only a list filed beside the VAT return (#2354).',
};
