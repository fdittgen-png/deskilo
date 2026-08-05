// SPDX-License-Identifier: 0BSD
import 'dart:convert' show utf8;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../core/files/file_names.dart';
import '../../../core/files/file_saver.dart';
import '../../../core/share/file_sharer.dart';
import '../../../core/trace/guarded.dart';
import '../../../core/trace/trace_logger.dart';
import '../../../core/ui/app_snack.dart';
import '../../../l10n/app_localizations.dart';
import '../../events/providers/event_providers.dart';
import '../../members/providers/directory_providers.dart';
import '../../reservations/providers/reservation_providers.dart';
import '../../workspace/domain/workspace.dart';
import '../../workspace/domain/workspace_feature.dart';
import '../../workspace/providers/workspace_providers.dart';
import '../domain/invoice_legal.dart';
import '../domain/vat_rate.dart';
import '../domain/e_invoice_routing.dart';
import '../domain/invoice.dart';
import '../domain/invoice_pdf.dart';
import '../domain/einvoice_gateway.dart';
import '../domain/invoice_cii.dart';
import '../domain/invoice_ubl.dart';
import '../domain/fec.dart';
import '../domain/saf_t.dart';
import '../domain/invoice_ubl_check.dart';
import '../domain/ledger_entry.dart';
import '../domain/invoice_pdf_template.dart';
import '../domain/dunning.dart';
import '../domain/invoice_report.dart';
import '../domain/statement.dart';
import '../providers/money_providers.dart';
import 'report_defaults.dart';
import 'e_invoice_identity.dart';
import 'widgets/einvoice_environment_picker.dart';
import 'invoice_line_text.dart';
import 'period_label.dart';
import 'widgets/accounting_export_sheet.dart';
import 'widgets/e_invoice_sheet.dart';
import 'widgets/invoice_detail_sheet.dart';
import 'widgets/invoice_form_sheet.dart';
import 'widgets/invoicing_dashboard.dart';
import '../../../core/time/clock.dart';
import '../../../core/time/workspace_time.dart';
import '../../../core/time/work_hours.dart';
import '../../workspace/presentation/feature_names.dart';
import '../../events/domain/workspace_event.dart';
import '../../plan/domain/accessory.dart';
import '../../plan/providers/accessory_providers.dart';
import '../../plan/providers/floor_plan_providers.dart';
import '../domain/package.dart';
import '../domain/service_item.dart';
import '../domain/fee_band.dart';
import '../../plan/domain/office.dart';
import '../../plan/domain/level.dart';
import '../../plan/domain/floor_plan.dart';

/// Everything an issued invoice can be PUT THROUGH, extracted out of the
/// screen (0069): the archive rows, the open cards and the detail sheet all
/// drive the same code, so an action cannot behave differently depending on
/// where it was tapped.

/// Renders the signed PDF. Every context-derived value is captured BEFORE
/// the first await (use_build_context_synchronously).
/// The active workspace's PDF template (#454) — empty when the
/// invoicePdfTemplate feature is off, so switching the flag off takes
/// the text off every future render without touching the template. A
/// SYNC read: the invoices hub watches the provider, so it is warm
/// before any render action can be tapped.
/// Resolves every `![name]` a rendered report references to bytes
/// (#488) — misses are skipped; the document renders without them.
Future<Map<String, Uint8List>> resolveReportImages(
  WidgetRef ref,
  InvoiceReport? report,
) async {
  if (report == null) return const {};
  final images = <String, Uint8List>{};
  for (final name in reportImageRefs(report)) {
    try {
      final bytes = await ref.read(reportImageBytesProvider(name).future);
      if (bytes != null) images[name] = bytes;
    } catch (e, st) {
      TraceLogger.instance.warn('money', 'report image fetch failed',
          error: e, stackTrace: st);
    }
  }
  return images;
}

InvoicePdfTemplate invoicePdfTemplateFor(WidgetRef ref) =>
    ref
            .read(enabledFeaturesSyncProvider)
            .contains(WorkspaceFeature.invoicePdfTemplate)
        ? ref.read(invoicePdfTemplateProvider).value ??
            InvoicePdfTemplate.empty
        : InvoicePdfTemplate.empty;

/// The LEGAL mention variables (#480) shared by every document's data
/// model: the seller's statutory lines and the payment-condition
/// mentions French law requires on a professional invoice. The four
/// mandatory clauses fall back to localized statutory defaults when the
/// owner configured nothing, so an untouched workspace still issues a
/// compliant document. [seller] (the invoice's frozen party) wins over
/// the live [workspace] for the identity numbers — the snapshot is what
/// the signature covers.
Map<String, Object?> legalMentionData(
  AppLocalizations? l10n,
  Workspace? workspace, {
  InvoiceParty? seller,
  InvoiceParty? buyer,
  String clientAddress = '',
}) {
  final legal = InvoiceLegal.fromJson(workspace?.invoiceLegal ?? const {});
  String orDefault(String value, String fallback) =>
      value.trim().isNotEmpty ? value.trim() : fallback;
  // #484 — the B2B-only clauses (mandatory between professionals) have
  // NO default on an association's documents; explicit text still wins.
  String orB2bDefault(String value, String fallback) =>
      legal.isAssociation ? value.trim() : orDefault(value, fallback);
  return <String, Object?>{
    'seller_legal_form': legal.legalForm,
    'seller_registration': legal.registration,
    'seller_vat_id': seller?.vatId ?? workspace?.vatId ?? '',
    'seller_legal_id': seller?.legalId ?? workspace?.legalId ?? '',
    'exemption_reason': seller?.taxExemptionReason ??
        workspace?.taxExemptionReason ??
        '',
    'client_address': clientAddress,
    // #482 — the client's own identifiers on B2B documents.
    'client_vat_id': buyer?.vatId ?? '',
    'client_legal_id': buyer?.legalId ?? '',
    'payment_terms': orDefault(
      legal.paymentTerms,
      l10n?.invoiceLegalPaymentTermsDefault ?? 'Payment on receipt.',
    ),
    'late_penalty': orB2bDefault(
      legal.latePenalty,
      l10n?.invoiceLegalLatePenaltyDefault ??
          'Late-payment penalty: three times the statutory interest rate.',
    ),
    'recovery_indemnity': orB2bDefault(
      legal.recoveryIndemnity,
      l10n?.invoiceLegalRecoveryDefault ??
          'Fixed recovery indemnity for collection costs: €40.',
    ),
    'escompte': orB2bDefault(
      legal.escompte,
      l10n?.invoiceLegalEscompteDefault ??
          'No discount for early payment.',
    ),
    'insurance': legal.insurance,
    'special_mentions': legal.specialMentions,
  };
}

/// One line's postal address as the document prints it, from the frozen
/// buyer party (0069) or the flat snapshot on legacy invoices.
String _clientAddressOf(Invoice invoice) {
  final buyer = invoice.buyerParty;
  if (buyer == null) return invoice.memberAddress;
  final cityLine =
      [buyer.postalCode, buyer.city].where((p) => p.isNotEmpty).join(' ');
  return [buyer.street, cityLine].where((p) => p.isNotEmpty).join(', ');
}

