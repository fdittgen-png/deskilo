// SPDX-License-Identifier: AGPL-3.0-or-later

/// [text] with a token spliced in, and where the caret goes afterwards.
typedef TokenInsertion = ({String text, int caret});

/// Splices [token] into [text] at [caret] (the end when [caret] is null or
/// outside the text) and puts the caret right after it. [token] is
/// inserted verbatim: what makes a token valid is the host's decision.
TokenInsertion insertTokenAt(String text, String token, {int? caret}) {
  final at = (caret == null || caret < 0 || caret > text.length)
      ? text.length
      : caret;
  return (
    text: text.substring(0, at) + token + text.substring(at),
    caret: at + token.length,
  );
}
