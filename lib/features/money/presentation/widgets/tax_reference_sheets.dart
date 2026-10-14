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
import '../../../../l10n/app_localizations.dart';
import '../../application/tax_reference_commands.dart';
import '../../domain/vat_rate.dart';

/// A one-line reading of a value, for lists.
String taxValueSummary(TaxValue v) => switch (v) {
      RateValue() => '${v.label} (${percentText(v.percent)} %)',
      EuMemberValue() => v.aliasOf,
      ExemptionTextValue() => v.text,
      VatIdPatternValue() => v.pattern,
      CatalogueNoteValue() => v.text,
      GroupExampleValue() => '${v.group}: ${v.text}',
    };

String taxDomainLabel(BuildContext context, TaxDomain d) => switch (d) {
      TaxDomain.rate => context.l10n.taxRefDomainRate,
      TaxDomain.euMember => context.l10n.taxRefDomainEuMember,
      TaxDomain.mention => context.l10n.taxRefDomainExemptionText,
      TaxDomain.vatIdPattern => context.l10n.taxRefDomainVatIdPattern,
      TaxDomain.catalogueNote => context.l10n.taxRefDomainCatalogueNote,
      TaxDomain.groupExample => context.l10n.taxRefDomainGroupExample,
    };

/// The state of one version form: its text fields and its three choices.
class _VersionForm {
  _VersionForm(this.domain, this.from, String today)
      : fields = FormControllers({
          'country': from?.country ?? '',
          'key': from?.key ?? '',
          'valid_from': today,
          'source': from?.source ?? '',
          'label': from?.value is RateValue ? (from!.value as RateValue).label : '',
          'percent': from?.value is RateValue
              ? percentText((from!.value as RateValue).percent)
              : '',
          'reason': from?.value is RateValue
              ? (from!.value as RateValue).exemptionReason
              : '',
          'position': switch (from?.value) {
            RateValue(:final position) => '$position',
            GroupExampleValue(:final position) => '$position',
            _ => '0',
          },
          'regime': from?.value is ExemptionTextValue
              ? (from!.value as ExemptionTextValue).regime
              : '',
          'text': from?.value is ExemptionTextValue
              ? (from!.value as ExemptionTextValue).text
              : '',
          'pattern': from?.value is VatIdPatternValue
              ? (from!.value as VatIdPatternValue).pattern
              : '',
          'alias_of': from?.value is EuMemberValue
              ? (from!.value as EuMemberValue).aliasOf
              : '',
          'note': switch (from?.value) {
            CatalogueNoteValue(:final text) => text,
            GroupExampleValue(:final text) => text,
            _ => '',
          },
        }),
        group = switch (from?.value) {
          RateValue(:final group) => group,
          GroupExampleValue(:final group) => group,
          _ => VatGroup.standard.wire,
        },
        category = from?.value is RateValue ? (from!.value as RateValue).category : 'S',
        confirmed = from?.confirmed ?? false;

  final TaxDomain domain;
  final TaxReferenceRow? from;
  final FormControllers fields;
  String group;
  String category;
  bool confirmed;

  double? get percent => double.tryParse(fields.text('percent').replaceAll(',', '.'));

  TaxValue value() => switch (domain) {
        TaxDomain.rate => RateValue(
            label: fields.text('label'),
            percent: percent ?? 0,
            group: group,
            category: category,
            exemptionReason: fields.text('reason'),
            position: int.tryParse(fields.text('position')) ?? 0,
          ),
        TaxDomain.euMember => EuMemberValue(aliasOf: fields.text('alias_of')),
        TaxDomain.mention => ExemptionTextValue(
            regime: fields.text('regime'), text: fields.text('text')),
        TaxDomain.vatIdPattern => VatIdPatternValue(pattern: fields.text('pattern')),
        TaxDomain.catalogueNote => CatalogueNoteValue(text: fields.text('note')),
        TaxDomain.groupExample => GroupExampleValue(
            group: group,
            text: fields.text('note'),
            position: int.tryParse(fields.text('position')) ?? 0,
          ),
      };

  TaxVersionDraft draft() => TaxVersionDraft(
        domain: domain,
        country: fields.text('country'),
        key: fields.text('key'),
        value: value(),
        source: fields.text('source'),
        confirmed: confirmed,
        validFrom: fields.text('valid_from'),
      );