/// The report data model (#470/#474) — every value the Liquid bands
/// can reference, resolved where formatting is at hand. Amounts arrive
/// pre-formatted in the workspace currency; the flags feed
/// `{% if %}` conditions. Shared by the PDF render AND the in-app
/// quick preview. [workspace] feeds the legal mention variables (#480);
/// null leaves the seller lines empty and the clauses on their
/// localized statutory defaults.
Map<String, Object?> invoiceReportData(
  BuildContext context,
  Invoice invoice, {
  required bool proforma,
  required bool copy,
  Workspace? workspace,
}) {
  final l10n = AppLocalizations.of(context);
  final currency = NumberFormat.simpleCurrency(name: invoice.currency);
  final dateFormat = DateFormat.yMMMd(
    Localizations.maybeLocaleOf(context)?.toString(),
  );
  String money(int cents) => currency.format(cents / 100);
  String rate(double percent) =>
      '${percent == percent.roundToDouble() ? percent.toStringAsFixed(0) : percent} %';
  return <String, Object?>{
    'workspace': invoice.workspaceName,
    'workspace_address': invoice.workspaceAddress,
    'member': invoice.memberName,
    'number': invoice.number,
    'period': invoicePeriodLabel(context, invoice),
    'issued': dateFormat.format(invoice.issuedAt),
    'issued_by': invoice.issuerName,
    'replaces': invoice.replacesNumber,
    'total': money(invoice.totalCents),
    'charges': money(invoice.chargesCents),
    'payments': money(invoice.lines
        .where((l) => l.amountCents < 0)
        .fold(0, (sum, l) => sum + l.amountCents)),
    // #480 — total HT / total TVA beside the TTC the bands always had.
    'net_total': money(invoice.netCents),
    'vat_total': money(invoice.vatCents),
    'voided': invoice.isVoided,
    'proforma': proforma,
    'copy': copy,
    'has_vat': invoice.vatTotals.any((t) => t.vatCents > 0),
    'lines': [
      for (final line in invoice.lines)
        {
          'label': invoiceLineText(l10n, line),
          'amount': money(line.amountCents),
          'negative': line.amountCents < 0,
          // #480 — quantity, unit price and per-line VAT so a template
          // can print the statutory line detail.
          'qty': '${line.quantity}',
          'unit_price': money(line.quantity > 1
              ? line.amountCents ~/ line.quantity
              : line.amountCents),
          'vat_rate': line.vatPercent > 0 ? rate(line.vatPercent) : '',
          'net': money(vatSplit(line.amountCents, line.vatPercent).netCents),
        },
    ],
    'vat': [
      for (final t in invoice.vatTotals.where((t) => t.vatCents > 0))
        {
          'rate': rate(t.percent),
          'net': money(t.netCents),
          'amount': money(t.vatCents),
        },
    ],
    ...legalMentionData(
      l10n,
      workspace,
      seller: invoice.sellerParty,
      buyer: invoice.buyerParty,
      clientAddress: _clientAddressOf(invoice),
    ),
  };
}

/// The statement data model (#476): the member's monthly summary as
/// report lines — subscription, overage, supplements, services,
/// packages and credits, with the balance as the total. Zero rows are
/// skipped so the document reads like the bill.
Map<String, Object?> statementReportData(
  BuildContext context, {
  required Statement statement,
  required String workspaceName,
  required String memberName,
  required String periodLabel,
  required String currencyCode,
  Workspace? workspace,
}) {
  final l10n = AppLocalizations.of(context);
  final currency = NumberFormat.simpleCurrency(name: currencyCode);
  String money(int cents) => currency.format(cents / 100);
  final lines = <Map<String, Object?>>[
    if (statement.feeCents > 0)
      {
        'label': l10n?.billSubscription(statement.subscriptionPct) ??
            'Subscription ${statement.subscriptionPct}%',
        'amount': money(statement.feeCents),
        'negative': false,
      },
    if (statement.overageCents > 0)
      {
        'label': l10n?.billOverage(statement.extraHalfDays) ??
            '${statement.extraHalfDays} extra half-days',
        'amount': money(statement.overageCents),
        'negative': false,
      },
    if (statement.accessorySupplementCents > 0)
      {
        'label': l10n?.billAccessorySupplements ?? 'Accessory supplements',
        'amount': money(statement.accessorySupplementCents),
        'negative': false,
      },
    if (statement.levelSupplementCents > 0)
      {
        'label': l10n?.levelSupplementLabel ?? 'Level reservations',
        'amount': money(statement.levelSupplementCents),
        'negative': false,
      },
    if (statement.officeSupplementCents > 0)
      {
        'label': l10n?.officeSupplementLabel ?? 'Office reservations',
        'amount': money(statement.officeSupplementCents),
        'negative': false,
      },
    if (statement.deskSupplementCents > 0)
      {
        'label': l10n?.deskSupplementLabel ?? 'Desk reservations',
        'amount': money(statement.deskSupplementCents),
        'negative': false,
      },
    if (statement.creditsCents != 0)
      {
        'label': l10n?.billPaymentsCredits ?? 'Payments & credits',
        'amount': money(statement.creditsCents),
        'negative': statement.creditsCents > 0,
      },
  ];
  return <String, Object?>{
    'workspace': workspaceName,
    'workspace_address': workspace?.address ?? '',
    'member': memberName,
    'number': '',
    'period': periodLabel,
    'issued': periodLabel,
    'issued_by': workspaceName,
    'replaces': '',
    'total': money(statement.balanceCents.abs()),
    'net_total': money(statement.feeCents + statement.overageCents),
    'vat_total': money(0),
    'charges': money(statement.feeCents + statement.overageCents),
    'payments': money(statement.creditsCents),
    'voided': false,
    'proforma': false,
    'copy': false,
    'has_vat': false,
    'lines': lines,
    'vat': const <Map<String, Object?>>[],
    ...legalMentionData(l10n, workspace),
  };
}

/// The FINANCIAL AGREEMENT data model (#494): every standing price that
/// applies to a member — the subscription fee for their percentage, the
/// extra half-day, the service and package catalogue, whole-space and
/// accessory supplements. The owner/admin SENDS it; the member reads,
/// shares or downloads it self-service.
Map<String, Object?> agreementReportData(
  BuildContext context,
  WidgetRef ref, {
  required String memberName,
  required int subscriptionPct,
}) {
  final l10n = AppLocalizations.of(context);
  final workspace = ref.read(currentWorkspaceProvider).value;
  final currency =
      NumberFormat.simpleCurrency(name: workspace?.currencyCode ?? 'EUR');
  String money(int cents) => currency.format(cents / 100);
  final bands = ref.read(feeBandsProvider).value ?? const <FeeBand>[];
  final band = bands
      .where((b) => b.fromPct < subscriptionPct && subscriptionPct <= b.toPct)
      .firstOrNull;
  final services = ref.read(servicesProvider).value ?? const <ServiceItem>[];
  final packages =
      ref.read(packagesProvider).value?.where((p) => p.active) ??
          const <Package>[];
  final levels = ref.read(levelsProvider).value ?? const <Level>[];
  final offices = [
    for (final level in levels)
      ...(ref.read(floorPlanProvider(level.id)).value?.offices ??
          const <Office>[]),
  ];
  final accessories =
      ref.read(accessoriesProvider()).value ?? const <Accessory>[];
  final lines = <Map<String, Object?>>[
    if (band != null) ...[
      {
        'label': l10n?.billSubscription(subscriptionPct) ??
            'Subscription $subscriptionPct%',
        'amount': money(band.feeCents),
      },
      {
        'label': l10n?.agreementExtraHalfDay ?? 'Extra half-day',
        'amount': money(band.overageFeeCents),
      },
    ],
    for (final service in services)
      {'label': service.name, 'amount': money(service.priceCents)},
    for (final package in packages)
      {
        'label': '${package.name} (${package.days}d)',
        'amount': money(package.priceCents),
      },
    for (final level in levels)
      if (level.bookableAsWhole && level.priceCents > 0)
        {
          'label':
              '${level.name} — ${l10n?.levelSupplementLabel ?? 'Level reservations'}',
          'amount': money(level.priceCents),
        },
    for (final office in offices)
      if (office.bookableAsWhole && office.priceCents > 0)
        {
          'label':
              '${office.name} — ${l10n?.officeSupplementLabel ?? 'Office reservations'}',
          'amount': money(office.priceCents),
        },
    for (final accessory in accessories)
      if (accessory.supplementCents > 0)
        {
          'label': accessory.name,
          'amount': money(accessory.supplementCents),
        },
  ];
  return <String, Object?>{
    'workspace': workspace?.name ?? '',
    'workspace_address': workspace?.address ?? '',
    'member': memberName,
    'subscription_pct': subscriptionPct,
    'number': '',
    'period': '',
    'issued': DateFormat.yMMMd(
      Localizations.maybeLocaleOf(context)?.toString(),
    ).format(ref.read(clockProvider).now()),
    'issued_by': workspace?.name ?? '',
    'replaces': '',
    'total': band == null ? '' : money(band.feeCents),
    'charges': '',
    'payments': '',
    'net_total': '',
    'vat_total': '',
    'voided': false,
    'proforma': false,
    'copy': false,
    'has_vat': false,
    'lines': lines,
    'vat': const <Map<String, Object?>>[],
    ...legalMentionData(l10n, workspace),
  };
}

