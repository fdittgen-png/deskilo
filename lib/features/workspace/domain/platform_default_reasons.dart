// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2519 — why a PLATFORM feature ("asked for, never assumed") still starts
// ON in the registry.
//
// A platform entry with `defaultOn: true` is the registry's exception to
// its own tier. Normal workspace creation stores platform features off;
// the registry default is used by the Demo and server-choice feature set
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
  WorkspaceFeature.nfcSeatTags:
      'The owner explicitly configures a tag on a seat; the original tag '
      'feature decision kept the configuration and scan path on (#604).',
  WorkspaceFeature.qrBadges:
      'Issuing a badge is an explicit action in the kiosk badge manager; '
      'the original badge decision kept this path on (#604).',
  WorkspaceFeature.invoiceAddressWindow:
      'Invoices need the recipient in the envelope window; the country '
      'supplies a default side that the owner can override (#868).',
  WorkspaceFeature.managedProfiles:
      'An admin must explicitly create a managed profile; it permits '
      'onboarding before an account and bound handover later (#887).',
  WorkspaceFeature.memberPaymentTerms:
      'Without an override the workspace terms apply; a permitted person '
      'must request a change and validation decides it (#881).',
  WorkspaceFeature.memberReports:
      'Members can obtain their financial agreement and monthly payments '
      'report themselves instead of depending on an admin to send them '
      '(#494).',
  WorkspaceFeature.reportTexts:
      'The owner must add text to change a report; absent language '
      'variants fall back to the default (#880).',
  WorkspaceFeature.vatReport:
      'The VAT period report exposes the taxable positions and their '
      'reconciliation with declaration boxes for the accountant (#878).',
  WorkspaceFeature.coOwner:
      'The owner can appoint a successor before departure; appointment is '
      'explicit and the server succession safeguard remains on (#341).',
  WorkspaceFeature.kioskMode:
      'The original feature audit kept the kiosk available by default; '
      'an owner still configures the kiosk account (#341).',
  WorkspaceFeature.nfcBadges:
      'The original feature audit kept badges available by default under '
      'the kiosk; credentials still need to be configured (#341).',
  WorkspaceFeature.usageRecords:
      'The member-facing trail explains billed time; an early-departure '
      'correction is requested and validated, not automatic (#833).',
  WorkspaceFeature.letterStandard:
      'Person-facing reports need the standard window-envelope layout; '
      'a kind without a custom design uses its default layout (#874).',
  WorkspaceFeature.vatDeclarations:
      'The VAT screen offers period declarations only for a registered '
      'workspace; preparing a return does not submit it (#534).',
  WorkspaceFeature.usageReport:
      'The month-end report shows a member what was consumed against the '
      'subscription paid ahead; it needs usage records and member reports '
      '(#873).',
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
  WorkspaceFeature.calendarValidations:
      'Off leaves the calendar as it was: the decisions are still taken, the '
      'calendar just carries none of them (#843).',
  WorkspaceFeature.configurationTransfer:
      'Off leaves the space file as it was: it carries settings and the floor '
      'plan only (#916).',
  WorkspaceFeature.inputVat:
      'Off leaves the VAT return as it was: it declares the VAT collected '
      'only (#2357).',
  WorkspaceFeature.paymentReminders:
      'Off keeps reminders a manual action, as before (#726).',
  WorkspaceFeature.invoicingWizard:
      'Off leaves the separate screens the guided month-close runs over '
      '(#827).',
  WorkspaceFeature.reportDesigner:
      'Off leaves the editor sheet the full-screen designer sits over (#822).',
  WorkspaceFeature.reportDesignExchange:
      'Off leaves designs editable in the designer, as before (#864).',
  WorkspaceFeature.validationScopes:
      'Off keeps who validates as before: the owner and the admins (#732).',
  WorkspaceFeature.validationChain:
      'Off keeps every validation asked at once, and nobody validating their '
      'own event, as before (#840).',
  WorkspaceFeature.salesTax:
      'Not an optional extra for a seller in the United States: with it off '
      'such a seller cannot issue, and it is an invoicing mode of that '
      'seller only (#2362).',
  WorkspaceFeature.viesVerification:
      'Off issues a general service reverse-charged to a business abroad '
      'outside the app: it is issued here only after a valid VIES check '
      '(#2354).',
  WorkspaceFeature.kioskMemberPhotos:
      'Off shows the name initial, like everywhere else; the photo is the one '
      'the member set on their own profile (#616).',
  WorkspaceFeature.reportLayouts:
      'A kind without a layout is drawn by its bands as before; only a kind '
      'the owner gave a layout changes (#875).',
  WorkspaceFeature.einvoiceCustomerDelivery:
      'A second leg beside the government platform that only shows on the '
      'send sheet of an issued invoice; the government channel and the VAT '
      'declarations are unchanged (#568).',
  WorkspaceFeature.invoiceJourney:
      'A presentation of the existing invoice lifecycle: nothing changes in '
      'the data or the RPCs (#812).',
  WorkspaceFeature.invoicePdfTemplate:
      'Owner-written intro and footer on the PDF only: the e-invoice XML '
      'never sees it (#454).',
  WorkspaceFeature.whatsappIntegration:
      'Members share a number on their own profile and one tap opens a chat '
      'with it; there is no server-side WhatsApp integration (#223).',
};