  FieldErrors errors(AppLocalizations l10n, TaxReferenceCommands commands) {
    final problems = commands.validate(
      country: fields.text('country'),
      key: fields.text('key'),
      validFrom: fields.text('valid_from'),
      source: fields.text('source'),
    );
    String? need(String k) => fields.text(k).isEmpty ? l10n.taxRefRequired : null;
    final p = percent;
    return {
      if (problems.contains(TaxVersionProblem.country)) 'country': l10n.taxRefCountry,
      if (problems.contains(TaxVersionProblem.key)) 'key': l10n.taxRefRequired,
      if (problems.contains(TaxVersionProblem.date)) 'valid_from': l10n.taxRefInvalidDate,
      if (problems.contains(TaxVersionProblem.source)) 'source': l10n.taxRefRequired,
      if (domain == TaxDomain.rate) ...{
        'label': ?need('label'),
        if (p == null || p < 0 || p > 99.999) 'percent': l10n.taxRefInvalidNumber,
      },
      if (domain == TaxDomain.mention) ...{
        'regime': ?need('regime'),
        'text': ?need('text'),
      },
      if (domain == TaxDomain.vatIdPattern) 'pattern': ?need('pattern'),
      if (domain == TaxDomain.catalogueNote || domain == TaxDomain.groupExample)
        'note': ?need('note'),
    };
  }

  Widget _text(String k, String label, {bool enabled = true, TextInputType? type}) =>
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

  Widget _choice(String k, String label, String current, Iterable<String> items,
          ValueChanged<String> onChanged) =>
      Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.md),
        child: DropdownButtonFormField<String>(
          key: ValueKey('tax-ref-$k'),
          initialValue: current,
          decoration: InputDecoration(labelText: label),
          items: [for (final i in items) DropdownMenuItem(value: i, child: Text(i))],
          onChanged: (x) => onChanged(x ?? current),
        ),
      );

  List<Widget> _domainFields(AppLocalizations l10n) => switch (domain) {
        TaxDomain.rate => [
            _text('label', l10n.taxRefLabel),
            _text('percent', l10n.taxRefPercent, type: TextInputType.number),
            _choice('group', l10n.taxRefGroup, group,
                VatGroup.values.map((g) => g.wire), (x) => group = x),
            _choice('category', l10n.taxRefCategory, category,
                const ['S', 'Z', 'E', 'O'], (x) => category = x),
            _text('reason', l10n.taxRefExemptionReason),
            _text('position', l10n.taxRefPosition, type: TextInputType.number),
          ],
        TaxDomain.euMember => [
            Text(l10n.taxRefMemberEmpty),
            _text('alias_of', l10n.taxRefAliasOf),
          ],
        TaxDomain.mention => [
            _text('regime', l10n.taxRefRegime),
            _text('text', l10n.taxRefText),
          ],
        TaxDomain.vatIdPattern => [_text('pattern', l10n.taxRefPattern)],
        TaxDomain.catalogueNote => [_text('note', l10n.taxRefText)],
        TaxDomain.groupExample => [
            _choice('group', l10n.taxRefGroup, group,
                VatGroup.values.map((g) => g.wire), (x) => group = x),
            _text('note', l10n.taxRefText),
            _text('position', l10n.taxRefPosition, type: TextInputType.number),
          ],
      };

  List<Widget> build(AppLocalizations l10n, VoidCallback refresh) => [
        _text('country', l10n.taxRefCountry, enabled: from == null),
        _text('key', l10n.taxRefKey, enabled: from == null),
        ..._domainFields(l10n),
        _text('valid_from', l10n.taxRefValidFrom),
        _text('source', l10n.taxRefSource),
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
      ];
}

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
  final form = _VersionForm(domain, from, today);
  return showAppFormSheet(
    context,
    AppFormSheet(
      title: '${l10n.taxRefNewVersion} · ${taxDomainLabel(context, domain)}',
      submitLabel: l10n.taxRefSave,
      submitKey: const ValueKey('tax-reference-save'),
      onDispose: form.fields.dispose,
      validate: () => form.errors(l10n, commands),
      onSubmit: () async {
        try {
          await commands.saveVersion(form.draft());
          onSaved();
          return null;
        } on Object catch (e, st) {
          TraceLogger.instance.error('money', 'tax reference save failed',
              error: e, stackTrace: st);
          return l10n.taxRefCouldNotSave;
        }
      },
      builder: (context, refresh) => form.build(l10n, refresh),
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
