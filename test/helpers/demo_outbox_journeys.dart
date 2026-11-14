// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3960 — the journeys of e-mail in the reference business, through the
// app's providers and commands on a Demo scope of their own: shared by the
// scenario checklist and the outbox test.
import 'package:deskilo/core/demo/data/money/demo_outbox.dart';
import 'package:deskilo/core/demo/demo_fixture.dart';
import 'package:deskilo/core/demo/demo_scope.dart';
import 'package:deskilo/features/money/application/invoice_mail_commands.dart';
import 'package:deskilo/features/money/application/reminder_mail_commands.dart';
import 'package:deskilo/features/money/domain/invoice_mail.dart';
import 'package:deskilo/features/money/domain/reminder_mail.dart';
import 'package:deskilo/features/money/providers/invoice_mail_providers.dart';
import 'package:deskilo/features/money/providers/reminder_mail_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Seeded: Ada's usage bill is overdue with no reminder yet (level 1 is due),
/// Bruno's bill was e-mailed when issued and reminded once, and Chiara has no
/// address on file.
const dueReminderInvoice = 'demo-usage-ada-b';
const sentInvoice = 'demo-invoice-bruno';
const noAddressInvoice = 'demo-usage-chiara-c';

const _letter = ReminderMailLetter(
  language: 'fr',
  subject: 'Document F-0001',
  text: 'A document for you',
  pdfBase64: 'JVBERi0=',
  fileName: 'document.pdf',
);

/// A fresh session of the Demo with its providers; [use] runs on it.
Future<T> withDemoSession<T>(
  Future<T> Function(
    DemoFixture fixture,
    DemoOutbox outbox,
    ProviderContainer container,
  )
  use,
) async {
  final fixture = DemoFixture.build();
  final container = ProviderContainer(overrides: demoOverrides(fixture));
  try {
    return await use(fixture, DemoOutbox.of(fixture), container);
  } finally {
    container.dispose();
  }
}

/// The owner e-mails the first reminder of the due bill: it is offered to
/// the customer's address, recorded with its document and language, and
/// answered as accepted; the customer without an address is refused.
Future<bool> reminderEmailJourney() =>
    withDemoSession((fixture, outbox, c) async {
      final mail = c.read(reminderMailCommandsProvider);
      final before = outbox.sent.length;
      final reach = await mail.reach('ws-1', dueReminderInvoice);
      final seeded = outbox.sent.any(
        (r) => r.kind == DemoMailKind.reminder && r.invoiceId == sentInvoice,
      );
      final answer = await mail.send(
        workspaceId: 'ws-1',
        invoiceId: dueReminderInvoice,
        level: 1,
        attemptId: 'scenario-reminder',
        letter: _letter,
      );
      final refused = await mail.send(
        workspaceId: 'ws-1',
        invoiceId: noAddressInvoice,
        level: 1,
        attemptId: 'scenario-reminder-none',
        letter: _letter,
      );
      final last = outbox.sent.last;
      return reach.target.available &&
          seeded &&
          answer is ReminderMailAnswered &&
          answer.send.state == ReminderMailState.accepted &&
          outbox.sent.length == before + 1 &&
          last.recipient == reach.target.recipient &&
          last.fileName == _letter.fileName &&
          last.language == 'fr' &&
          last.at == fixture.seededAt &&
          refused is ReminderMailNotSent;
    });

/// The owner e-mails an invoice: the page shows the earlier send of the
/// seeded bill, the new send is recorded with its date, and the customer
/// without an address is refused.
Future<bool> invoiceEmailJourney() =>
    withDemoSession((fixture, outbox, c) async {
      final mail = c.read(invoiceMailCommandsProvider);
      final earlier = await mail.view('ws-1', sentInvoice);
      final view = await mail.view('ws-1', dueReminderInvoice);
      final answer = await mail.send(
        workspaceId: 'ws-1',
        invoiceId: dueReminderInvoice,
        kind: InvoiceMailKind.first,
        attemptId: 'scenario-invoice',
        letter: _letter,
      );
      final after = await mail.view('ws-1', dueReminderInvoice);
      final refused = await mail.send(
        workspaceId: 'ws-1',
        invoiceId: noAddressInvoice,
        kind: InvoiceMailKind.first,
        attemptId: 'scenario-invoice-none',
        letter: _letter,
      );
      return earlier.lastLeft != null &&
          view.available &&
          view.sends.isEmpty &&
          answer is InvoiceMailAnswered &&
          answer.send.createdAt == fixture.seededAt &&
          after.latest?.id == 'scenario-invoice' &&
          refused is InvoiceMailNotSent;
    });
