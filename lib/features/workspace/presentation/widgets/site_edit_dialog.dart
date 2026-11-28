// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #945 / #3649 -- the dialog that edits one site: its name, its address with
// the region its country asks for, its registration, and for a site that is
// its own legal entity, its VAT number and exemption.
import 'package:flutter/material.dart';

import '../../../../core/jurisdiction/installed_postal_layouts.dart';
import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/ui/address_region_field.dart';
import '../../../../core/ui/country_field.dart';
import '../../domain/site.dart';

/// What the dialog decided: the site to save, or that it is to be deleted.
typedef SiteEditResult = ({bool delete, Site draft});

/// Edits [site], or a new one in [workspaceId] when it is null.
class SiteEditDialog extends StatefulWidget {
  const SiteEditDialog({
    super.key,
    required this.site,
    required this.workspaceId,
    required this.workspaceCountry,
  });

  final Site? site;
  final String workspaceId;
  final String workspaceCountry;

  @override
  State<SiteEditDialog> createState() => _SiteEditDialogState();
}

class _SiteEditDialogState extends State<SiteEditDialog> {
  late final Site? _site = widget.site;
  late final _name = TextEditingController(text: _site?.name ?? '');
  late final _street = TextEditingController(text: _site?.street ?? '');
  late final _postal = TextEditingController(text: _site?.postalCode ?? '');
  late final _city = TextEditingController(text: _site?.city ?? '');
  late final _country = TextEditingController(
    text: _site?.countryCode ?? widget.workspaceCountry,
  );
  late final _legal = TextEditingController(text: _site?.legalId ?? '');
  late final _vat = TextEditingController(text: _site?.vatId ?? '');
  late final _exemption = TextEditingController(
    text: _site?.taxExemptionReason ?? '',
  );
  late String _region = _site?.subdivision ?? '';
  String? _regionError;
  String? _countryError;

  @override
  void dispose() {
    for (final c in [
      _name,
      _street,
      _postal,
      _city,
      _country,
      _legal,
      _vat,
      _exemption,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Site get _draft => Site(
    id: _site?.id ?? '',
    workspaceId: widget.workspaceId,
    name: _name.text.trim(),
    street: _street.text.trim(),
    postalCode: _postal.text.trim(),
    city: _city.text.trim(),
    countryCode: _country.text.trim().toUpperCase(),
    subdivision: regionCode(_region),
    legalId: _legal.text.trim(),
    vatId: _vat.text.trim(),
    taxExemptionReason: _exemption.text.trim(),
    isDefault: _site?.isDefault ?? false,
    sortOrder: _site?.sortOrder ?? 0,
  );

  /// #3649 -- the region is checked once the address is edited: a site stored
  /// before its country asked for one keeps saving as it is.
  void _save() {
    final draft = _draft;
    final before = _site;
    final edited =
        before == null ||
        draft.street != before.street ||
        draft.postalCode != before.postalCode ||
        draft.city != before.city ||
        draft.countryCode != before.countryCode ||
        draft.subdivision != before.subdivision;
    // #4501 -- a country that is picked is one of the catalogue; one stored before stays as it is until changed
    if (draft.countryCode != (before?.countryCode ?? '') && !isKnownOrEmptyCountry(draft.countryCode)) {
      setState(() => _countryError = context.l10n.masterDataUnlisted);
      return;
    }
    final refusal = edited
        ? postalLayoutOf(draft.countryCode).regionRefusal(draft.subdivision)
        : null;
    if (refusal != null) {
      setState(() => _regionError = regionRefusalText(context.l10n, refusal));
      return;
    }
    Navigator.of(context).pop<SiteEditResult>((delete: false, draft: draft));
  }

  Widget _field(String key, TextEditingController c, String label) => TextField(
    key: ValueKey(key),
    controller: c,
    decoration: InputDecoration(labelText: label),
  );

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final site = _site;
    final ownEntity = site != null && !site.isDefault;
    return AlertDialog(
      title: Text(site == null ? l10n.sitesAdd : site.name),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _field('site-name', _name, l10n.siteName),
            _field('site-street', _street, l10n.siteStreet),
            _field('site-postal', _postal, l10n.sitePostalCode),
            _field('site-city', _city, l10n.siteCity),
            CountryField(
              controller: _country,
              textKey: const ValueKey('site-country'),
              fieldKey: 'site-country',
              label: l10n.siteCountry,
              error: _countryError,
              onChanged: (_) => setState(() => _countryError = null),
            ),
            const SizedBox(height: AppSpacing.md),
            ValueListenableBuilder(
              valueListenable: _country,
              builder: (context, country, _) => AddressRegionField(
                key: ValueKey(
                  'site-region-${country.text.trim().toUpperCase()}',
                ),
                fieldKey: 'site-region',
                country: country.text.trim().toUpperCase(),
                value: _region,
                error: _regionError,
                onChanged: (v) => setState(() {
                  _region = v;
                  _regionError = null;
                }),
              ),
            ),
            _field('site-legal', _legal, l10n.siteLegalId),
            if (ownEntity) ...[
              const SizedBox(height: AppSpacing.md),
              Text(
                l10n.siteRegistrationHint,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              _field('site-vat', _vat, l10n.siteVatId),
              _field('site-exemption', _exemption, l10n.siteExemptionReason),
              const SizedBox(height: AppSpacing.md),
              Text(
                l10n.siteDeleteHint,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ],
        ),
      ),
      actions: [
        if (ownEntity)
          TextButton(
            key: const ValueKey('site-delete'),
            onPressed: () =>
                Navigator.of(context)
                    .pop<SiteEditResult>((delete: true, draft: site)),
            child: Text(l10n.siteDelete),
          ),
        TextButton(
          key: const ValueKey('sites-cancel'),
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.commonCancel),
        ),
        FilledButton(
          key: const ValueKey('site-save'),
          onPressed: _save,
          child: Text(l10n.commonSave),
        ),
      ],
    );
  }
}
