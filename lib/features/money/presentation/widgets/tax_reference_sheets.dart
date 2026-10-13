// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2477 -- the platform owner's two sheets over the tax reference store:
// a form that creates a NEW version of a value (never edits one) and the
// history of a value. One typed form per domain; the server validates the
// shape again.
import 'package:flutter/material.dart';

import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/text/number_text.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/trace/trace_logger.dart';
import '../../../../core/ui/app_sheet.dart';
import '../../../../core/ui/form_kit.dart';
import '../../../../core/ui/form_sheet.dart';
import '../../../../core/vat/tax_reference.dart';
import '../../application/tax_reference_commands.dart';
import '../../domain/vat_rate.dart';

/// A one-line reading of a value, for lists.
String taxValueSummary(TaxValue v) => switch (v) {
      RateValue() => '${v.label} (${percentText(v.percent)} %)',
      EuMemberValue() => '',
      ExemptionTextValue() => v.text,
      VatIdPatternValue() => v.pattern,
    };

String taxDomainLabel(BuildContext context, TaxDomain d) => switch (d) {
      TaxDomain.rate => context.l10n.taxRefDomainRate,
      TaxDomain.euMember => context.l10n.taxRefDomainEuMember,
      TaxDomain.mention => context.l10n.taxRefDomainExemptionText,
      TaxDomain.vatIdPattern => context.l10n.taxRefDomainVatIdPattern,
    };

