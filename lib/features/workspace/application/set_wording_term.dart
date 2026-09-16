// SPDX-License-Identifier: 0BSD
//
// #1277 S3 — the decision to rename one of the product's words, out of
// the widget.
//
// ADR 0024 and `reservations/application/book_seat.dart` are the shape:
// `presentation/` says what the owner asked for, `application/` decides
// which write that is, `data/` performs it. Pure Dart — no Flutter, no
// `BuildContext`, no localization — so the rules below can be exercised
// without pumping a screen.
//
// It does not catch. A refusal from the server is information the owner
// needs verbatim: "unknown wording key legendFree" and "the wording must
// carry exactly the placeholders {}" are the server's own sentences, and
// swallowing them here to return a tidier type would throw away the only
// explanation there is.
import '../domain/workspace_repository.dart';

/// Renaming a term and resetting it are the SAME server call with the
/// text absent, which is what keeps "reset" from drifting into "store
/// the default". This type exists so a widget cannot express one while
/// meaning the other.
class WordingTerms {
  const WordingTerms(this._workspaces);

  final WorkspaceRepository _workspaces;

  /// The workspace's own word for [key] in [locale].
  ///
  /// An empty or whitespace-only [text] is a RESET, not a blank label:
  /// an owner who clears the box is saying "I have no word of my own",
  /// which is the same statement as pressing Reset. Sending the empty
  /// string instead would store a blank override and render nothing
  /// where the word belongs.
  Future<void> rename({
    required String workspaceId,
    required String locale,
    required String key,
    required String text,
  }) =>
      text.trim().isEmpty
          ? reset(workspaceId: workspaceId, locale: locale, key: key)
          : _workspaces.setLexiconTerm(workspaceId, locale, key, text.trim());

  /// REMOVES the override, rather than writing the product's own word
  /// back as one.
  ///
  /// Storing the default would freeze that word against every future
  /// product rewording — the space would keep saying "Checked in" long
  /// after the product had chosen better words, with nothing on screen
  /// to say why. `null` is what the server takes for exactly this.
  Future<void> reset({
    required String workspaceId,
    required String locale,
    required String key,
  }) =>
      _workspaces.setLexiconTerm(workspaceId, locale, key, null);
}
