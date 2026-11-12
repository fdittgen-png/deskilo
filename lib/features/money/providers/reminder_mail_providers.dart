// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3673 — reminders by e-mail: the server's side (overridable in tests and
// the demonstration, which sends no e-mail).
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/reminder_mail_commands.dart';
import '../data/supabase_reminder_mail.dart';
import '../domain/reminder_mail.dart';
import 'credit_providers.dart';

final reminderMailProvider = Provider<ReminderMail>(
  (ref) => SupabaseReminderMail(ref.watch(moneyClientProvider)),
);

final reminderMailCommandsProvider = Provider<ReminderMailCommands>(
  (ref) => ReminderMailCommands(ref.watch(reminderMailProvider)),
);
