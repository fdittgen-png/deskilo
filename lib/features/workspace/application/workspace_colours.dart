// SPDX-License-Identifier: 0BSD
//
// #1289 S2 — the decision to give a space its own colour, out of the
// widget.
//
// ADR 0024's shape, the same as `WordingTerms` (#1277): the screen says
// what the owner asked for, this decides which write that is, and the
// repository performs it. Pure Dart, so the rules below are exercised
// without pumping a screen — the contrast measurement itself needs
// Flutter, so the caller passes it in ([BrandSeedCheck]), which also
// keeps ONE implementation of the check for the lint, the import and
// this screen.
import '../domain/workspace_branding.dart';
import '../domain/workspace_repository.dart';
import 'apply_brand_seed.dart';

/// What happened to a colour the owner chose.
sealed class ColourOutcome {
  const ColourOutcome();
}

/// Stored; the app now derives its themes from it.
class ColourApplied extends ColourOutcome {
  const ColourApplied(this.hex);
  final String hex;
}

/// Removed; the app is back to the product's own palette.
class ColourReset extends ColourOutcome {
  const ColourReset();
}

/// Not a colour: `#RRGGBB`, six digits, nothing else.
class ColourMalformed extends ColourOutcome {
  const ColourMalformed(this.text);
  final String text;
}

/// A colour the app could not make readable: [pair] is the first pair
/// that would fall below its floor. Nothing was written.
class ColourRefused extends ColourOutcome {
  const ColourRefused(this.pair);
  final String pair;
}

class WorkspaceColours {
  const WorkspaceColours(this._workspaces, this._check);
  final WorkspaceRepository _workspaces;
  final BrandSeedCheck _check;

  /// The workspace's brand seed.
  ///
  /// An empty or whitespace-only [text] is a RESET, not a blank colour —
  /// an owner who clears the box is saying "I have no colour of my own",
  /// the same statement as pressing Reset. Anything that is not
  /// `#RRGGBB` is refused as malformed rather than stored and rendered
  /// as black.
  Future<ColourOutcome> choose({
    required String workspaceId,
    required String text,
  }) async {
    if (text.trim().isEmpty) return reset(workspaceId: workspaceId);
    final argb = parseHexColor(text.trim());
    if (argb == null) return ColourMalformed(text.trim());
    final refusals = _check(argb);
    if (refusals.isNotEmpty) return ColourRefused(refusals.first);
    final hex = hexOfColor(argb);
    await _workspaces.setWorkspaceBranding(
      workspaceId,
      {BrandingKeys.seedColor: hex},
    );
    return ColourApplied(hex);
  }

  /// REMOVES the seed rather than storing the product's own colour as
  /// one: a stored copy would freeze this space against every future
  /// change to the product palette, with nothing on screen to say why.
  Future<ColourOutcome> reset({required String workspaceId}) async {
    await _workspaces.setWorkspaceBranding(
      workspaceId,
      {BrandingKeys.seedColor: null},
    );
    return const ColourReset();
  }
}
