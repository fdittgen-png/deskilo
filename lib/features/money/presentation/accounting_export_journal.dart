// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2370 / #2365 — the generic journal export's words: the file is saved,
// or the person is told why there is none (no local book, or the roles to
// map first). The decision is `application/generic_journal_export.dart`.
import 'package:flutter/material.dart';

import '../../../core/l10n/context_l10n.dart';
import '../../../core/trace/guarded.dart';
import '../../../core/ui/app_snack.dart';
import '../application/generic_journal_export.dart';
import '../domain/book_profile.dart';

/// Builds the journal of [year] through [export] and hands it to [save].
Future<void> exportGenericJournal(
  BuildContext context,
  GenericJournalExport export, {
  required String workspaceId,
  required List<BookProfile> profiles,
  required int year,
  required Future<void> Function(String content) save,
}) async {
  GenericJournal? journal;
  final read = await runGuarded(
    context,
    domain: 'money',
    message: 'journal postings failed',
    action: () async => journal = await export.of(workspaceId, profiles, year),
  );
  if (!read || !context.mounted) return;
  final l10n = context.l10n;
  switch (journal) {
    case JournalFile(:final content):
      await save(content);
    case JournalNeedsLocalBook():
      AppSnack.error(context, l10n.journalNeedsLocalBook);
    case JournalBlocked(:final roles):
      AppSnack.error(context, l10n.journalBlocked(roles.join(', ')));
    case null:
      return;
  }
}
