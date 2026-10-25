// SPDX-License-Identifier: AGPL-3.0-or-later
//
// The destructive workspace reset (0039) unlocks only on a typed phrase.
//
// Pure Dart.
library;

/// Whether [typed] is the confirmation [phrase]: surrounding spaces and
/// letter case do not matter, every other character does.
bool resetPhraseMatches(String typed, String phrase) =>
    typed.trim().toLowerCase() == phrase.toLowerCase();
