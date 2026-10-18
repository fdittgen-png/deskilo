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
import '../../../../core/ui/form_kit.dart';
import '../../../../core/vat/tax_reference.dart';
import '../../../../l10n/app_localizations.dart';
import '../../application/tax_reference_commands.dart';
import '../../domain/einvoice_mandates.dart';
import '../../domain/vat_rate.dart';
import 'tax_reference_component_fields.dart';
import 'tax_reference_labels.dart';
import 'tax_reference_sales_fields.dart';

export 'tax_reference_labels.dart';

/// The state of one version form: its text fields and its three choices.
class _VersionForm {
  _VersionForm(this.domain, this.from, String today)
      : fields = FormControllers({
          'country': from?.country ?? '',
          'key': from?.key ?? '',
          'valid_from': today,
          'source': from?.source ?? '',
          'label': switch (from?.value) {
            RateValue(:final label) => label,
            FormBoxValue(:final label) => label,
            AccountMapValue(:final label) => label,
            _ => '',
          },
          'role': switch (from?.value) {
            AccountMapValue(:final role) => role,
            _ => '',
          },
          'account': switch (from?.value) {
            AccountMapValue(:final account) => account,
            _ => '',
          },
          'state': from?.value is SalesTaxValue
              ? (from!.value as SalesTaxValue).state
              : '',
          'components': switch (from?.value) {
            SalesTaxValue v => salesTaxComponentsText(v),
            RateComponentValue v => rateComponentsText(v),
            _ => '',
          },
          'tax_code': switch (from?.value) {
            AccountMapValue(:final taxCode) => taxCode,
            _ => '',
          },
          'groups': switch (from?.value) {
            FormBoxValue(:final groups) => groups.join(', '),
            _ => '',
          },
          'exclude_groups': switch (from?.value) {
            FormBoxValue(:final excludeGroups) => excludeGroups.join(', '),
            _ => '',
          },
          'percent': switch (from?.value) {
            RateValue(:final percent) => percentText(percent),
            RateComponentValue(:final percent) => percentText(percent),
            _ => '',
          },
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
          'years': from?.value is RetentionValue ? '${(from!.value as RetentionValue).years}' : '',
          'cents': switch (from?.value) {
            ThresholdValue(:final cents) => '$cents',
            _ => '',
          },
          'currency': switch (from?.value) {
            ThresholdValue(:final currency) => currency,
            IssuingGateValue(:final currency) => currency,
            _ => '',
          },
          'from': switch (from?.value) {
            MandateValue(:final from) => from,
            _ => '',
          },
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
        choice = _choicesOf(from?.value),
        flag = _flagsOf(from?.value),
        confirmed = from?.confirmed ?? false;

  final TaxDomain domain;
  final TaxReferenceRow? from;
  final FormControllers fields;
  String group;
  String category;
  bool confirmed;

  /// The closed-list choices (threshold effect, tax point rule, backstop,
  /// mandate duty) and the yes/no switches of the typed forms.
  final Map<String, String> choice;
  final Map<String, bool> flag;

  static Map<String, String> _choicesOf(TaxValue? v) => {
        'effect': v is ThresholdValue ? v.effect : 'next_year',
        'standard': v is TaxPointValue ? v.standard : 'invoice',
        'cash_backstop': v is TaxPointValue ? v.cashBackstop : 'none',
        'start': v is RetentionValue ? v.from : 'fiscal_year_end',
        'duty': v is MandateValue ? v.duty : MandateDuty.receiveAll.wire,
        'format': v is AccountMapValue ? v.format : 'coa',
        'status': v is TaxabilityValue ? v.status : taxabilityStatuses.first,
        'tax_system': v is IssuingGateValue ? v.taxSystem : 'vat',
      };

  static Map<String, bool> _flagsOf(TaxValue? v) => {
        'invoice_option': v is TaxPointValue && v.invoiceOption,
        'cash_option': v is! TaxPointValue || v.cashOption,
        'supported': v is IssuingGateValue && v.supported,
        'requires_tax_number': v is IssuingGateValue && v.requiresTaxNumber,
        'national_channel_required':
            v is IssuingGateValue && v.nationalChannelRequired,
      };

  List<String> _groupList(String k) => [
        for (final g in fields.text(k).split(','))
          if (g.trim().isNotEmpty) g.trim(),
      ];

  /// Whether the lists of a return box name known groups, at least one, and
  /// none twice over (a group cannot be both taken and excluded).
  bool get groupListsValid {
    final known = VatGroup.values.map((g) => g.wire).toSet();
    final taken = _groupList('groups');
    final left = _groupList('exclude_groups');
    return (taken.isNotEmpty || left.isNotEmpty) &&
        [...taken, ...left].every(known.contains) &&
        !taken.any(left.contains);
  }

  double? get percent => double.tryParse(fields.text('percent').replaceAll(',', '.'));

  /// The two values that begin on a day: a duty, a retention clock.
  TaxValue _datedValue() => domain == TaxDomain.mandate
      ? MandateValue(duty: choice['duty']!, from: fields.text('from'))
      : RetentionValue(
          years: int.tryParse(fields.text('years')) ?? 0,
          from: choice['start']!,
        );

  TaxValue value() => switch (domain) {
        TaxDomain.rate => RateValue(
            label: fields.text('label'),
            percent: percent ?? 0,
            group: group,
            category: category,
            exemptionReason: fields.text('reason'),
            position: int.tryParse(fields.text('position')) ?? 0,
          ),
        TaxDomain.threshold => ThresholdValue(
            cents: int.tryParse(fields.text('cents')) ?? 0,
            effect: choice['effect']!,
            currency: fields.text('currency').toUpperCase(),
          ),
        TaxDomain.taxPoint => TaxPointValue(
            standard: choice['standard']!,
            invoiceOption: flag['invoice_option']!,
            cashOption: flag['cash_option']!,
            cashBackstop: choice['cash_backstop']!,
          ),
        TaxDomain.mandate || TaxDomain.retention => _datedValue(),
        TaxDomain.issuingGate => IssuingGateValue(
            supported: flag['supported']!,
            requiresTaxNumber: flag['requires_tax_number']!,
            nationalChannelRequired: flag['national_channel_required']!,
            currency: fields.text('currency').toUpperCase(),
            taxSystem: choice['tax_system']!,
          ),
        TaxDomain.salesTax => SalesTaxValue(
            state: fields.text('state').toUpperCase(),
            components: parseSalesTaxComponents(fields.text('components')) ?? const [],
          ),
        TaxDomain.taxability => TaxabilityValue(status: choice['status']!),
        TaxDomain.rateComponent => RateComponentValue(
            percent: percent ?? 0,
            components: parseRateComponents(fields.text('components')) ?? const [],
          ),
        TaxDomain.formBox => FormBoxValue(
            label: fields.text('label'),
            groups: _groupList('groups'),
            excludeGroups: _groupList('exclude_groups'),
          ),
        TaxDomain.accountMap => AccountMapValue(
            format: choice['format']!,
            role: fields.text('role'),
            account: fields.text('account'),
            taxCode: fields.text('tax_code'),
            label: fields.text('label'),
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
    return {
      if (problems.contains(TaxVersionProblem.country)) 'country': l10n.taxRefCountry,
      if (problems.contains(TaxVersionProblem.key)) 'key': l10n.taxRefRequired,
      if (problems.contains(TaxVersionProblem.date)) 'valid_from': l10n.taxRefInvalidDate,
      if (problems.contains(TaxVersionProblem.source)) 'source': l10n.taxRefRequired,
      ..._keyedErrors(l10n),
      if (domain == TaxDomain.mention) ...{
        'regime': ?need('regime'),
        'text': ?need('text'),
      },
      if (domain == TaxDomain.vatIdPattern) 'pattern': ?need('pattern'),
      if (domain == TaxDomain.catalogueNote || domain == TaxDomain.groupExample)
        'note': ?need('note'),
      if (domain == TaxDomain.threshold) ...{
        if ((int.tryParse(fields.text('cents')) ?? 0) <= 0)
          'cents': l10n.taxRefInvalidNumber,
        if (fields.text('currency').length != 3) 'currency': l10n.taxRefRequired,
      },
      if (domain == TaxDomain.retention && (int.tryParse(fields.text('years')) ?? 0) < 1)
        'years': l10n.taxRefInvalidNumber,
      if (domain == TaxDomain.mandate &&
          !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(fields.text('from')))
        'from': l10n.taxRefInvalidDate,
    };
  }

  /// The refusals of the domains whose value carries a label or a key of its
  /// own (rates, return boxes, export accounts).
  FieldErrors _keyedErrors(AppLocalizations l10n) {
    String? need(String k) => fields.text(k).isEmpty ? l10n.taxRefRequired : null;
    final p = percent;
    return {
      if (domain == TaxDomain.rate) ...{
        'label': ?need('label'),
        if (p == null || p < 0 || p > 99.999) 'percent': l10n.taxRefInvalidNumber,
      },
      if (domain == TaxDomain.formBox) ...{
        'label': ?need('label'),
        if (!groupListsValid) 'groups': l10n.taxRefInvalidGroups,
      },
      if (domain == TaxDomain.salesTax) ...{
        if (!RegExp(r'^[A-Za-z]{2}$').hasMatch(fields.text('state')))
          'state': l10n.taxRefInvalidState,
        if (parseSalesTaxComponents(fields.text('components')) == null)
          'components': l10n.taxRefInvalidComponents,
      },
      if (domain == TaxDomain.rateComponent) ...{
        if (p == null || p <= 0 || p > 99.999) 'percent': l10n.taxRefInvalidNumber,
        if (!rateComponentsAddUp(parseRateComponents(fields.text('components')), p))
          'components': l10n.taxRefInvalidRateComponents,
      },
      if (domain == TaxDomain.accountMap) ...{
        'role': ?need('role'),
        if (fields.text('account').isEmpty && fields.text('tax_code').isEmpty)
          'account': l10n.taxRefInvalidAccount,
      },
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

  Widget _switch(String k, String label, VoidCallback refresh) => SwitchListTile(
        key: ValueKey('tax-ref-$k'),
        contentPadding: EdgeInsets.zero,
        title: Text(label),
        value: flag[k]!,
        onChanged: (x) {
          flag[k] = x;
          refresh();
        },
      );

  Widget _pick(String k, String label, Iterable<String> items) =>
      _choice(k, label, choice[k]!, items, (x) => choice[k] = x);

  List<Widget> _domainFields(AppLocalizations l10n, VoidCallback refresh) =>
      switch (domain) {
        TaxDomain.threshold => [
            _text('cents', l10n.taxRefCents, type: TextInputType.number),
            _pick('effect', l10n.taxRefEffect, const ['next_year', 'immediate']),
            _text('currency', l10n.taxRefCurrency),
          ],
        TaxDomain.taxPoint => [
            _pick('standard', l10n.taxRefStandardRule,
                const ['invoice', 'receipt', 'service_period', 'earlier_of']),
            _switch('invoice_option', l10n.taxRefInvoiceOption, refresh),
            _switch('cash_option', l10n.taxRefCashOption, refresh),
            _pick('cash_backstop', l10n.taxRefCashBackstop,
                const ['none', 'end_of_following_year', 'one_year_after_issue']),
          ],
        TaxDomain.retention => [
            _text('years', l10n.taxRefYears, type: TextInputType.number),
            _pick('start', l10n.taxRefRetentionStart, const ['fiscal_year_end', 'document_date']),
          ],
        TaxDomain.mandate => [
            _pick('duty', l10n.taxRefDuty, MandateDuty.values.map((d) => d.wire)),
            _text('from', l10n.taxRefFrom),
          ],
        TaxDomain.issuingGate => [
            _switch('supported', l10n.taxRefSupported, refresh),
            _switch('requires_tax_number', l10n.taxRefRequiresTaxNumber, refresh),
            _switch('national_channel_required', l10n.taxRefNationalChannel, refresh),
            _text('currency', l10n.taxRefCurrency),
            _pick('tax_system', l10n.taxRefTaxSystem, const ['vat', salesTaxSystem]),
          ],
        TaxDomain.salesTax => [
            _text('state', l10n.taxRefState),
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: salesTaxComponentsField(fields, l10n),
            ),
          ],
        TaxDomain.taxability => [
            _pick('status', l10n.taxRefStatus, taxabilityStatuses),
          ],
        TaxDomain.rateComponent => [
            _text('percent', l10n.taxRefPercent, type: TextInputType.number),
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: rateComponentsField(fields, l10n),
            ),
          ],
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
        TaxDomain.formBox => [
            _text('label', l10n.taxRefLabel),
            _text('groups', l10n.taxRefGroups),
            _text('exclude_groups', l10n.taxRefExcludeGroups),
          ],
        TaxDomain.accountMap => [
            _pick('format', l10n.taxRefFormat,
                const ['coa', 'fec', 'datev', 'sage', 'saf_t']),
            _text('role', l10n.taxRefRole),
            _text('account', l10n.taxRefAccount),
            _text('tax_code', l10n.taxRefTaxCode),
            _text('label', l10n.taxRefLabel),
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
        ..._domainFields(l10n, refresh),
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
