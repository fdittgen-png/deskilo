// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3774 — a refused e-mail says why in words: the codes this server writes
// become sentences, a provider's answer names its status, anything else is
// quoted as it came; the same for a purchase order and a reminder.
import 'package:deskilo/features/money/domain/mail_refusal.dart';
import 'package:deskilo/features/money/presentation/mail_refusal_text.dart';
import 'package:deskilo/l10n/app_localizations_en.dart';
import 'package:deskilo/l10n/app_localizations_fr.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('the recorded reasons read as what they are', () {
    expect(MailRefusal.of('mail_not_configured'), isA<MailRefusalNoSender>());
    expect(MailRefusal.of('invalid_order_mail'), isA<MailRefusalInvalid>());
    expect(
      MailRefusal.of('provider_422'),
      isA<MailRefusalProvider>().having((r) => r.status, 'status', '422'),
    );
    expect(
      MailRefusal.of('provider_x'),
      isA<MailRefusalOther>().having((r) => r.text, 'text', 'provider_x'),
    );
  });

  test('a code becomes a sentence; anything else is quoted', () {
    final en = AppLocalizationsEn();
    final fr = AppLocalizationsFr();
    expect(mailRefusalText(en, 'mail_not_configured'), en.mailRefusalNoSender);
    expect(mailRefusalText(fr, 'provider_422'), contains('422'));
    expect(mailRefusalText(en, 'no route'), '“no route”');
    expect(mailRefusalText(fr, 'no route'), '« no route »');
    expect(
      en.purchaseOrderSendRefused(mailRefusalText(en, 'mail_not_configured')),
      isNot(contains('mail_not_configured')),
    );
  });
}
