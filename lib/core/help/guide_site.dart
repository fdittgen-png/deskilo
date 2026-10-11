// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../links/link_launcher.dart';

/// The published guide site: one page per language for the user guide
/// (`en.html`) and one for the setup guide (`setup-en.html`). Every
/// section's element id is its help anchor (`user.x.y` / `setup.x.y`).
const _guideSiteBase = 'https://fdittgen-png.github.io/deskilo/guide/';

const _guideLanguages = {'en', 'fr', 'de', 'es', 'it'};

/// Where [anchor] lives for a reader in [languageCode]; with no anchor,
/// the top of the user guide. An anchor that starts with `setup.` opens
/// the setup guide.
Uri _guideUri(String languageCode, {String? anchor}) {
  final lang = _guideLanguages.contains(languageCode) ? languageCode : 'en';
  final setup = anchor != null && anchor.startsWith('setup.');
  return Uri.parse(
    '$_guideSiteBase${setup ? 'setup-' : ''}$lang.html'
    '${anchor == null ? '' : '#$anchor'}',
  );
}

/// Opens the guide site at [anchor] in the reader's language.
Future<bool> openGuide(WidgetRef ref, BuildContext context, {String? anchor}) =>
    ref.read(linkLauncherProvider)(
      _guideUri(Localizations.localeOf(context).languageCode, anchor: anchor),
    );
