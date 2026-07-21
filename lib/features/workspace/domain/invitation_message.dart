// SPDX-License-Identifier: 0BSD
//
// Invitation messages (0049): a new member is invited over WhatsApp, SMS,
// or any share target with a text that explains — in the chosen language —
// how to download DesKilo, create an account, and join the workspace.
// The owner may replace the localized default with a custom template;
// {tag} placeholders are filled from the same value map either way.

/// Where to get the app. Play is derived from the applicationId; F-Droid
/// carries the Google-services-free flavor of the same package.
abstract final class StoreLinks {
  static const String play =
      'https://play.google.com/store/apps/details?id=de.deskilo.app';
  static const String fdroid = 'https://f-droid.org/packages/de.deskilo.app';

  /// Both stores on one line — the {downloadUrl} tag.
  static const String downloadLine = '$play · $fdroid';
}

/// The placeholder tags an invitation template may carry. Kept as data so
/// the settings editor can list them and the filler can iterate them —
/// one source of truth for both.
abstract final class InvitationTags {
  static const firstName = '{firstName}';
  static const lastName = '{lastName}';
  static const phone = '{phone}';
  static const workspaceName = '{workspaceName}';
  static const workspaceId = '{workspaceId}';
  static const inviteLink = '{inviteLink}';
  static const downloadUrl = '{downloadUrl}';
  static const role = '{role}';

  static const all = [
    firstName,
    lastName,
    phone,
    workspaceName,
    workspaceId,
    inviteLink,
    downloadUrl,
    role,
  ];
}

/// Max template length — cross-pinned to the 0049 column check.
const int invitationTemplateMaxLength = 2000;

/// Fills every known {tag} in [template] from [values] (tag → value,
/// keys WITHOUT braces). Unknown tags are left as-is so a typo is visible
/// in the preview instead of silently vanishing.
String fillInvitationTemplate(String template, Map<String, String> values) {
  var text = template;
  for (final tag in InvitationTags.all) {
    final key = tag.substring(1, tag.length - 1);
    text = text.replaceAll(tag, values[key] ?? '');
  }
  return text;
}
