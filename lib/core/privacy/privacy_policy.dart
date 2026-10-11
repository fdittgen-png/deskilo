// SPDX-License-Identifier: AGPL-3.0-or-later
import '../../l10n/app_localizations.dart';

/// #751 — the consent the app asks for before anything else, and shows
/// again on demand (Settings → Privacy & data, the in-app help, the
/// guide site, privacy.html). Bump [kPrivacyPolicyVersion] whenever the TEXT
/// changes: every account is then asked again, once.
const kPrivacyPolicyVersion = '2026-10-10';

/// Where the same text lives outside the app: its section of the published
/// user guide (the guide site's element id is the section's anchor).
const kPrivacyGuideUrl =
    'https://fdittgen-png.github.io/deskilo/guide/en.html#user.privacy.consent';

/// One section of the consent text: a heading and its paragraph.
class PrivacySection {
  const PrivacySection(this.title, this.body);
  final String title;
  final String body;
}

/// The consent text, localized, in reading order. The English fallback
/// is the text of record; the ARB fragments carry the four translations.
List<PrivacySection> privacySections(AppLocalizations? l10n) => [
      PrivacySection(
        l10n?.consentWhatTitle ?? 'What DesKilo processes',
        l10n?.consentWhatBody ??
            'Your account (e-mail, display name, hashed password), your '
                'profile as you fill it (photo, status, address, WhatsApp '
                'number — each optional), and what you do in a space: '
                'bookings and check-ins, messages, expenses and consumptions, '
                'your subscription, invoices and payments. All of it is '
                'stored on the server your space runs on: on the shared '
                'reference server, in the EU (Supabase, eu-central-1); on a '
                'server a community runs itself, wherever its operator chose. '
                'Settings → Privacy & data shows that server\'s notice: who '
                'runs it, where the data is and who receives it.',
      ),
      PrivacySection(
        l10n?.consentNotTitle ?? 'What DesKilo never does',
        l10n?.consentNotBody ??
            'No tracking, no analytics, no advertising, no sale of data. '
                'Your data goes to nobody except the recipients named here '
                'and in the server\'s notice. The F-Droid build has no Google '
                'services at all.',
      ),
      PrivacySection(
        l10n?.consentWhoTitle ?? 'Who can see what',
        l10n?.consentWhoBody ??
            'Access follows roles and is enforced on the server: bookings '
                'are visible to the space (the floor plan shows occupancy); '
                'your finances and your commercial agreement only to you, the '
                'owners and the admins holding the matching permission. Each '
                'item of your profile is shown only to the audience you pick '
                'under Who sees me; nothing is public unless you choose it. A '
                'public profile stays off until you publish it: then anyone '
                'with the link reads your name, profession and bio — never '
                'your contact details, presence or spaces — until you '
                'withdraw it. Settings → Privacy & data names the people and '
                'lists who actually looked.',
      ),
      PrivacySection(
        l10n?.consentMessagesTitle ?? 'Messages',
        l10n?.consentMessagesBody ??
            'Only the people in a conversation can open it: the two of '
                'you, the members of a group or, when you write to a space, '
                'the hosts the app names before you send. A space\'s owners '
                'and admins cannot read your conversations. Messages are not '
                'end-to-end encrypted: they are stored on the server the '
                'conversation lives on — another server\'s, after you confirm, '
                'when you write to someone there — and whoever runs that '
                'server can technically reach them.',
      ),
      PrivacySection(
        l10n?.consentPushTitle ?? 'Push notifications',
        l10n?.consentPushBody ??
            'Optional, and outbound. When the server\'s operator has set '
                'push up, your space uses it and it is on for this device, '
                'this device\'s address and each notification go to the push '
                'service (Firebase Cloud Messaging, which hands notifications '
                'for Apple devices on to Apple). A notification only says '
                'something generic, such as "You have a new message": no '
                'names, no times, no message text. Switch it off in Settings '
                '→ Privacy & data; the app keeps working and nothing more is '
                'sent to this device.',
      ),
      PrivacySection(
        l10n?.consentControllerTitle ?? 'Who is responsible',
        l10n?.consentControllerBody ??
            'Each space is run by its owner — your community — who '
                'decides members, prices and payment providers. Each server '
                'is run by its operator: the shared reference server by '
                'Florian Dittgen (Germany), a community\'s own server by '
                'whoever runs it. The app is free software '
                '(AGPL-3.0-or-later), published by Florian Dittgen. Online '
                'payments go through the provider the owner enabled (PayPal, '
                'Stripe, Mollie, Wero) under that provider\'s terms.',
      ),
      PrivacySection(
        l10n?.consentRetentionTitle ?? 'How long',
        l10n?.consentRetentionBody ??
            'As long as you are a member. When you leave a space and '
                'erase, your messages in that space go, and your profile goes '
                'with your last space. Accounting records stay for the legal '
                'retention period: the ledger by identifier, invoices as they '
                'were issued.',
      ),
      PrivacySection(
        l10n?.consentRightsTitle ?? 'Your rights',
        l10n?.consentRightsBody ??
            'Access, rectification, export (art. 20), erasure (art. 17) '
                'and objection — each is a button in Settings → Privacy & '
                'data. For anything else: fdittgen@gmail.com. You may '
                'withdraw this consent by leaving the workspace and erasing '
                'your data at any time.',
      ),
      PrivacySection(
        l10n?.consentReviewTitle ?? 'Read it again anytime',
        l10n?.consentReviewBody ??
            'This text stays available in Settings → Privacy & data, in '
                'the in-app help (Privacy) and in the online user guide. A '
                'change of the text asks for your acceptance again.',
      ),
    ];
