// SPDX-License-Identifier: 0BSD
import '../../l10n/app_localizations.dart';

/// #751 — the consent the app asks for before anything else, and shows
/// again on demand (Settings → Privacy & data, the help §14, the wiki,
/// privacy.html). Bump [kPrivacyPolicyVersion] whenever the TEXT
/// changes: every account is then asked again, once.
const kPrivacyPolicyVersion = '2026-08-30';

/// Where the same text lives outside the app.
const kPrivacyWikiUrl =
    'https://github.com/fdittgen-png/deskilo/wiki/User-Guide#14-privacy';

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
                'number — each optional), and what you do in a workspace: '
                'reservations and check-ins, messages, expenses and '
                'consumptions, your subscription, invoices and payments. '
                'Everything is stored in the EU (Supabase, eu-central-1).',
      ),
      PrivacySection(
        l10n?.consentNotTitle ?? 'What DesKilo never does',
        l10n?.consentNotBody ??
            'No tracking, no analytics, no advertising, no sale or sharing '
                'of data. Push notifications carry no content — only "you '
                'have a new message"; the app itself writes the text. The '
                'F-Droid build has no Google services at all.',
      ),
      PrivacySection(
        l10n?.consentWhoTitle ?? 'Who can see what',
        l10n?.consentWhoBody ??
            'Access follows roles and is enforced on the server: bookings '
                'are visible to the workspace (the floor plan shows '
                'occupancy); messages only to the people in the '
                'conversation, whatever their role; your finances and your '
                'commercial agreement only to you, the owners and the '
                'admins holding the matching permission. Settings → '
                'Privacy & data names the people and lists who actually '
                'looked.',
      ),
      PrivacySection(
        l10n?.consentControllerTitle ?? 'Who is responsible',
        l10n?.consentControllerBody ??
            'Each workspace is operated by its owner — your community — '
                'who decides members, prices and payment providers. The '
                'app is open source (0BSD) and published by Florian '
                'Dittgen (Germany); the backend is Supabase in the EU. '
                'Online payments go through the provider the owner '
                'enabled (PayPal, Stripe, Mollie, Wero) under that '
                'provider\'s terms.',
      ),
      PrivacySection(
        l10n?.consentRetentionTitle ?? 'How long',
        l10n?.consentRetentionBody ??
            'As long as you are a member. When you leave and erase, your '
                'profile and messages go; accounting records (invoices, '
                'payments) stay for the legal retention period, by '
                'identifier and not by name.',
      ),
      PrivacySection(
        l10n?.consentRightsTitle ?? 'Your rights',
        l10n?.consentRightsBody ??
            'Access, rectification, export (art. 20), erasure (art. 17) '
                'and objection — each is a button in Settings → Privacy & '
                'data. For anything else: fdittgen@gmail.com. You may '
                'withdraw this consent by leaving the workspace and '
                'erasing your data at any time.',
      ),
      PrivacySection(
        l10n?.consentReviewTitle ?? 'Read it again anytime',
        l10n?.consentReviewBody ??
            'This text stays available in Settings → Privacy & data, in '
                'the in-app help (Privacy) and in the project wiki. A '
                'change of the text asks for your acceptance again.',
      ),
    ];