/// The MONTHLY PAYMENTS data model (#494): everything the member paid,
/// declared or had validated in [period] — the little balance sheet a
/// member can pull self-service.
Map<String, Object?> paymentsReportData(
  BuildContext context,
  WidgetRef ref, {
  required String period,
  required String memberName,
}) {
  final l10n = AppLocalizations.of(context);
  final workspace = ref.read(currentWorkspaceProvider).value;
  final me = ref.read(myMemberProvider).value;
  final currency =
      NumberFormat.simpleCurrency(name: workspace?.currencyCode ?? 'EUR');
  String money(int cents) => currency.format(cents / 100);
  final dateFormat = DateFormat.yMMMd(
    Localizations.maybeLocaleOf(context)?.toString(),
  );
  final ledger = (ref.read(myLedgerProvider).value ?? const <LedgerEntry>[])
      .where((entry) =>
          entry.period == period && entry.kind == LedgerKind.credit)
      .toList();
  final pending = (ref.read(eventsProvider).value ?? const [])
      .where((event) =>
          event.isPending &&
          event.subjectMemberId == me?.id &&
          (event.type == EventType.payment ||
              event.type == EventType.expense) &&
          (event.payload['period'] as String? ?? period) == period)
      .toList();
  final validatedCents =
      ledger.fold<int>(0, (sum, entry) => sum + entry.amountCents);
  final pendingCents = pending.fold<int>(
      0,
      (sum, event) =>
          sum + ((event.payload['amount_cents'] as num?)?.toInt() ?? 0));
  final statement = ref.read(myStatementProvider(period)).value;
  return <String, Object?>{
    'workspace': workspace?.name ?? '',
    'workspace_address': workspace?.address ?? '',
    'member': memberName,
    'number': '',
    'period': period,
    'issued': dateFormat.format(ref.read(clockProvider).now()),
    'issued_by': workspace?.name ?? '',
    'replaces': '',
    'total': money(statement?.balanceCents ?? 0),
    'charges': '',
    'payments': money(validatedCents),
    'net_total': '',
    'vat_total': '',
    'validated_total': money(validatedCents),
    'pending_total': money(pendingCents),
    'voided': false,
    'proforma': false,
    'copy': false,
    'has_vat': false,
    'lines': [
      for (final entry in ledger)
        {
          'label':
              '${dateFormat.format(WorkspaceTime.dateOf(entry.occurredOn ?? entry.createdAt))} · ${entry.description.isEmpty ? (l10n?.billPaymentsCredits ?? 'Payments & credits') : entry.description}',
          'amount': money(entry.amountCents),
        },
      for (final event in pending)
        {
          'label':
              '${event.payload['note'] as String? ?? (l10n?.eventTypePayment ?? 'Payment')} — ${l10n?.paymentsPendingTag ?? 'pending validation'}',
          'amount': money(
              (event.payload['amount_cents'] as num?)?.toInt() ?? 0),
        },
    ],
    'vat': const <Map<String, Object?>>[],
    ...legalMentionData(l10n, workspace),
  };
}

/// The WORKSPACE REPORT data model (#494): everything about the space —
/// identity, floor-plan counts, availability, features, prices.
Map<String, Object?> workspaceReportData(BuildContext context, WidgetRef ref) {
  final l10n = AppLocalizations.of(context);
  final workspace = ref.read(currentWorkspaceProvider).value;
  final currency =
      NumberFormat.simpleCurrency(name: workspace?.currencyCode ?? 'EUR');
  String money(int cents) => currency.format(cents / 100);
  final levels = ref.read(levelsProvider).value ?? const <Level>[];
  final plans = [
    for (final level in levels)
      ref.read(floorPlanProvider(level.id)).value,
  ].whereType<FloorPlan>().toList();
  final features = ref.read(enabledFeaturesSyncProvider);
  final members = ref.read(workspaceMembersProvider).value ?? const [];
  final bands = ref.read(feeBandsProvider).value ?? const <FeeBand>[];
  final services = ref.read(servicesProvider).value ?? const <ServiceItem>[];
  final openDays = ref.read(openWeekdaysProvider).value ?? const <int>[];
  final hours = WorkHours.current;
  String clock(int minutes) =>
      '${(minutes ~/ 60).toString().padLeft(2, '0')}:${(minutes % 60).toString().padLeft(2, '0')}';
  final dayNames = DateFormat.E(
    Localizations.maybeLocaleOf(context)?.toString(),
  );
  final monday = DateTime(2024, 1, 1); // a Monday — weekday names only.
  return <String, Object?>{
    'workspace': workspace?.name ?? '',
    'workspace_address': workspace?.address ?? '',
    'member': '',
    'number': '',
    'period': '',
    'issued': DateFormat.yMMMd(
      Localizations.maybeLocaleOf(context)?.toString(),
    ).format(ref.read(clockProvider).now()),
    'issued_by': workspace?.name ?? '',
    'replaces': '',
    'total': '',
    'charges': '',
    'payments': '',
    'net_total': '',
    'vat_total': '',
    'voided': false,
    'proforma': false,
    'copy': false,
    'has_vat': false,
    'country': workspace?.countryCode ?? '',
    'currency': workspace?.currencyCode ?? '',
    'timezone': workspace?.timezone ?? '',
    'members_count': members.length,
    'levels_count': levels.length,
    'offices_count':
        plans.fold<int>(0, (sum, plan) => sum + plan.offices.length),
    'desks_count':
        plans.fold<int>(0, (sum, plan) => sum + plan.desks.length),
    'seats_count':
        plans.fold<int>(0, (sum, plan) => sum + plan.seats.length),
    'open_days': openDays
        .map((d) => dayNames.format(monday.add(Duration(days: d - 1))))
        .join(', '),
    'work_hours':
        '${clock(hours.startMinutes)}–${clock(hours.halfBoundaryMinutes)}–${clock(hours.endMinutes)}',
    'features': [
      for (final feature in features)
        {'label': featureName(l10n, feature)},
    ],
    'lines': [
      for (final band in bands)
        {
          'label':
              '${l10n?.billSubscription(band.toPct) ?? 'Subscription ${band.toPct}%'} (${band.fromPct + 1}–${band.toPct}%)',
          'amount': money(band.feeCents),
        },
      for (final service in services)
        {'label': service.name, 'amount': money(service.priceCents)},
    ],
    'vat': const <Map<String, Object?>>[],
    ...legalMentionData(l10n, workspace),
  };
}

