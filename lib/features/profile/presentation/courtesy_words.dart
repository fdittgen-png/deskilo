// SPDX-License-Identifier: 0BSD
//
// #912 — the courtesy title in the reader's language.
//
// The choice is stored as a code, never as a word: a document is read in
// the language its reader asked for, and a French member's invoice sent
// to a German accountant must still greet him as the seller's template
// says. So the word is resolved at render time, here, once.
import '../../../l10n/app_localizations.dart';
import '../domain/personal_info.dart';

/// The title as [l10n] says it — '' for [Courtesy.none], which prints
/// the name on its own.
String courtesyWord(AppLocalizations? l10n, Courtesy courtesy) =>
    switch (courtesy) {
      Courtesy.none => '',
      Courtesy.mr => l10n?.courtesyMr ?? 'Mr',
      Courtesy.mrs => l10n?.courtesyMrs ?? 'Ms',
    };

/// What the picker offers, including the honest "none".
String courtesyOptionLabel(AppLocalizations? l10n, Courtesy courtesy) =>
    courtesy == Courtesy.none
        ? (l10n?.courtesyNone ?? 'None')
        : courtesyWord(l10n, courtesy);
