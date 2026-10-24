// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1823 — the words and icons for visibility fields and audiences, in
// one place so the card, the sheet and the preview cannot disagree.
import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../domain/audience_space.dart';
import '../domain/visibility.dart';

String visibilityFieldLabel(AppLocalizations l10n, VisibilityField field) =>
    switch (field) {
      VisibilityField.identity => l10n.visibilityIdentity,
      VisibilityField.about => l10n.visibilityAbout,
      VisibilityField.contactChannels =>
        l10n.visibilityContact,
      VisibilityField.presence =>
        l10n.visibilityPresence,
      VisibilityField.reachability =>
        l10n.visibilityReachability,
    };

IconData visibilityFieldIcon(VisibilityField field) => switch (field) {
      VisibilityField.identity => Icons.badge_outlined,
      VisibilityField.about => Icons.work_outline,
      VisibilityField.contactChannels => Icons.contact_phone_outlined,
      VisibilityField.presence => Icons.location_on_outlined,
      VisibilityField.reachability => Icons.forum_outlined,
    };

String audienceLabel(AppLocalizations l10n, VisibilityAudience audience) =>
    switch (audience) {
      VisibilityAudience.nobody => l10n.visibilityNobody,
      VisibilityAudience.mySpaces =>
        l10n.visibilityMySpaces,
      VisibilityAudience.chosenSpaces =>
        l10n.visibilityChosenSpaces,
      VisibilityAudience.signedIn =>
        l10n.visibilitySignedIn,
    };

/// The audience, and how many spaces when they were chosen.
String audienceSummary(AppLocalizations l10n, FieldAudience choice) =>
    choice.audience == VisibilityAudience.chosenSpaces
        ? (l10n.visibilityChosenCount(choice.workspaces.length))
        : audienceLabel(l10n, choice.audience);

String previewAudienceLabel(AppLocalizations l10n, PreviewAudience as) =>
    switch (as) {
      PreviewAudience.mySpaces =>
        l10n.visibilityPreviewMySpaces,
      PreviewAudience.signedIn =>
        l10n.visibilityPreviewSignedIn,
      PreviewAudience.nobody => l10n.visibilityPreviewNobody,
    };

/// #2558 — what a chosen space is called: its name where the home may
/// read one, else what kind of space it is. [space] null is a saved space
/// the home no longer lists.
String audienceSpaceLabel(AppLocalizations l10n, AudienceSpace? space) {
  final name = space?.name?.trim();
  if (name != null && name.isNotEmpty) return name;
  if (space != null && !space.hostedHere) return l10n.meRefUnnamed;
  return l10n.visibilitySpaceUnlisted;
}

/// #2558 — where a space lives, to tell two spaces of one name apart:
/// this personal home, or another installation by the start of its id.
String audienceSpaceSource(AppLocalizations l10n, AudienceSpace space) =>
    space.hostedHere
        ? l10n.visibilitySpaceHere
        : l10n.visibilitySpaceOnServer(space.installationId.length > 8
            ? space.installationId.substring(0, 8)
            : space.installationId);