/// Warms every provider the #494 letter-document builders read, so the
/// SYNC data builders see loaded values (the invoice-hub warming idiom).
Future<void> warmLetterDocProviders(WidgetRef ref, String docId) async {
  Future<void> quiet(Future<void> Function() load) async {
    try {
      await load();
    } catch (e, st) {
      TraceLogger.instance.warn('money', 'letter-doc provider warm failed',
          error: e, stackTrace: st);
    }
  }

  await quiet(() => ref.read(invoicePdfTemplateProvider.future));
  if (docId == 'agreement') {
    await quiet(() => ref.read(feeBandsProvider.future));
    await quiet(() => ref.read(servicesProvider.future));
    await quiet(() => ref.read(packagesProvider.future));
    await quiet(() => ref.read(accessoriesProvider().future));
    await quiet(() async {
      final levels = await ref.read(levelsProvider.future);
      for (final level in levels) {
        await ref.read(floorPlanProvider(level.id).future);
      }
    });
  } else if (docId == 'payments') {
    await quiet(() => ref.read(myLedgerProvider.future));
    await quiet(() => ref.read(eventsProvider.future));
  } else if (docId == 'workspace') {
    await quiet(() => ref.read(workspaceMembersProvider.future));
    await quiet(() => ref.read(feeBandsProvider.future));
    await quiet(() => ref.read(servicesProvider.future));
    await quiet(() => ref.read(openWeekdaysProvider.future));
    await quiet(() async {
      final levels = await ref.read(levelsProvider.future);
      for (final level in levels) {
        await ref.read(floorPlanProvider(level.id).future);
      }
    });
  }
  await quiet(() => ref.read(memberNamesProvider.future));
}

/// Renders letter document [docId] through the workspace's template
/// bands (or the shipped default — a broken template never blocks, the
/// #470 contract).
InvoiceReport renderLetterDoc(
  BuildContext context,
  WidgetRef ref, {
  required String docId,
  required Map<String, Object?> data,
}) {
  final l10n = AppLocalizations.of(context);
  final bands = invoicePdfTemplateFor(ref).docBands(docId) ??
      defaultBandsForDoc(docId, l10n);
  return renderReportBands(bands: bands, data: data) ??
      renderReportBands(
          bands: defaultBandsForDoc(docId, l10n), data: data)!;
}

/// The PDF of a rendered letter document (#494).
Future<({Uint8List bytes, String fileName})> letterDocPdf(
  BuildContext context,
  WidgetRef ref, {
  required InvoiceReport report,
  required String title,
}) async {
  final l10n = AppLocalizations.of(context);
  final images = await resolveReportImages(ref, report);
  Future<pw.Font> font(String asset) async =>
      pw.Font.ttf(await rootBundle.load(asset));
  final bytes = await buildBandedLetterPdf(
    report: report,
    reportImages: images,
    pageLabel: l10n?.invoicePdfPage ?? 'Page',
    documentTitle: title,
    baseFont: await font('assets/fonts/Roboto-Regular.ttf'),
    boldFont: await font('assets/fonts/Roboto-Bold.ttf'),
  );
  return (
    bytes: Uint8List.fromList(bytes),
    fileName: '${safeFileSlug(title)}.pdf',
  );
}

/// The reminder-letter data model (#472/#474) — the invoice basics plus

/// The reminder-letter data model (#472/#474) — the invoice basics plus
/// the level, the letter date and the days the invoice sits open.
Map<String, Object?> reminderReportData(
  BuildContext context,
  WidgetRef ref,
  Invoice invoice, {
  required int level,
}) {
  final currency = NumberFormat.simpleCurrency(name: invoice.currency);
  final dateFormat = DateFormat.yMMMd(
    Localizations.maybeLocaleOf(context)?.toString(),
  );
  final now = ref.read(clockProvider).now();
  final l10n = AppLocalizations.of(context);
  final workspace = ref.read(currentWorkspaceProvider).value;
  return <String, Object?>{
    'workspace': invoice.workspaceName,
    'workspace_address': invoice.workspaceAddress,
    'member': invoice.memberName,
    'number': invoice.number,
    'issued': dateFormat.format(invoice.issuedAt),
    'total': currency.format(invoice.totalCents / 100),
    'reminder_level': level,
    'reminder_date': dateFormat.format(now),
    'days_open': now.difference(invoice.issuedAt).inDays,
    // #480 — a reminder cites the same statutory payment clauses.
    ...legalMentionData(
      l10n,
      workspace,
      seller: invoice.sellerParty,
      buyer: invoice.buyerParty,
      clientAddress: _clientAddressOf(invoice),
    ),
  };
}

Future<({List<int> bytes, String fileName})> buildInvoicePdfFile(
  BuildContext context,
  Invoice invoice, {
  bool proforma = false,
  bool copy = false,
  String facturXml = '',
  Uint8List? colorProfile,
  InvoicePdfTemplate template = InvoicePdfTemplate.empty,
  Workspace? workspace,
  // #488 — resolves ![name] references; null renders without images.
  Future<Uint8List?> Function(String name)? reportImage,
}) async {
  final l10n = AppLocalizations.of(context);
  final currency = NumberFormat.simpleCurrency(name: invoice.currency);
  final dateFormat = DateFormat.yMMMd(
    Localizations.maybeLocaleOf(context)?.toString(),
  );
  final dateLabel = dateFormat.format(invoice.issuedAt);
  final periodLabel = invoicePeriodLabel(context, invoice);
  final voidedAt = invoice.voidedAt;
  final voidedLabel = voidedAt == null
      ? ''
      : '${l10n?.invoicePdfVoided ?? 'ERRONEOUS — voided on'} '
          '${dateFormat.format(voidedAt)}';
  Future<pw.Font> font(String asset) async =>
      pw.Font.ttf(await rootBundle.load(asset));
  final reportData = invoiceReportData(
    context,
    invoice,
    proforma: proforma,
    copy: copy,
    workspace: workspace,
  );
  // #476: a proforma renders its OWN bands when the owner set them —
  // else the invoice's, as it always did.
  final bands = proforma
      ? (template.proformaBands ?? template.invoiceBands)
      : template.invoiceBands;
  final report = renderReportBands(bands: bands, data: reportData);
  final reportImages = <String, Uint8List>{};
  if (report != null && reportImage != null) {
    for (final name in reportImageRefs(report)) {
      final imageBytes = await reportImage(name);
      if (imageBytes != null) reportImages[name] = imageBytes;
    }
  }
  final bytes = await buildInvoicePdf(
    invoice: invoice,
    reportImages: reportImages,
    lineText: (line) => invoiceLineText(l10n, line),
    activityText: (entry) => annexEntryText(l10n, entry),
    strings: InvoicePdfStrings(
      invoiceTitle: l10n?.invoicePdfTitle ?? 'Invoice',
      issuedOn: l10n?.invoicePdfIssuedOn ?? 'Issued on',
      issuedBy: l10n?.invoicePdfIssuedBy ?? 'Issued by',
      billedTo: l10n?.invoicePdfBilledTo ?? 'Billed to',
      total: l10n?.invoiceBalance ?? 'Balance due',
      signature: l10n?.invoicePdfSignature ?? 'Digital signature (SHA-256)',
      voided: voidedLabel,
      // The archive row's own word for it — one term, everywhere.
      voidedWatermark: l10n?.invoiceVoidedChip ?? 'Erroneous',
      proforma: l10n?.invoicePdfProforma ?? 'Proforma',
      copy: l10n?.invoicePdfCopy ?? 'Copy',
      replaces: l10n?.invoicePdfReplaces ?? 'Replaces',
      description: l10n?.invoicePdfDescription ?? 'Description',
      charges: l10n?.invoicePdfCharges ?? 'Charges',
      payments: l10n?.invoicePdfPayments ?? 'Payments',
      net: l10n?.vatPdfNet ?? 'Net',
      vat: l10n?.vatPdfVat ?? 'VAT',
      annex: l10n?.invoicePdfAnnex ?? 'Annex — details',
      attendance: l10n?.invoicePdfAttendance ?? 'Check-ins',
      activity: l10n?.invoicePdfActivity ?? 'Bookings & payments',
      reserved: l10n?.invoicePdfReserved ?? 'reserved',
      page: l10n?.invoicePdfPage ?? 'Page',
    ),
    money: (cents) => currency.format(cents / 100),
    dateLabel: dateLabel,
    // The stored title is the raw period ('2026-07'); the document reads
    // the month like a human would.
    periodLabel: periodLabel,
    proforma: proforma,
    copy: copy,
    facturXml: facturXml,
    colorProfile: colorProfile,
    report: report,
    baseFont: await font('assets/fonts/Roboto-Regular.ttf'),
    boldFont: await font('assets/fonts/Roboto-Bold.ttf'),
  );
  // A proforma is named after what it covers — it has no number to be
  // filed under, and must never sit in a folder looking like the invoice.
  final stem = proforma
      ? safeFileSlug('${l10n?.invoicePdfProforma ?? 'proforma'} '
          '${invoice.number.isEmpty ? '${invoice.memberName} $periodLabel' : invoice.number}')
      : safeFileSlug(invoice.number);
  return (bytes: bytes, fileName: '$stem.pdf');
}

