// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4005 — Settings › Organisation › Add a house abroad: the head's owner
// makes a business of its own in another country or currency, carrying the
// head's configuration. The country comes first; the currency, the time zone
// and the documents' language are proposed from it and stay editable. Before
// the button the form says what travels, what arrives to be priced and what
// does not travel: the person knows before a legal entity's business exists.
// One opened form is one request: a retry answers the same house.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/country/country_catalog.dart';
import '../../../../core/i18n/app_format.dart';
import '../../../../core/i18n/country_names.dart';
import '../../../../core/i18n/time_zone_picker.dart';
import '../../../../core/ids/request_id.dart';
import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/time/clock.dart';
import '../../../../core/ui/currency_field.dart';
import '../../../../core/ui/form_kit.dart';
import '../../../../core/ui/master_data_field.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/organisation.dart';
import '../../providers/organisation_providers.dart';
import 'organisation_sheet.dart' show organisationRefusalText;

/// The languages a house's documents may speak: the app's own.
List<String> get _houseLanguages => [
  for (final l in AppLocalizations.supportedLocales) l.languageCode,
];

/// The documents' language proposed for [country]: the language the
/// country's first format locale pairs with it, when the documents speak it;
/// English otherwise.
@visibleForTesting
String proposedHouseLanguage(String country) {
  final paired = kFormatLocales
      .where((l) => l.endsWith('_${country.toUpperCase()}'))
      .map((l) => l.split('_').first)
      .firstOrNull;
  return paired != null && _houseLanguages.contains(paired) ? paired : 'en';
}

/// The values a change of country from [from] to [to] leaves: each one the
/// person has not changed follows the new country; one they chose stays.
@visibleForTesting
({String currency, String timezone, String language}) houseProposalAfter(
  Country from,
  Country to, {
  required String currency,
  required String timezone,
  required String language,
}) => (
  currency: currency.trim() == from.currencyCode ? to.currencyCode : currency,
  timezone: timezone == from.defaultTimezone ? to.defaultTimezone : timezone,
  language: language == proposedHouseLanguage(from.code)
      ? proposedHouseLanguage(to.code)
      : language,
);

/// Opens the form for a house of [organisation]; the new house's id once it
/// exists, null when the person leaves the form.
abstract final class AddHouseForm {
  static Future<String?> open(
    BuildContext context,
    WidgetRef ref,
    Organisation organisation,
  ) async {
    final l10n = context.l10n;
    final commands = ref.read(organisationCommandsProvider);
    final requestId = newRequestId();
    final proposed = ref.read(houseCountryProposalProvider);
    var country = proposed == null
        ? CountryCatalog.countries.first
        : CountryCatalog.byCode(proposed);
    final language = proposedHouseLanguage(country.code);
    var timezone = country.defaultTimezone;
    final fields = FormControllers({
      'name': '',
      'country': country.code,
      'currency': country.currencyCode,
      'language': language,
    });
    String? created;
    final done = await showAppFormSheet(
      context,
      AppFormSheet(
        title: l10n.houseAddTitle,
        submitLabel: l10n.houseAddSubmit,
        submitKey: const ValueKey('house-add-submit'),
        onDispose: fields.dispose,
        validate: () => {
          if (fields['name'].text.trim().isEmpty)
            'name': l10n.organisationRefusedNoName,
        },
        onSubmit: () async {
          final answer = await commands.createHouse((
            organisationId: organisation.id,
            name: fields['name'].text.trim(),
            country: country.code,
            currency: fields['currency'].text.trim().toUpperCase(),
            timezone: timezone,
            language: fields['language'].text,
            requestId: requestId,
          ));
          if (answer.refused case final refused?) {
            return organisationRefusalText(l10n, refused);
          }
          created = answer.workspaceId;
          return null;
        },
        builder: (context, refresh) => [
          MasterDataField(
            controller: fields['country'],
            label: l10n.workspaceCountryLabel,
            fieldKey: 'country',
            textKey: const ValueKey('house-add-country'),
            options: [
              for (final c in CountryCatalog.countries)
                MasterDataOption(
                  code: c.code,
                  name: localizedCountryName(l10n, c.code),
                ),
            ],
            onChanged: (code) {
              if (!CountryCatalog.isKnown(code)) return;
              final next = CountryCatalog.byCode(code);
              final proposal = houseProposalAfter(
                country,
                next,
                currency: fields['currency'].text,
                timezone: timezone,
                language: fields['language'].text,
              );
              fields['currency'].text = proposal.currency;
              fields['language'].text = proposal.language;
              timezone = proposal.timezone;
              country = next;
              refresh();
            },
          ),
          const FormGap(),
          CurrencyField(
            controller: fields['currency'],
            label: l10n.workspaceCurrencyLabel,
            fieldKey: 'currency',
            textKey: const ValueKey('house-add-currency'),
          ),
          const FormGap(),
          OutlinedButton.icon(
            key: const ValueKey('house-add-timezone'),
            icon: const Icon(Icons.schedule),
            label: Text(l10n.houseAddTimezone(timezone)),
            onPressed: () async {
              final picked = await showTimeZonePicker(
                context,
                current: timezone,
                now: ref.read(clockProvider).now(),
              );
              if (picked == null) return;
              timezone = picked;
              refresh();
            },
          ),
          const FormGap(),
          MasterDataField(
            controller: fields['language'],
            label: l10n.houseAddLanguage,
            fieldKey: 'language',
            textKey: const ValueKey('house-add-language'),
            options: [
              for (final code in _houseLanguages)
                MasterDataOption(
                  code: code,
                  name: localizedLanguageName(l10n, code),
                ),
            ],
          ),
          const FormGap(),
          AppTextField(
            key: const ValueKey('house-add-name'),
            controller: fields['name'],
            fieldKey: 'name',
            label: l10n.houseAddName,
            maxLength: 200,
          ),
          const FormGap(),
          // Before the button: what travels, what arrives to be priced,
          // what does not.
          Text(l10n.houseAddCarried, key: const ValueKey('house-add-carried')),
          const FormGap.small(),
          Text(l10n.houseAddToPrice),
          const FormGap.small(),
          Text(l10n.houseAddNotCarried),
        ],
      ),
    );
    return done ? created : null;
  }
}
