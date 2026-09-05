// SPDX-License-Identifier: 0BSD
//
// #886 — THE identity form. A person edits their own personal
// information here (Settings → Personal information); an admin edits a
// managed member's identity (#887) with the same widget, so both places
// ask for the same fields in the same words and the documents print
// one shape whoever typed it.
import 'package:flutter/material.dart';

import '../../../../core/country/country_catalog.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../workspace/presentation/country_names.dart';
import '../../domain/personal_info.dart';

/// Edits a [PersonalInfo]; [onSave] receives the normalized value.
/// Every field carries a `personal-info-<field>` key for tests.
class PersonalInfoForm extends StatefulWidget {
  const PersonalInfoForm({
    super.key,
    required this.initial,
    required this.onSave,
    this.workspaceCountry = '',
    this.saving = false,
    this.intro,
  });

  final PersonalInfo initial;
  final Future<void> Function(PersonalInfo info) onSave;

  /// Pre-selects the country when the person never chose one, and
  /// drives the postal-block preview (the country line only abroad).
  final String workspaceCountry;
  final bool saving;

  /// Replaces the "printed on YOUR documents" line — an admin editing a
  /// managed member (#887) is told whose data this is instead.
  final String? intro;

  @override
  State<PersonalInfoForm> createState() => _PersonalInfoFormState();
}

class _PersonalInfoFormState extends State<PersonalInfoForm> {
  late final TextEditingController _first;
  late final TextEditingController _last;
  late final TextEditingController _company;
  late final TextEditingController _street;
  late final TextEditingController _postal;
  late final TextEditingController _city;
  late final TextEditingController _phone;
  late final TextEditingController _email;
  late final TextEditingController _vat;
  late final TextEditingController _legal;
  String? _country;

  @override
  void initState() {
    super.initState();
    final i = widget.initial;
    _first = TextEditingController(text: i.firstName);
    _last = TextEditingController(text: i.lastName);
    _company = TextEditingController(text: i.company);
    _street = TextEditingController(text: i.street);
    _postal = TextEditingController(text: i.postalCode);
    _city = TextEditingController(text: i.city);
    _phone = TextEditingController(text: i.phone);
    _email = TextEditingController(text: i.email);
    _vat = TextEditingController(text: i.vatId);
    _legal = TextEditingController(text: i.legalId);
    final stored = i.countryCode.isNotEmpty
        ? i.countryCode
        : widget.workspaceCountry.toUpperCase();
    _country = CountryCatalog.countries.any((c) => c.code == stored)
        ? stored
        : null;
    for (final c in _controllers) {
      c.addListener(_refreshPreview);
    }
  }

  List<TextEditingController> get _controllers => [
    _first,
    _last,
    _company,
    _street,
    _postal,
    _city,
    _phone,
    _email,
    _vat,
    _legal,
  ];

  void _refreshPreview() => setState(() {});

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  PersonalInfo get _value => PersonalInfo(
    firstName: _first.text,
    lastName: _last.text,
    company: _company.text,
    street: _street.text,
    postalCode: _postal.text,
    city: _city.text,
    countryCode: _country ?? '',
    phone: _phone.text,
    email: _email.text,
    vatId: _vat.text,
    legalId: _legal.text,
  ).normalized();

  Widget _field(
    TextEditingController controller,
    String keySuffix,
    String label, {
    TextInputType? type,
    TextCapitalization capitalization = TextCapitalization.words,
    bool autocorrect = true,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.md),
    child: TextField(
      key: ValueKey('personal-info-$keySuffix'),
      controller: controller,
      enabled: !widget.saving,
      keyboardType: type,
      textCapitalization: capitalization,
      autocorrect: autocorrect,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final value = _value;
    final previewLines = [
      value.fullName,
      value.postalBlock(workspaceCountry: widget.workspaceCountry),
    ].where((l) => l.isNotEmpty).join('\n');
    final preview = previewLines.isEmpty
        ? (l10n?.personalInfoNone ?? 'Not filled in yet')
        : previewLines;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          widget.intro ??
              l10n?.personalInfoSubtitle ??
              'Printed on your invoices and letters. Your family name is '
                  'written in capitals, as on official mail.',
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(height: AppSpacing.lg),
        _field(
          _first,
          'first-name',
          l10n?.personalInfoFirstName ?? 'First name',
          type: TextInputType.name,
        ),
        _field(
          _last,
          'last-name',
          l10n?.personalInfoLastName ?? 'Family name',
          type: TextInputType.name,
        ),
        _field(
          _company,
          'company',
          l10n?.personalInfoCompany ?? 'Company (optional)',
        ),
        _field(
          _street,
          'street',
          l10n?.personalInfoStreet ?? 'Street and number',
          type: TextInputType.streetAddress,
        ),
        Row(
          children: [
            SizedBox(
              width: 140,
              child: _field(
                _postal,
                'postal-code',
                l10n?.personalInfoPostalCode ?? 'Postal code',
                capitalization: TextCapitalization.characters,
                autocorrect: false,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: _field(_city, 'city', l10n?.personalInfoCity ?? 'City'),
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.md),
          child: DropdownButtonFormField<String>(
            key: const ValueKey('personal-info-country'),
            initialValue: _country,
            decoration: InputDecoration(
              labelText: l10n?.personalInfoCountry ?? 'Country',
              border: const OutlineInputBorder(),
            ),
            items: [
              for (final c in CountryCatalog.countries)
                DropdownMenuItem(
                  value: c.code,
                  child: Text(localizedCountryName(l10n, c.code)),
                ),
            ],
            onChanged: widget.saving
                ? null
                : (v) => setState(() => _country = v),
          ),
        ),
        _field(
          _phone,
          'phone',
          l10n?.personalInfoPhone ?? 'Telephone',
          type: TextInputType.phone,
          capitalization: TextCapitalization.none,
          autocorrect: false,
        ),
        _field(
          _email,
          'email',
          l10n?.personalInfoEmail ?? 'E-mail for documents',
          type: TextInputType.emailAddress,
          capitalization: TextCapitalization.none,
          autocorrect: false,
        ),
        _field(
          _vat,
          'vat-id',
          l10n?.personalInfoVatId ?? 'VAT number (optional)',
          capitalization: TextCapitalization.characters,
          autocorrect: false,
        ),
        _field(
          _legal,
          'legal-id',
          l10n?.personalInfoLegalId ?? 'Company / registration id (optional)',
          capitalization: TextCapitalization.characters,
          autocorrect: false,
        ),
        // The block exactly as the envelope window and the invoice will
        // print it — so what the person sees here is what gets posted.
        Text(
          l10n?.personalInfoPreview ?? 'On your documents',
          style: theme.textTheme.labelLarge,
        ),
        const SizedBox(height: AppSpacing.xs),
        Container(
          key: const ValueKey('personal-info-preview'),
          width: double.infinity,
          padding: AppSpacing.mdAll,
          decoration: BoxDecoration(
            border: Border.all(color: theme.colorScheme.outlineVariant),
            borderRadius: AppRadius.mdAll,
          ),
          child: Text(preview, style: theme.textTheme.bodyMedium),
        ),
        const SizedBox(height: AppSpacing.lg),
        FilledButton(
          key: const ValueKey('personal-info-save'),
          onPressed: widget.saving ? null : () => widget.onSave(_value),
          child: Text(l10n?.personalInfoSave ?? 'Save'),
        ),
      ],
    );
  }
}
