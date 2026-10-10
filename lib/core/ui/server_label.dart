// SPDX-License-Identifier: AGPL-3.0-or-later
import '../../l10n/app_localizations.dart';
import '../backend/backend_settings.dart';

/// #2343 — how a server is named to a person: the reference deployment by
/// that name, any other by its host.
String serverLabel(AppLocalizations l10n, String url) {
  final host = Uri.tryParse(url)?.host ?? url;
  return isReferenceBackend(url) ? l10n.serverReferenceLabel(host) : host;
}