/// FACTUR-X: one PDF that carries the EN 16931 invoice inside it (as CII,
/// the syntax the format mandates). A human opens it and sees the invoice;
/// a platform opens it and finds `factur-x.xml`. This is what French and
/// German small businesses actually hand to their platform.
Future<({List<int> bytes, String fileName})> buildFacturXFile(
  BuildContext context,
  WidgetRef ref,
  Invoice invoice, {
  required InvoiceParty seller,
  required InvoiceParty buyer,
  required String iban,
}) async {
  final l10n = AppLocalizations.of(context);
  final xml = buildInvoiceCii(
    invoice: invoice,
    seller: seller,
    buyer: buyer,
    iban: iban,
    lineText: (line) => invoiceLineText(l10n, line),
  );
  // PDF/A-3 cannot exist without an embedded output intent.
  final icc = await rootBundle.load('assets/pdf/sRGB2014.icc');
  if (!context.mounted) {
    return (bytes: const <int>[], fileName: '');
  }
  final pdf = await buildInvoicePdfFile(
    context,
    invoice,
    copy: _rendersCopy(ref),
    facturXml: xml,
    colorProfile: icc.buffer.asUint8List(),
    template: invoicePdfTemplateFor(ref),
    workspace: ref.read(currentWorkspaceProvider).value,
    reportImage: (name) => ref.read(reportImageBytesProvider(name).future),
  );
  return (
    bytes: pdf.bytes,
    fileName: '${safeFileSlug('facturx ${invoice.number}')}.pdf',
  );
}

/// ACCOUNTING EXPORT (0074): one SAF-T file for a period — the OECD's own
/// XML for handing accounting data to an accountant. Saved to Downloads,
/// because that is where a file destined for someone else's software goes.
Future<void> exportAccountingFile(
  BuildContext context,
  WidgetRef ref,
  List<Invoice> invoices, {
  required String label,
}) async {
  final l10n = AppLocalizations.of(context);
  final workspace = ref.read(currentWorkspaceProvider).value;
  if (workspace == null) return;
  if (invoices.isEmpty) {
    AppSnack.info(
      context,
      l10n?.invoiceAccountingExportEmpty ??
          'Nothing to export for this period.',
    );
    return;
  }
  final matches = ref.read(invoiceMatchesProvider).value ?? const {};
  final company = sellerOf(invoices.last, workspace);
  // Two standards, and which one is wanted depends on who asks: an
  // accountant's software reads SAF-T, a French audit demands the FEC.
  final format = await showAccountingExportSheet(
    context,
    offerFec: workspace.countryCode.toUpperCase() == 'FR',
  );
  if (format == null || !context.mounted) return;

  if (format == AccountingExportFormat.fec) {
    // The file NAME is the SIREN — without it the export cannot even be
    // called what the arrêté requires.
    if (company.legalId.replaceAll(RegExp('[^0-9]'), '').isEmpty) {
      AppSnack.error(
        context,
        l10n?.fecMissingSiren ??
            'The FEC is named after your registration number — fill it in '
                'under Legal identity first.',
      );
      return;
    }
    // The owner's own VAT account (0072) if they set one — the dialog is
    // where it can still be corrected.
    final accounts = await showFecAccountsDialog(
      context,
      initial: workspace.vatAccount.isEmpty
          ? const FecAccounts()
          : FecAccounts(vat: workspace.vatAccount),
    );
    if (accounts == null || !context.mounted) return;
    await runGuarded(
      context,
      domain: 'money',
      message: 'FEC export failed',
      errorText: l10n?.workspaceGenericError ??
          'Something went wrong. Please try again.',
      action: () async {
        final fec = buildFecFile(
          invoices: invoices,
          matches: matches,
          company: company,
          accounts: accounts,
          lineText: (line) => invoiceLineText(l10n, line),
          customersLabel: l10n?.fecAccountCustomers ?? 'Clients',
          revenueLabel: l10n?.fecAccountRevenue ?? 'Ventes',
          bankLabel: l10n?.fecAccountBank ?? 'Banque',
          vatLabel: l10n?.fecAccountVat ?? 'TVA collectée',
        );
        // The fiscal year closes on 31 December of the latest invoiced
        // year — the only close date the app can know.
        final year = invoices
            .map((invoice) => invoice.issuedAt.year)
            .reduce((a, b) => a > b ? a : b);
        final bytes = Uint8List.fromList(utf8.encode(fec));
        if (!context.mounted) return;
        await savePdfToDownloads(
          context,
          ref,
          bytes: bytes,
          fileName: fecFileName(company.legalId, DateTime(year, 12, 31)),
        );
      },
    );
    return;
  }

  await runGuarded(
    context,
    domain: 'money',
    message: 'accounting export failed',
    errorText: l10n?.workspaceGenericError ??
        'Something went wrong. Please try again.',
    action: () async {
      final xml = buildSafTFile(
        invoices: invoices,
        matches: matches,
        company: company,
        currency: workspace.currencyCode,
        softwareVersion: safTSoftwareVersion,
        createdAt: ref.read(clockProvider).now(),
        lineText: (line) => invoiceLineText(l10n, line),
        fallbackDescription: l10n?.invoicesTitle ?? 'Invoice',
      );
      final bytes = Uint8List.fromList(utf8.encode(xml));
      if (!context.mounted) return;
      await savePdfToDownloads(
        context,
        ref,
        bytes: bytes,
        fileName: '${safeFileSlug('saf-t ${workspace.name} $label')}.xml',
      );
    },
  );
}

