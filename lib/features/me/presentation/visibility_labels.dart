// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1823 — the words and icons for visibility fields and audiences, in
// one place so the card, the sheet and the preview cannot disagree.
import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../domain/visibility.dart';

String visibilityFieldLabel(AppLocalizations? l10n, VisibilityField field) =>
    switch (field) {
      VisibilityField.identity => l10n?.visibilityIdentity ?? 'Name and photo',
      VisibilityField.about => l10n?.visibilityAbout ?? 'Profession and bio',
      VisibilityField.contactChannels =>
        l10n?.visibilityContact ?? 'WhatsApp and e-mail',
      VisibilityField.presence =>
        l10n?.visibilityPresence ?? 'In the space today',
      VisibilityField.reachability =>
        l10n?.visibilityReachability ?? 'Who can start a conversation with me',
    };

IconData visibilityFieldIcon(VisibilityField field) => switch (field) {
      VisibilityField.identity => Icons.badge_outlined,
      VisibilityField.about => Icons.work_outline,
      VisibilityField.contactChannels => Icons.contact_phone_outlined,
      VisibilityField.presence => Icons.location_on_outlined,
      VisibilityField.reachability => Icons.forum_outlined,
    };

String audienceLabel(AppLocalizations? l10n, VisibilityAudience audience) =>
    switch (audience) {
      VisibilityAudience.nobody => l10n?.visibilityNobody ?? 'Nobody',
      VisibilityAudience.mySpaces =>
        l10n?.visibilityMySpaces ?? 'Members of my spaces',
      VisibilityAudience.chosenSpaces =>
        l10n?.visibilityChosenSpaces ?? 'Members of chosen spaces',
      VisibilityAudience.signedIn =>
        l10n?.visibilitySignedIn ?? 'Anyone signed in',
    };

/// The audience, and how many spaces when they were chosen.
String audienceSummary(AppLocalizations? l10n, FieldAudience choice) =>
    choice.audience == VisibilityAudience.chosenSpaces
        ? (l10n?.visibilityChosenCount(choice.workspaces.length) ??
            'Members of ${choice.workspaces.length} chosen spaces')
        : audienceLabel(l10n, choice.audience);

String previewAudienceLabel(AppLocalizations? l10n, PreviewAudience as) =>
    switch (as) {
      PreviewAudience.mySpaces =>
        l10n?.visibilityPreviewMySpaces ?? 'A member of my spaces',
      PreviewAudience.signedIn =>
        l10n?.visibilityPreviewSignedIn ?? 'Anyone signed in',
      PreviewAudience.nobody => l10n?.visibilityPreviewNobody ?? 'Nobody',
    };
