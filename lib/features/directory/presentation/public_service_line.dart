// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3553, #3554 — one published service in one line, wherever it is shown:
// its name, its duration, its price as the caller formats it (the owner's
// preview in the business's format, Discover in the person's, the currency
// named) and what that price means for tax. A price is never shown without
// its tax word.
import '../../../l10n/app_localizations.dart';
import '../domain/public_workspace.dart';

/// The words of a price's tax treatment.
String _taxWords(AppLocalizations l10n, PublicTaxTreatment t) => switch (t) {
  PublicTaxTreatment.included => l10n.portalOfferTaxIncluded,
  PublicTaxTreatment.excluded => l10n.portalOfferTaxExcluded,
  PublicTaxTreatment.none => l10n.portalOfferTaxNone,
};

/// "Name · 60 min · [price] · tax word".
String publicServiceLine(
  AppLocalizations l10n,
  PublicService service,
  String price,
) => [
  service.name,
  if (service.durationMinutes case final minutes?)
    l10n.portalOfferMinutes(minutes),
  price,
  _taxWords(l10n, service.taxTreatment),
].join(' · ');
