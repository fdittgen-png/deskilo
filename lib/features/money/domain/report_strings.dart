// SPDX-License-Identifier: 0BSD
//
// #1061 / #1048 task 3.1 — the words a document needs, as DATA.
//
// The report-data builders reached `AppLocalizations` through a
// `BuildContext`, which tied the document layer to the widget layer and
// cost two real things: a builder could not be unit-tested without
// pumping a widget, and `tool/report.dart` — pure Dart, never Flutter —
// could not call them, which is why `report_sample_data.dart` exists as
// a SECOND implementation of the same field shapes.
//
// `LetterStrings` in `report_letter_layouts.dart` is this seam already
// done right, and this is deliberately its twin: a plain value object
// with ENGLISH defaults, so the domain renders without Flutter, and the
// app passes its localized copy (`reportStringsOf`) at the widget
// boundary.
//
// Not a second localization mechanism: the ARB files stay the one source
// of words, and `reportStringsOf` is the single place that reads them
// for a document. Per-language templates and reader-language resolution
// are untouched; only HOW the resolved words reach a builder changes.
import '../../profile/domain/personal_info.dart';

class ReportStrings {
  const ReportStrings({
    this.localeName,
    this.dateLocale,
    this.paymentTermsDefault = 'Payment on receipt.',
    this.latePenaltyDefault =
        'Late-payment penalty: three times the statutory interest rate.',
    this.recoveryDefault =
        'Fixed recovery indemnity for collection costs: €40.',
    this.escompteDefault = 'No discount for early payment.',
    this.accessorySupplements = 'Accessory supplements',
    this.levelReservations = 'Level reservations',
    this.officeReservations = 'Office reservations',
    this.deskReservations = 'Desk reservations',
    this.lineAdjustment = 'Adjustment',
    this.categoryPayment = 'Payment',
    this.categoryExpense = 'Expense reimbursement',
    this.categorySubscription = 'Subscription',
    this.categoryOverage = 'Overage',
    this.categoryAdjustment = 'Adjustment',
    this.categoryService = 'Service',
    this.courtesyMr = 'Mr',
    this.courtesyMrs = 'Ms',
    this.paymentsCredits = 'Payments & credits',
    this.agreementExtraHalfDay = 'Extra half-day',
    this.eventTypePayment = 'Payment',
    this.paymentsPendingTag = 'pending validation',
    this.overage = _overage,
    this.participation = _participation,
    this.subscription = _subscription,
    this.participationMonth = _participationMonth,
    this.subscriptionMonth = _subscriptionMonth,
  });

  /// The l10n bundle's locale — `en`, `fr` — for the month NAMES; null
  /// (no bundle) renders with intl's default, as the builders always did.
  final String? localeName;

  /// The widget tree's locale for dates and month labels; null renders
  /// with intl's default. Two sources because the builders always had
  /// two (`AppLocalizations.localeName` vs `Localizations.localeOf`),
  /// and a document must not change by a byte for this seam.
  final String? dateLocale;

  final String paymentTermsDefault;
  final String latePenaltyDefault;
  final String recoveryDefault;
  final String escompteDefault;

  final String accessorySupplements;
  final String levelReservations;
  final String officeReservations;
  final String deskReservations;
  final String lineAdjustment;
  final String categoryPayment;
  final String categoryExpense;
  final String categorySubscription;
  final String categoryOverage;
  final String categoryAdjustment;
  final String categoryService;
  final String courtesyMr;
  final String courtesyMrs;
  final String paymentsCredits;
  final String agreementExtraHalfDay;
  final String eventTypePayment;
  final String paymentsPendingTag;

  /// Plural-bearing sentences are FUNCTIONS: the rule belongs to the
  /// language and the ARB already expresses it — carried across, never
  /// re-implemented here.
  final String Function(int extra) overage;
  final String Function(int pct) participation;
  final String Function(int pct) subscription;
  final String Function(String month, int pct) participationMonth;
  final String Function(String month, int pct) subscriptionMonth;

  String courtesyWord(Courtesy courtesy) => switch (courtesy) {
        Courtesy.none => '',
        Courtesy.mr => courtesyMr,
        Courtesy.mrs => courtesyMrs,
      };

  static String _overage(int extra) => '$extra extra half-days';
  static String _participation(int pct) => 'Participation $pct%';
  static String _subscription(int pct) => 'Subscription $pct%';
  static String _participationMonth(String month, int pct) => '$month $pct%';
  static String _subscriptionMonth(String month, int pct) =>
      'Subscription $month $pct%';
}
