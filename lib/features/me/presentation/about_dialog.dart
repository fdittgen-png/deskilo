// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1823 — my profession and a few words about me. They live apart from
// the profile row every space mate can read (#1822), so "nobody" can
// mean nobody; who reads them is the About audience on the same card.
import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../application/me_actions.dart';

/// Edits profession and bio; pops `(profession, bio)` or null.
class AboutMeDialog extends StatefulWidget {
  const AboutMeDialog({super.key, required this.profession, required this.bio});

  final String profession;
  final String bio;

  @override
  State<AboutMeDialog> createState() => _AboutDialogState();
}

class _AboutDialogState extends State<AboutMeDialog> {
  late final _profession = TextEditingController(text: widget.profession);
  late final _bio = TextEditingController(text: widget.bio);

  @override
  void dispose() {
    _profession.dispose();
    _bio.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l10n?.visibilityAboutMe ?? 'About me'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              key: const ValueKey('about-profession'),
              controller: _profession,
              maxLength: AboutLimits.profession,
              decoration: InputDecoration(
                  labelText: l10n?.visibilityProfession ?? 'Profession'),
            ),
            TextField(
              key: const ValueKey('about-bio'),
              controller: _bio,
              maxLength: AboutLimits.bio,
              minLines: 2,
              maxLines: 5,
              decoration: InputDecoration(
                  labelText: l10n?.visibilityBio ?? 'A few words about you'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n?.commonCancel ?? 'Cancel'),
        ),
        FilledButton(
          key: const ValueKey('about-save'),
          onPressed: () =>
              Navigator.of(context).pop((_profession.text, _bio.text)),
          child: Text(l10n?.commonSave ?? 'Save'),
        ),
      ],
    );
  }
}
