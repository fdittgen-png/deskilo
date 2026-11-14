// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3960 — the Demo's outbox: e-mail of invoices and reminders is recorded in
// memory and answered as the server answers; the refusals are the server's;
// nothing leaves the device and nothing is shared between sessions.
import 'package:deskilo/core/demo/data/money/demo_outbox.dart';
import 'package:deskilo/core/demo/seed/demo_flags.dart';
import 'package:deskilo/features/money/domain/invoice_mail.dart';
import 'package:deskilo/features/money/domain/reminder_mail.dart';
import 'package:deskilo/features/money/providers/invoice_mail_providers.dart';
import 'package:deskilo/features/money/providers/reminder_mail_providers.dart';
import 'package:deskilo/features/workspace/domain/workspace_feature.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/demo_outbox_journeys.dart';

const _letter = ReminderMailLetter(
  language: 'fr',
  subject: 'S',
  text: 'T',
  pdfBase64: 'JVBERi0=',
  fileName: 'f.pdf',
);

void main() {
  test('both e-mail features are on in the reference business', () {
    expect(
      demoFeaturesLeftOff,
      isNot(contains(WorkspaceFeature.reminderEmail)),
    );
    expect(demoFeaturesLeftOff, isNot(contains(WorkspaceFeature.invoiceEmail)));
  });

  test(
    'the Demo opens with one invoice and one reminder already sent',
    () async {
      await withDemoSession((f, outbox, c) async {
        final sent = outbox.sent;
        expect(sent.map((r) => r.kind), [
          DemoMailKind.invoice,
          DemoMailKind.reminder,
        ]);
        expect(sent.every((r) => r.invoiceId == sentInvoice), isTrue);
        expect(
          sent.first.at,
          f.money.invoices.firstWhere((i) => i.id == sentInvoice).issuedAt,
        );
        expect(
          sent.every((r) => r.recipient.endsWith('@example.test')),
          isTrue,
        );
        final lines = await c.read(reminderMailProvider).lines('ws-1', [
          sentInvoice,
          dueReminderInvoice,
          noAddressInvoice,
        ]);
        expect(lines[sentInvoice]!.sentAt(1), isNotNull);
        expect(lines[dueReminderInvoice]!.lastSend, isNull);
        expect(
          lines[noAddressInvoice]!.target.reason,
          ReminderMailUnavailable.noAddress,
        );
      });
    },
  );

  test('the owner records a reminder and an invoice', () async {
    expect(await reminderEmailJourney(), isTrue);
    expect(await invoiceEmailJourney(), isTrue);
  });

  test(
    'a customer without an address is refused in the server\'s words',
    () async {
      await withDemoSession((f, outbox, c) async {
        await expectLater(
          c
              .read(reminderMailProvider)
              .send(
                workspaceId: 'ws-1',
                invoiceId: noAddressInvoice,
                level: 1,
                attemptId: 'a1',
                letter: _letter,
              ),
          throwsA(
            isA<ReminderMailRefused>().having(
              (e) => e.message,
              'message',
              DemoOutbox.noAddressMessage,
            ),
          ),
        );
        await expectLater(
          c
              .read(invoiceMailProvider)
              .send(
                workspaceId: 'ws-1',
                invoiceId: noAddressInvoice,
                kind: InvoiceMailKind.first,
                attemptId: 'a2',
                letter: _letter,
              ),
          throwsA(isA<ReminderMailRefused>()),
        );
        final view = await c
            .read(invoiceMailProvider)
            .state('ws-1', noAddressInvoice);
        expect(view.available, isFalse);
        expect(view.reason, InvoiceMailUnavailable.noAddress);
        expect(outbox.sent.length, 2, reason: 'a refusal records nothing');
      });
    },
  );

  test('a send is once per level, and its attempt id replays it', () async {
    await withDemoSession((f, outbox, c) async {
      final mail = c.read(reminderMailProvider);
      Future<ReminderMailSend> send(String attempt, {int level = 1}) =>
          mail.send(
            workspaceId: 'ws-1',
            invoiceId: dueReminderInvoice,
            level: level,
            attemptId: attempt,
            letter: _letter,
          );
      final first = await send('r1');
      final again = await send('r1');
      expect(again.id, first.id);
      expect(outbox.sent.length, 3);
      await expectLater(send('r2'), throwsA(isA<ReminderMailRefused>()));
      expect((await send('r3', level: 2)).level, 2);

      final invoices = c.read(invoiceMailProvider);
      Future<InvoiceMailSend> sendInvoice(String attempt, InvoiceMailKind k) =>
          invoices.send(
            workspaceId: 'ws-1',
            invoiceId: sentInvoice,
            kind: k,
            attemptId: attempt,
            letter: _letter,
          );
      await expectLater(
        sendInvoice('i1', InvoiceMailKind.first),
        throwsA(isA<ReminderMailRefused>()),
      );
      expect(
        (await sendInvoice('i2', InvoiceMailKind.resend)).kind,
        InvoiceMailKind.resend,
      );
    });
  });

  test(
    'a paid invoice is not reminded, another business is not offered',
    () async {
      await withDemoSession((f, outbox, c) async {
        final mail = c.read(reminderMailProvider);
        await expectLater(
          mail.send(
            workspaceId: 'ws-1',
            invoiceId: 'demo-invoice-chiara',
            level: 1,
            attemptId: 'p1',
            letter: _letter,
          ),
          throwsA(isA<ReminderMailRefused>()),
        );
        final other = await mail.target('ws-2', dueReminderInvoice);
        expect(other.available, isFalse);
        expect(other.reason, ReminderMailUnavailable.featureOff);
      });
    },
  );

  test('two sessions never share an outbox', () async {
    await withDemoSession((f, outbox, c) async {
      await c
          .read(reminderMailProvider)
          .send(
            workspaceId: 'ws-1',
            invoiceId: dueReminderInvoice,
            level: 1,
            attemptId: 'x',
            letter: _letter,
          );
    });
    await withDemoSession((f, outbox, c) async {
      expect(outbox.sent.length, 2);
    });
  });
}
