// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1922 — the reminders of one invoice and their delivery evidence.
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../domain/reminder_evidence.dart';
import 'money_providers.dart';

part 'reminder_evidence_providers.g.dart';

@riverpod
Future<List<ReminderEvidence>> reminderEvidence(Ref ref, String invoiceId) =>
    ref.read(moneyRepositoryProvider).fetchReminderEvidence(invoiceId);
