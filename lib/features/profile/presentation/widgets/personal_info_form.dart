// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #886 — THE identity form. A person edits their own personal
// information here (Settings → Personal information); an admin edits a
// managed member's identity (#887) with the same widget, so both places
// ask for the same fields in the same words and the documents print
// one shape whoever typed it.
import 'package:flutter/material.dart';

import '../../../../core/country/country_catalog.dart';
import '../../../../core/i18n/country_names.dart';
import '../../../../core/jurisdiction/installed_postal_layouts.dart';
import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/phone/phone_entry.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/ui/address_region_field.dart';
import '../../../../core/ui/phone_field.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/personal_info.dart';
import '../courtesy_words.dart';

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
    this.managed = false,
    this.extraSection,
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

  /// #1288 — the workspace's own questions, rendered just above Save so
  /// one Save sends the whole form. The host owns the section's answers
  /// and sends them; this form only makes room for it, which is what
  /// keeps PersonalInfoForm the ONE identity form.
  final Widget? extraSection;

  /// #1177 — the form is editing SOMEBODY ELSE. The subject decides the
  /// person the hints are written in: "your name" is right on your own
  /// profile and wrong on a managed one, where an admin fills a form
  /// about a member who has no account yet.
  final bool managed;

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

  /// #3650 — the country the phone is read in: the person's own, never
  /// the workspace's.
  late final TextEditingController _phoneCountry;
  String? _phoneError;
  late final TextEditingController _email;
  late final TextEditingController _vat;
  late final TextEditingController _legal;
  String? _country;
  // #3649 -- the region's code, and why it cannot be saved.
  late String _region;
  String? _regionError;
  // #912 — how this person asks to be addressed.
  late Courtesy _courtesy;

  @override
  void initState() {
    super.initState();
    final i = widget.initial;
    _courtesy = i.courtesy;
    _first = TextEditingController(text: i.firstName);
    _last = TextEditingController(text: i.lastName);
    _company = TextEditingController(text: i.company);
    _street = TextEditingController(text: i.street);
    _postal = TextEditingController(text: i.postalCode);
    _city = TextEditingController(text: i.city);
    _region = i.subdivision;
    _phone = TextEditingController(text: i.phone);
    _phoneCountry = TextEditingController(text: i.countryCode);
    _email = TextEditingController(text: i.email);
    _vat = TextEditingController(text: i.vatId);
    _legal = TextEditingController(text: i.legalId);
    // A country the person already has is kept whatever the catalogue
    // offers; the workspace's is only proposed, and only when it is offered.
    final proposed = widget.workspaceCountry.toUpperCase();
    _country = i.countryCode.isNotEmpty
        ? i.countryCode
        : (CountryCatalog.countries.any((c) => c.code == proposed)
              ? proposed
              : null);
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
    _phoneCountry.dispose();
    super.dispose();
  }

  /// #3650 — an edited phone is saved only once it is a number of its
  /// country; one kept as it was saves as before.
  Future<void> _save() async {
    if (_phone.text.trim() != widget.initial.phone.trim()) {
      final problem = phoneProblemText(context.l10n, phoneEntryOf(_phone, _phoneCountry));
      if (problem != null) {
        setState(() => _phoneError = problem);
        return;
      }
    }
    final region = _regionProblem();
    if (region != null) {
      _setRegion(_region, error: region);
      return;
    }
    await widget.onSave(_value);
  }

  /// #3649 -- the region is checked once the address is edited: an address
  /// stored before its country asked for one keeps saving as it is.
  String? _regionProblem() {
    final now = _value;
    final before = widget.initial.normalized();
    final edited =
        now.street != before.street ||
        now.postalCode != before.postalCode ||
        now.city != before.city ||
        now.subdivision != before.subdivision ||
        now.countryCode != before.countryCode;
    if (!edited) return null;
    final refusal = postalLayoutOf(now.countryCode).regionRefusal(now.subdivision);
    return refusal == null ? null : regionRefusalText(context.l10n, refusal);
  }

  /// A new country keeps the region only when it has one by that code.
  void _setCountry(String? country) {
    final names = postalLayoutOf(country ?? '').region?.names ?? const {};
    final keep = names.isEmpty || names.containsKey(_region);
    _setRegion(keep ? _region : '', country: country);
  }

  /// The one place the address's country and region change, with why the
  /// region cannot be saved when it cannot.
  void _setRegion(String region, {String? country, String? error}) =>
      setState(() {
        if (country != null) _country = country;
        _region = region;
        _regionError = error;
      });

  PersonalInfo get _value => PersonalInfo(
    courtesy: _courtesy,
    firstName: _first.text,
    lastName: _last.text,
    company: _company.text,
    street: _street.text,
    postalCode: _postal.text,
    city: _city.text,
    subdivision: _region,
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
    List<String>? autofill,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.md),
    child: TextField(
      key: ValueKey('personal-info-$keySuffix'),
      controller: controller,
      enabled: !widget.saving,
      keyboardType: type,
      autofillHints: autofill,
      textCapitalization: capitalization,
      autocorrect: autocorrect,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
    ),
  );

  /// #3650 — the identity phone in the form kit's phone field, read in the
  /// person's own country. A number kept from before is not refused: it
  /// says what it is missing until it is edited.
  Widget _phoneField(AppLocalizations l10n) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.md),
    child: PhoneField(
      number: _phone,
      country: _phoneCountry,
      label: l10n.personalInfoPhone,
      fieldKey: 'personal-info-phone',
      helper: _phone.text.trim() == widget.initial.phone.trim()
          ? phoneProblemText(
              l10n,
              parsePhone(widget.initial.phone, country: widget.initial.countryCode),
            )
          : null,
      error: _phoneError,
      enabled: !widget.saving,
      onChanged: () {
        if (_phoneError != null) setState(() => _phoneError = null);
      },
    ),
  );

  /// The country, then the region its addresses have (#3649).
  List<Widget> _countryAndRegion(AppLocalizations l10n) => [
    Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: DropdownButtonFormField<String>(
        key: const ValueKey('personal-info-country'),
        initialValue: _country,
        decoration: InputDecoration(
          labelText: l10n.workspaceCountryLabel,
          border: const OutlineInputBorder(),
        ),
        items: [
          for (final code in CountryCatalog.addressCodes(
            stored: widget.initial.countryCode,
          ))
            DropdownMenuItem(
              value: code,
              child: Text(localizedCountryName(l10n, code)),
            ),
        ],
        onChanged: widget.saving ? null : _setCountry,
      ),
    ),
    AddressRegionField(
      key: ValueKey('personal-info-region-$_country'),
      fieldKey: 'personal-info-region',
      country: _country ?? '',
      value: _region,
      error: _regionError,
      enabled: !widget.saving,
      onChanged: _setRegion,
    ),
  ];

  /// #3281 — the one Company field; on my own profile it says it is the
  /// account-wide value, not a workspace's question.
  Widget _companyField(AppLocalizations l10n) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _field(
        _company,
        'company',
        l10n.personalInfoCompany,
        autofill: const [AutofillHints.organizationName],
      ),
      if (!widget.managed)
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.md),
          child: Text(
            l10n.personalInfoCompanyScope,
            key: const ValueKey('personal-info-company-scope'),
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
    ],
  );

  /// The block as documents print it, under the name; a word when empty.
  String _preview(AppLocalizations l10n, PersonalInfo value) {
    final lines = [
      value.fullName,
      value.postalBlock(
        workspaceCountry: widget.workspaceCountry,
        courtesyWord: courtesyWord(l10n, value.courtesy),
        countryName: (code) => localizedCountryName(l10n, code),
      ),
    ].where((l) => l.isNotEmpty).join('\n');
    return lines.isEmpty ? l10n.personalInfoNone : lines;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final value = _value;
    final preview = _preview(l10n, value);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          widget.intro ??
              l10n.personalInfoSubtitle,
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(height: AppSpacing.lg),
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.md),
          child: DropdownButtonFormField<Courtesy>(
            key: const ValueKey('personal-info-courtesy'),
            initialValue: _courtesy,
            decoration: InputDecoration(
              labelText: l10n.courtesyLabel,
              helperMaxLines: 3,
              helperText: widget.managed
                  ? (l10n.courtesyHintManaged)
                  : (l10n.courtesyHint),
              border: const OutlineInputBorder(),
            ),
            items: [
              for (final c in Courtesy.values)
                DropdownMenuItem(
                  value: c,
                  child: Text(courtesyOptionLabel(l10n, c)),
                ),
            ],
            onChanged: widget.saving
                ? null
                : (v) => setState(() => _courtesy = v ?? _courtesy),
          ),
        ),
        _field(
          _first,
          'first-name',
          l10n.personalInfoFirstName,
          type: TextInputType.name,
          autofill: const [AutofillHints.givenName],
        ),
        _field(
          _last,
          'last-name',
          l10n.personalInfoLastName,
          type: TextInputType.name,
          autofill: const [AutofillHints.familyName],
        ),
        _companyField(l10n),
        _field(
          _street,
          'street',
          l10n.personalInfoStreet,
          type: TextInputType.streetAddress,
          autofill: const [AutofillHints.streetAddressLine1],
        ),
        Row(
          children: [
            SizedBox(
              width: 140,
              child: _field(
                _postal,
                'postal-code',
                l10n.personalInfoPostalCode,
                capitalization: TextCapitalization.characters,
                autocorrect: false,
                autofill: const [AutofillHints.postalCode],
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: _field(
                _city,
                'city',
                l10n.personalInfoCity,
                autofill: const [AutofillHints.addressCity],
              ),
            ),
          ],
        ),
        ..._countryAndRegion(l10n),
        _phoneField(l10n),
        _field(
          _email,
          'email',
          l10n.personalInfoEmail,
          type: TextInputType.emailAddress,
          capitalization: TextCapitalization.none,
          autocorrect: false,
          autofill: const [AutofillHints.email],
        ),
        _field(
          _vat,
          'vat-id',
          l10n.personalInfoVatId,
          capitalization: TextCapitalization.characters,
          autocorrect: false,
        ),
        _field(
          _legal,
          'legal-id',
          l10n.personalInfoLegalId,
          capitalization: TextCapitalization.characters,
          autocorrect: false,
        ),
        // The block exactly as the envelope window and the invoice will
        // print it — so what the person sees here is what gets posted.
        Text(
          l10n.personalInfoPreview,
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
        if (widget.extraSection != null) widget.extraSection!,
        const SizedBox(height: AppSpacing.lg),
        FilledButton(
          key: const ValueKey('personal-info-save'),
          onPressed: widget.saving ? null : _save,
          child: Text(l10n.commonSave),
        ),
      ],
    );
  }
}