/// SENDS the invoice: builds the Factur-X document and posts it to the
/// workspace's platform through the edge function, which holds the
/// credential and records the attempt (0073). The document that leaves is
/// byte-for-byte the one the download produces — one builder, no second
/// truth.
Future<void> sendEInvoice(
  BuildContext context,
  WidgetRef ref,
  Invoice invoice, {
  required InvoiceParty seller,
  required InvoiceParty buyer,
  required String iban,
  required String workspaceId,
  String environment = 'prod',
}) async {
  final l10n = AppLocalizations.of(context);
  EInvoiceSubmission? result;
  if (!await runGuarded(
    context,
    domain: 'money',
    message: 'e-invoice submission failed',
    errorText: l10n?.workspaceGenericError ??
        'Something went wrong. Please try again.',
    action: () async {
      final file = await buildFacturXFile(
        context,
        ref,
        invoice,
        seller: seller,
        buyer: buyer,
        iban: iban,
      );
      if (file.fileName.isEmpty) return;
      result = await ref.read(moneyRepositoryProvider).sendEInvoice(
            workspaceId: workspaceId,
            invoiceId: invoice.id,
            fileName: file.fileName,
            mimeType: 'application/pdf',
            bytes: file.bytes,
            environment: environment,
          );
    },
  )) {
    return;
  }
  ref.invalidate(invoiceTransmissionsProvider);
  if (!context.mounted) return;
  final submission = result;
  if (submission == null) return;
  if (submission.accepted) {
    AppSnack.success(
      context,
      environment == 'prod'
          ? (l10n?.invoiceSendAccepted ?? 'Sent — the platform accepted it.')
          : (l10n?.invoiceSendAcceptedTest(environment.toUpperCase()) ??
              'Test send accepted (${environment.toUpperCase()}).'),
    );
    return;
  }
  // The platform's own words beat a generic failure: they are what the
  // owner has to act on.
  AppSnack.error(
    context,
    submission.detail.isEmpty
        ? (l10n?.invoiceSendRejected ?? 'The platform refused it.')
        : '${l10n?.invoiceSendRejected ?? 'The platform refused it.'} '
            '${submission.detail}',
  );
}

/// Renders the month as a PROFORMA and hands it to the share sheet — the
/// quote an issuer sends before invoicing, and the payment request they
/// can re-send afterwards. Nothing is issued, nothing is booked.
Future<void> shareProforma(
  BuildContext context,
  WidgetRef ref,
  Invoice invoice,
) async {
  final l10n = AppLocalizations.of(context);
  if (!invoice.lines.any((line) => line.amountCents > 0)) {
    AppSnack.info(
      context,
      l10n?.invoiceProformaNothing ??
          'Nothing tracked for this month — no proforma to send.',
    );
    return;
  }
  if (!await runGuarded(
    context,
    domain: 'money',
    message: 'proforma share failed',
    errorText: l10n?.workspaceGenericError ??
        'Something went wrong. Please try again.',
    action: () async {
      final pdf = await buildInvoicePdfFile(context, invoice,
          proforma: true,
          template: invoicePdfTemplateFor(ref),
          workspace: ref.read(currentWorkspaceProvider).value,
          reportImage: (name) =>
              ref.read(reportImageBytesProvider(name).future));
      await ref.read(fileSharerProvider)(
        bytes: Uint8List.fromList(pdf.bytes),
        fileName: pdf.fileName,
        mimeType: 'application/pdf',
      );
    },
  )) {
    return;
  }
  if (!context.mounted) return;
  AppSnack.success(
    context,
    l10n?.invoiceProformaShared ?? 'Proforma shared.',
  );
}

/// Builds the proforma of a month that has NOT been invoiced yet: the
/// server's own derivation (the same RPC the issue sheet previews) dressed
/// in the live workspace and member identity. Returns null when the month
/// tracked nothing.
Future<Invoice?> proformaForMonth(
  WidgetRef ref, {
  required String memberId,
  required String period,
}) async {
  final workspace = ref.read(currentWorkspaceProvider).value;
  if (workspace == null) return null;
  final preview = await ref.read(moneyRepositoryProvider).previewInvoice(
        workspaceId: workspace.id,
        memberId: memberId,
        period: period,
      );
  if (preview.lines.isEmpty) return null;
  final names = await ref.read(memberNamesProvider.future);
  final members = await ref.read(workspaceMembersProvider.future);
  final userId = members
      .where((m) => m.id == memberId)
      .map((m) => m.userId)
      .firstOrNull;
  final profiles = await ref.read(memberProfilesProvider.future);
  return Invoice(
    // No id and no number: nothing was issued.
    id: '',
    workspaceId: workspace.id,
    memberId: memberId,
    number: '',
    issuedAt: ref.read(clockProvider).now(),
    period: period,
    title: period,
    lines: preview.lines,
    totalCents: preview.totalCents,
    currency: workspace.currencyCode,
    memberName: names[memberId] ?? '',
    memberAddress: userId == null ? '' : profiles[userId]?.address ?? '',
    workspaceName: workspace.name,
    workspaceAddress: workspace.address,
    issuerName: '',
    signature: '',
  );
}

/// Whether THIS viewer renders a copy: only an issuer (owner, or an admin
/// with the delegation) holds the original. A member downloading their own
/// invoice gets a document stamped as the duplicate it is.
bool _rendersCopy(WidgetRef ref) {
  final me = ref.read(myMemberProvider).value;
  if (me == null) return true;
  return !(me.actsAsOwner || me.canAdminister);
}

/// Saves [bytes] to Downloads and reports where they landed.
/// Saves [bytes] into the device Downloads and reports the path — the
/// shared "download, don't just share" path (#474).
Future<void> savePdfToDownloads(
  BuildContext context,
  WidgetRef ref, {
  required Uint8List bytes,
  required String fileName,
}) async {
  final l10n = AppLocalizations.of(context);
  final path = await ref.read(fileSaverProvider)(
    bytes: bytes,
    fileName: fileName,
  );
  if (!context.mounted) return;
  if (path == null) {
    AppSnack.error(context, l10n?.commonSaveFailed ?? 'Could not save.');
  } else {
    AppSnack.success(context, l10n?.commonSavedTo(path) ?? 'Saved to $path');
  }
}

Future<void> downloadInvoicePdf(
  BuildContext context,
  WidgetRef ref,
  Invoice invoice,
) async {
  final l10n = AppLocalizations.of(context);
  await runGuarded(
    context,
    domain: 'money',
    message: 'invoice download failed',
    errorText: l10n?.workspaceGenericError ??
        'Something went wrong. Please try again.',
    action: () async {
      final pdf = await buildInvoicePdfFile(
        context,
        invoice,
        copy: _rendersCopy(ref),
        template: invoicePdfTemplateFor(ref),
        workspace: ref.read(currentWorkspaceProvider).value,
    reportImage: (name) => ref.read(reportImageBytesProvider(name).future),
      );
      if (!context.mounted) return;
      await savePdfToDownloads(
        context,
        ref,
        bytes: Uint8List.fromList(pdf.bytes),
        fileName: pdf.fileName,
      );
    },
  );
}

Future<void> shareInvoicePdf(
  BuildContext context,
  WidgetRef ref,
  Invoice invoice,
) async {
  final l10n = AppLocalizations.of(context);
  await runGuarded(
    context,
    domain: 'money',
    message: 'invoice share failed',
    errorText: l10n?.workspaceGenericError ??
        'Something went wrong. Please try again.',
    action: () async {
      final pdf = await buildInvoicePdfFile(
        context,
        invoice,
        copy: _rendersCopy(ref),
        template: invoicePdfTemplateFor(ref),
        workspace: ref.read(currentWorkspaceProvider).value,
    reportImage: (name) => ref.read(reportImageBytesProvider(name).future),
      );
      await ref.read(fileSharerProvider)(
        bytes: Uint8List.fromList(pdf.bytes),
        fileName: pdf.fileName,
        mimeType: 'application/pdf',
      );
    },
  );
}

