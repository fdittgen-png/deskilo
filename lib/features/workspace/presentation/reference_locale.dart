// SPDX-License-Identifier: 0BSD
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../providers/workspace_providers.dart';

/// #1179 — the language a message REFERENCE is written in.
///
/// A `[res:…|label]` token bakes its label into the message body and is
/// never re-rendered: that is deliberate (see `member_note_refs.dart` —
/// it is what lets a since-deleted reservation still read as text, and
/// what keeps a message list from doing a lookup per reference). The
/// consequence is that whatever language the label is written in, every
/// reader of that conversation gets it, for ever.
///
/// It used to be the SENDER'S DEVICE language, which is nobody's
/// agreement: an English conversation showed "31 août" because the
/// person who sent it held a French phone.
///
/// The workspace's own language is the one thing the participants share,
/// and the app already uses it this way for invitations. A space that
/// never set one falls back to the reader's — the old behaviour, for the
/// only case where there is nothing better.
String? referenceLocale(WidgetRef ref, BuildContext context) {
  final workspace = ref.read(currentWorkspaceProvider).value;
  final chosen = workspace?.defaultLocale.trim() ?? '';
  if (chosen.isNotEmpty) return chosen;
  return Localizations.maybeLocaleOf(context)?.toString();
}

/// #1179 — the translations a baked-in reference label is written with.
///
/// The companion to [referenceLocale]: a label like "Deletion request ·
/// Ana · 14 Sept" carries a translated noun as well as a formatted
/// date, and both are frozen into the message. This resolves the same
/// language [referenceLocale] picks, falling back to the reader's own
/// whenever the workspace names a language the app does not ship.
AppLocalizations? referenceL10n(WidgetRef ref, BuildContext context) {
  final mine = AppLocalizations.of(context);
  final name = referenceLocale(ref, context);
  if (name == null || name.isEmpty) return mine;
  final locale = Locale(name.split(RegExp('[_-]')).first);
  if (!AppLocalizations.delegate.isSupported(locale)) return mine;
  return lookupAppLocalizations(locale);
}
