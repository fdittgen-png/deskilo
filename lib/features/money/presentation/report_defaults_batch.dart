// SPDX-License-Identifier: AGPL-3.0-or-later
//
// The three documents #671 added to report management, split out of
// report_defaults.dart when that file reached its length budget.
//
// What they have in common — and why they sit together rather than
// beside the invoice presets — is that NONE of them is a bill. Two are
// batch prints whose real content the renderer lays out (a template
// cannot place a barcode), and one is a preview of something the app
// does not own. So none of them carries the statutory payment-clause
// footer every invoice-like document must: printing payment terms and
// late-payment penalties on a sheet of QR stickers would be noise at
// best, and a claim the workspace never made at worst.
import '../../../l10n/app_localizations.dart';
import '../domain/invoice_pdf_template.dart';

/// #671 — the chart-of-accounts PREVIEW as a printable document.
///
/// A page the owner can hand to their accountant and ask "is this your
/// chart?". It is a SUGGESTION, and the footer says so on every copy:
/// the app keeps no ledger, and a preview that read as authoritative
/// would be worse than none — an accountant who assumes it is real books
/// against numbers nobody chose.
ReportBands defaultCoaBands(AppLocalizations l10n) => ReportBands(
      header: '''
# ${l10n.reportCoaTitle}
> {{ workspace }}
> {{ coa_chart_name }} ({{ coa_chart_code }}) · {{ country }}
> {{ issued }}
---''',
      body: '''
${l10n.reportCoaIntro}

## ${l10n.reportCoaAccounts}
= ${l10n.reportCoaNumber} | ${l10n.reportCoaLabel}
{% for a in coa_accounts %}{{ a.number }} | {{ a.label }}
> {{ a.note }}
{% endfor %}''',
      footer: '''
> ${l10n.reportCoaDisclaimer}''',
    );

/// #671 — the badge sheet, moved into report management.
///
/// It was a hard-coded PDF; as a document it can carry the workspace's
/// own wording, and it is edited where every other printable is. The
/// CARDS themselves are laid out by the renderer — a template cannot
/// place a barcode — so the bands are what surrounds them.
ReportBands defaultBadgeSheetBands(AppLocalizations l10n) => ReportBands(
      header: '''
# ${l10n.reportBadgesTitle}
> {{ workspace }}
> {{ issued }}
---''',
      body: l10n.reportBadgesIntro,
      footer: '''
> ${l10n.reportBadgesFooter}''',
    );

/// #671 — the space QR cards, likewise. Ten credit-card codes per A4.
ReportBands defaultSpaceCodesBands(AppLocalizations l10n) => ReportBands(
      header: '''
# ${l10n.reportSpaceCodesTitle}
> {{ workspace }}
> {{ issued }}
---''',
      body: l10n.reportSpaceCodesIntro,
      // A stale card is the failure mode that matters here: it sends
      // whoever scans it to the wrong space, silently.
      footer: '''
> ${l10n.reportSpaceCodesFooter}''',
    );