/// Tags [invoice] erroneous (0061) after an explicit confirm — the stamp is
/// one-way, so the dialog says so.
Future<void> voidInvoiceWithConfirm(
  BuildContext context,
  WidgetRef ref,
  Invoice invoice,
) async {
  final l10n = AppLocalizations.of(context);
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(l10n?.invoiceVoidAction ?? 'Mark erroneous'),
      content: Text(
        l10n?.invoiceVoidConfirm(invoice.number) ??
            'Mark invoice ${invoice.number} as erroneous? '
                'This cannot be undone.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(l10n?.commonCancel ?? 'Cancel'),
        ),
        FilledButton(
          key: const ValueKey('invoice-void-confirm'),
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(l10n?.invoiceVoidAction ?? 'Mark erroneous'),
        ),
      ],
    ),
  );
  if (confirmed != true || !context.mounted) return;
  if (!await runGuarded(
    context,
    domain: 'money',
    message: 'invoice void failed',
    errorText: l10n?.workspaceGenericError ??
        'Something went wrong. Please try again.',
    action: () => ref.read(moneyRepositoryProvider).voidInvoice(invoice.id),
  )) {
    return;
  }
  ref.invalidate(invoicesProvider);
  if (!context.mounted) return;
  AppSnack.success(
    context,
    l10n?.invoiceVoided ?? 'Invoice marked as erroneous.',
  );
}

/// Records a payment reminder (0066) and hands the invoice PDF to the share
/// sheet with a localized reminder message — mail, WhatsApp, whatever the
/// device offers.
/// Renders the reminder LETTER for [invoice] at [level] (#472): the
/// owner's band set for that level, else the shipped localized default.
/// A broken custom band set falls back to the default — a reminder must
/// never fail on a template.
Future<({List<int> bytes, String fileName, String title})>
    buildReminderPdfFile(
  BuildContext context,
  WidgetRef ref,
  Invoice invoice, {
  required int level,
  ReportBands? draftBands,
}) async {
  final l10n = AppLocalizations.of(context);
  final title = level <= 1
      ? (l10n?.reminderPdfTitleFriendly ?? 'Payment reminder')
      : '${l10n?.reminderPdfTitleFirm ?? 'Reminder'} $level';
  final data = reminderReportData(context, ref, invoice, level: level);
  final bands = draftBands ??
      invoicePdfTemplateFor(ref).reminderBands(level);
  final fallback = defaultReminderBands(level, l10n);
  final report = (bands == null
          ? null
          : renderReportBands(bands: bands, data: data)) ??
      renderReportBands(bands: fallback, data: data)!;
  final pageLabel = l10n?.invoicePdfPage ?? 'Page';
  Future<pw.Font> font(String asset) async =>
      pw.Font.ttf(await rootBundle.load(asset));
  final bytes = await buildBandedLetterPdf(
    report: report,
    reportImages: await resolveReportImages(ref, report),
    pageLabel: pageLabel,
    documentTitle: '$title ${invoice.number}',
    baseFont: await font('assets/fonts/Roboto-Regular.ttf'),
    boldFont: await font('assets/fonts/Roboto-Bold.ttf'),
  );
  return (
    bytes: bytes,
    fileName: '${safeFileSlug('$title ${invoice.number}')}.pdf',
    title: title,
  );
}

Future<void> remindInvoice(
  BuildContext context,
  WidgetRef ref,
  Invoice invoice,
) async {
  final l10n = AppLocalizations.of(context);
  final currency = NumberFormat.simpleCurrency(name: invoice.currency);
  final message = l10n?.invoiceReminderMessage(
        invoice.number,
        currency.format(invoice.totalCents / 100),
      ) ??
      'Friendly reminder: invoice ${invoice.number} — balance due '
          '${currency.format(invoice.totalCents / 100)}.';
  // #472: the level of THIS send — one past what was already sent,
  // capped at the configured maximum (extra sends reuse the last
  // letter).
  final rules =
      ref.read(dunningRulesProvider).value ?? DunningRules.defaults;
  final sent =
      ref.read(invoiceRemindersProvider).value?[invoice.id]?.count ?? 0;
  final level = (sent + 1).clamp(1, rules.levels);
  if (!await runGuarded(
    context,
    domain: 'money',
    message: 'invoice reminder failed',
    errorText: l10n?.workspaceGenericError ??
        'Something went wrong. Please try again.',
    action: () async {
      // PDF first — it captures its context-derived values before any
      // await (use_build_context_synchronously).
      final pdf = await buildReminderPdfFile(context, ref, invoice,
          level: level);
      await ref.read(moneyRepositoryProvider).remindInvoice(invoice.id);
      await ref.read(fileSharerProvider)(
        bytes: Uint8List.fromList(pdf.bytes),
        fileName: pdf.fileName,
        mimeType: 'application/pdf',
        text: message,
      );
    },
  )) {
    return;
  }
  ref.invalidate(invoiceRemindersProvider);
  if (!context.mounted) return;
  AppSnack.success(context, l10n?.invoiceReminded ?? 'Reminder recorded.');
}

/// EN 16931 e-invoice (0066/0069): the sheet first — WHERE the file has to
/// go in this country, and whether it would be ACCEPTED at all — then the
/// UBL 2.1 XML to Downloads or the share sheet.
Future<void> exportEInvoice(
  BuildContext context,
  WidgetRef ref,
  Invoice invoice, {
  required String countryCode,
}) async {
  final route = eInvoiceRouteFor(countryCode);
  final workspace = ref.read(currentWorkspaceProvider).value;
  if (route == null || workspace == null) return;
  // The invoice's own snapshot, or the live workspace identity for
  // pre-0069 documents (see sellerOf).
  final seller = sellerOf(invoice, workspace);
  final buyer = buyerOf(invoice, workspace);
  final readiness = checkEInvoiceReadiness(
    invoice: invoice,
    seller: seller,
    buyer: buyer,
  );
  // The same judgement against the LIVE identity: if that one passes, the
  // owner is not missing anything — the document is simply older than the
  // identity, and only a replacement can carry the new one.
  final identityFixedSince = invoice.sellerParty != null &&
      !readiness.ready &&
      checkEInvoiceReadiness(
        invoice: invoice,
        seller: workspaceParty(workspace),
        buyer: buyer,
      ).ready;
  final me = ref.read(myMemberProvider).value;
  // AWAIT the probe: a cached `.value` is null on the first open, which
  // would hide the Send button exactly when it is most wanted.
  EInvoiceGatewayConfig gateway;
  try {
    gateway = await ref.read(eInvoiceGatewayProvider.future);
  } catch (e, st) {
    TraceLogger.instance.warn('money', 'e-invoice gateway probe failed',
        error: e, stackTrace: st);
    gateway = EInvoiceGatewayConfig.notConfigured;
  }
  if (!context.mounted) return;
  final export = await showEInvoiceSheet(
    context,
    route: route,
    readiness: readiness,
    canFixIdentity: me?.actsAsOwner ?? false,
    identityFixedSince: identityFixedSince,
    // Only an issuer sends, and only when a platform is configured.
    canSend: gateway.configured &&
        (me?.actsAsOwner == true || me?.canAdminister == true),
  );
  if (export == null || !context.mounted) return;
  if (export == EInvoiceExport.fixIdentity) {
    context.push('/legal-identity');
    return;
  }
  final l10nForFile = AppLocalizations.of(context);
  if (export == EInvoiceExport.send) {
    // Dev mode + a configured test platform → choose the target (#393);
    // anyone else goes straight to production, no extra tap.
    final environment =
        await pickEInvoiceEnvironment(context, ref, gateway: gateway);
    if (environment == null || !context.mounted) return;
    await sendEInvoice(
      context,
      ref,
      invoice,
      seller: seller,
      buyer: buyer,
      iban: workspaceIban(workspace),
      workspaceId: workspace.id,
      environment: environment,
    );
    return;
  }
  if (export == EInvoiceExport.facturXDownload ||
      export == EInvoiceExport.facturXShare) {
    await runGuarded(
      context,
      domain: 'money',
      message: 'factur-x export failed',
      errorText: l10nForFile?.workspaceGenericError ??
          'Something went wrong. Please try again.',
      action: () async {
        final file = await buildFacturXFile(
          context,
          ref,
          invoice,
          seller: seller,
          buyer: buyer,
          iban: workspaceIban(workspace),
        );
        if (file.fileName.isEmpty) return;
        final bytes = Uint8List.fromList(file.bytes);
        if (export == EInvoiceExport.facturXShare) {
          await ref.read(fileSharerProvider)(
            bytes: bytes,
            fileName: file.fileName,
            mimeType: 'application/pdf',
          );
          return;
        }
        if (!context.mounted) return;
        await savePdfToDownloads(context, ref, bytes: bytes, fileName: file.fileName);
      },
    );
    return;
  }
  final l10n = AppLocalizations.of(context);
  await runGuarded(
    context,
    domain: 'money',
    message: 'e-invoice export failed',
    errorText: l10n?.workspaceGenericError ??
        'Something went wrong. Please try again.',
    action: () async {
      final xml = buildInvoiceUbl(
        invoice: invoice,
        seller: seller,
        buyer: buyer,
        iban: workspaceIban(workspace),
        lineText: (line) => invoiceLineText(l10n, line),
      );
      final bytes = Uint8List.fromList(utf8.encode(xml));
      final fileName = '${safeFileSlug(invoice.number)}.xml';
      if (export == EInvoiceExport.share) {
        await ref.read(fileSharerProvider)(
          bytes: bytes,
          fileName: fileName,
          mimeType: 'application/xml',
        );
        return;
      }
      if (!context.mounted) return;
      await savePdfToDownloads(context, ref, bytes: bytes, fileName: fileName);
    },
  );
}