/// Opens the form. [from] is the version being superseded (its fields
/// prefill and its country and key are fixed); without it a new value of
/// [domain] is added. Returns whether a version was saved.
Future<bool> showTaxReferenceVersionSheet(
  BuildContext context, {
  required TaxReferenceCommands commands,
  required String today,
  required VoidCallback onSaved,
  required TaxDomain domain,
  TaxReferenceRow? from,
}) {
  final l10n = context.l10n;
  final v = from?.value;
  final fields = FormControllers({
    'country': from?.country ?? '',
    'key': from?.key ?? '',
    'valid_from': today,
    'source': from?.source ?? '',
    'label': v is RateValue ? v.label : '',
    'percent': v is RateValue ? percentText(v.percent) : '',
    'reason': v is RateValue ? v.exemptionReason : '',
    'position': v is RateValue ? '${v.position}' : '0',
    'regime': v is ExemptionTextValue ? v.regime : '',
    'text': v is ExemptionTextValue ? v.text : '',
    'pattern': v is VatIdPatternValue ? v.pattern : '',
  });
  var group = v is RateValue ? v.group : VatGroup.standard.wire;
  var category = v is RateValue ? v.category : 'S';
  var confirmed = from?.confirmed ?? false;

  TaxValue value() => switch (domain) {
        TaxDomain.rate => RateValue(
            label: fields.text('label'),
            percent: double.parse(fields.text('percent').replaceAll(',', '.')),
            group: group,
            category: category,
            exemptionReason: fields.text('reason'),
            position: int.tryParse(fields.text('position')) ?? 0,
          ),
        TaxDomain.euMember => const EuMemberValue(),
        TaxDomain.mention => ExemptionTextValue(
            regime: fields.text('regime'), text: fields.text('text')),
        TaxDomain.vatIdPattern => VatIdPatternValue(pattern: fields.text('pattern')),
      };

  FieldErrors validate() {
    final problems = commands.validate(
      country: fields.text('country'),
      key: fields.text('key'),
      validFrom: fields.text('valid_from'),
      source: fields.text('source'),
    );
    final percent = double.tryParse(fields.text('percent').replaceAll(',', '.'));
    String need(String k) => fields.text(k).isEmpty ? l10n.taxRefRequired : '';
    return {
      if (problems.contains(TaxVersionProblem.country)) 'country': l10n.taxRefCountry,
      if (problems.contains(TaxVersionProblem.key)) 'key': l10n.taxRefRequired,
      if (problems.contains(TaxVersionProblem.date)) 'valid_from': l10n.taxRefInvalidDate,
      if (problems.contains(TaxVersionProblem.source)) 'source': l10n.taxRefRequired,
      if (domain == TaxDomain.rate) ...{
        if (need('label').isNotEmpty) 'label': need('label'),
        if (percent == null || percent < 0 || percent > 99.999)
          'percent': l10n.taxRefInvalidNumber,
      },
      if (domain == TaxDomain.mention) ...{
        if (need('regime').isNotEmpty) 'regime': need('regime'),
        if (need('text').isNotEmpty) 'text': need('text'),
      },
      if (domain == TaxDomain.vatIdPattern && need('pattern').isNotEmpty)
        'pattern': need('pattern'),
    };
  }

  Widget text(String k, String label, {bool enabled = true, TextInputType? type}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.md),
        child: AppTextField(
          key: ValueKey('tax-ref-$k'),
          controller: fields[k],
          fieldKey: k,
          label: label,
          enabled: enabled,
          keyboardType: type,
        ),
      );

  return showAppFormSheet(
    context,
    AppFormSheet(
      title: '${l10n.taxRefNewVersion} · ${taxDomainLabel(context, domain)}',
      submitLabel: l10n.taxRefSave,
      submitKey: const ValueKey('tax-reference-save'),
      onDispose: fields.dispose,
      validate: validate,
      onSubmit: () async {
        try {
          await commands.saveVersion(
            domain: domain,
            country: fields.text('country'),
            key: fields.text('key'),
            value: value(),
            source: fields.text('source'),
            confirmed: confirmed,
            validFrom: fields.text('valid_from'),
          );
          onSaved();
          return null;
        } on Object catch (e, st) {
          TraceLogger.instance.error('money', 'tax reference save failed',
              error: e, stackTrace: st);
          return l10n.taxRefCouldNotSave;
        }
      },
      builder: (context, refresh) => [
        text('country', l10n.taxRefCountry, enabled: from == null),
        text('key', l10n.taxRefKey, enabled: from == null),
        if (domain == TaxDomain.rate) ...[
          text('label', l10n.taxRefLabel),
          text('percent', l10n.taxRefPercent, type: TextInputType.number),
          DropdownButtonFormField<String>(
            key: const ValueKey('tax-ref-group'),
            initialValue: group,
            decoration: InputDecoration(labelText: l10n.taxRefGroup),
            items: [
              for (final g in VatGroup.values)
                DropdownMenuItem(value: g.wire, child: Text(g.wire)),
            ],
            onChanged: (x) => group = x ?? group,
          ),
          const FormGap(),
          DropdownButtonFormField<String>(
            key: const ValueKey('tax-ref-category'),
            initialValue: category,
            decoration: InputDecoration(labelText: l10n.taxRefCategory),
            items: [
              for (final c in const ['S', 'Z', 'E', 'O'])
                DropdownMenuItem(value: c, child: Text(c)),
            ],
            onChanged: (x) => category = x ?? category,
          ),
          const FormGap(),
          text('reason', l10n.taxRefExemptionReason),
          text('position', l10n.taxRefPosition, type: TextInputType.number),
        ],
        if (domain == TaxDomain.euMember) Text(l10n.taxRefMemberEmpty),
        if (domain == TaxDomain.mention) ...[
          text('regime', l10n.taxRefRegime),
          text('text', l10n.taxRefText),
        ],
        if (domain == TaxDomain.vatIdPattern) text('pattern', l10n.taxRefPattern),
        text('valid_from', l10n.taxRefValidFrom),
        text('source', l10n.taxRefSource),
        SwitchListTile(
          key: const ValueKey('tax-ref-confirmed'),
          contentPadding: EdgeInsets.zero,
          title: Text(l10n.taxRefConfirmed),
          value: confirmed,
          onChanged: (x) {
            confirmed = x;
            refresh();
          },
        ),
      ],
    ),
  );
}

/// Every version of one value, newest first.
Future<void> showTaxReferenceHistorySheet(
  BuildContext context, {
  required TaxReferenceSet set,
  required TaxReferenceRow row,
}) {
  final versions = set.history(row.domain, row.country, row.key);
  return showAppSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (context) {
      final l10n = context.l10n;
      return SheetShell(
        title: l10n.taxRefHistory,
        children: [
          Text('${row.country} · ${row.key}',
              style: Theme.of(context).textTheme.titleMedium),
          for (final v in versions)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(taxValueSummary(v.value).isEmpty
                  ? v.country
                  : taxValueSummary(v.value)),
              subtitle: Text('${l10n.taxRefValidFrom} ${v.validFrom}'
                  '${v.validTo == null ? '' : ' · ${l10n.taxRefValidUntil} ${v.validTo}'}'
                  ' · ${v.source}'),
              trailing: Text(v.confirmed ? l10n.taxRefConfirmed : l10n.taxRefUnconfirmed),
            ),
        ],
      );
    },
  );
}