/// Matches an open invoice to its payment (0067) — the only way an invoice
/// closes and archives. Over/under payments resolve in the dialog; the
/// server re-validates and files the invoice_payment event (pending when a
/// validation rule exists).
Future<void> matchInvoiceToPayment(
  BuildContext context,
  WidgetRef ref,
  Invoice invoice,
) async {
  final l10n = AppLocalizations.of(context);
  final currency = NumberFormat.simpleCurrency(name: invoice.currency);
  // 0068 — the candidates: the member's registered payments (incl. settled
  // online payments) not yet consumed by another match.
  final repo = ref.read(moneyRepositoryProvider);
  final ledger = await repo.fetchLedger(invoice.memberId);
  final matches = ref.read(invoiceMatchesProvider).value ?? const {};
  final consumed = {
    for (final match in matches.values) ?match.paymentLedgerId,
  };
  final payments = [
    for (final entry in ledger)
      if (entry.kind == LedgerKind.credit &&
          entry.category == LedgerCategory.payment &&
          !consumed.contains(entry.id))
        entry,
    // Newest PAYMENT first — by the day the money moved (0070), not by
    // the day it happened to be typed in.
  ]..sort((a, b) => b.on.compareTo(a.on));
  if (!context.mounted) return;
  final choice = await showDialog<MatchChoice>(
    context: context,
    builder: (context) => MatchInvoiceDialog(
      dueCents: invoice.totalCents,
      currency: currency,
      payments: payments,
    ),
  );
  if (choice == null || !context.mounted) return;
  if (!await runGuarded(
    context,
    domain: 'money',
    message: 'invoice match failed',
    errorText: l10n?.workspaceGenericError ??
        'Something went wrong. Please try again.',
    action: () => ref.read(moneyRepositoryProvider).matchInvoice(
          invoiceId: invoice.id,
          paymentLedgerId: choice.paymentLedgerId,
          resolution: choice.resolution,
          note: choice.note,
        ),
  )) {
    return;
  }
  ref.invalidate(invoiceMatchesProvider);
  ref.invalidate(invoicesProvider);
  invalidateBookingData(ref);
  if (!context.mounted) return;
  AppSnack.success(context, l10n?.invoiceMatched ?? 'Invoice matched.');
}

/// One tap invoices every listed member for [period] — behind a confirm
/// naming what is about to become N immutable documents. Per-member
/// guarded, so one failing statement neither stops the sweep nor hides
/// itself: the snack reports what did NOT go through.
Future<void> issueInvoicesForAll(
  BuildContext context,
  WidgetRef ref,
  List<ToInvoiceEntry> entries,
  String period,
  NumberFormat currency,
) async {
  final l10n = AppLocalizations.of(context);
  final workspace = ref.read(currentWorkspaceProvider).value;
  if (workspace == null || entries.isEmpty) return;
  final total = entries.fold(0, (sum, e) => sum + e.totalCents);
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(l10n?.invoiceIssueAll ?? 'Invoice all'),
      content: Text(
        l10n?.invoiceIssueAllConfirm(
              entries.length,
              monthLabel(context, period),
              currency.format(total / 100),
            ) ??
            'Issue ${entries.length} invoices for '
                '${monthLabel(context, period)}, '
                '${currency.format(total / 100)} in total? An issued '
                'invoice can no longer be edited.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(l10n?.commonCancel ?? 'Cancel'),
        ),
        FilledButton(
          key: const ValueKey('invoice-issue-all-confirm'),
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(l10n?.invoiceIssueAll ?? 'Invoice all'),
        ),
      ],
    ),
  );
  if (confirmed != true || !context.mounted) return;

  var issued = 0;
  for (final entry in entries) {
    try {
      await ref.read(moneyRepositoryProvider).createInvoice(
            workspaceId: workspace.id,
            memberId: entry.memberId,
            period: period,
          );
      issued++;
    } catch (e, st) {
      TraceLogger.instance.error('money', 'invoice sweep entry failed',
          error: e, stackTrace: st);
    }
  }
  ref.invalidate(invoicesProvider);
  if (!context.mounted) return;
  final failed = entries.length - issued;
  if (failed > 0) {
    AppSnack.error(
      context,
      l10n?.invoiceIssuedPartial(issued, failed) ??
          '$issued issued, $failed failed.',
    );
    return;
  }
  AppSnack.success(
    context,
    l10n?.invoiceIssuedCount(issued) ?? '$issued invoices issued.',
  );
}

/// Runs what the detail sheet decided on, with the SCREEN's context — the
/// sheet is already gone by then.
Future<void> runInvoiceAction(
  BuildContext context,
  WidgetRef ref,
  InvoiceAction action,
  Invoice invoice, {
  required String countryCode,
}) =>
    switch (action) {
      InvoiceAction.downloadPdf => downloadInvoicePdf(context, ref, invoice),
      InvoiceAction.sharePdf => shareInvoicePdf(context, ref, invoice),
      InvoiceAction.eInvoice =>
        exportEInvoice(context, ref, invoice, countryCode: countryCode),
      InvoiceAction.remind => remindInvoice(context, ref, invoice),
      InvoiceAction.markPaid => matchInvoiceToPayment(context, ref, invoice),
      InvoiceAction.markErroneous =>
        voidInvoiceWithConfirm(context, ref, invoice),
      InvoiceAction.replace =>
        showInvoiceIssueSheet(context, ref, replaces: invoice),
    };
