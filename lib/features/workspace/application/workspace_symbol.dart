// SPDX-License-Identifier: AGPL-3.0-or-later
//
// A workspace's symbol: one or two letters on a colour. The pair is unique
// across workspaces (0378); a taken pair is an outcome the member acts on —
// another colour, other letters, or a photo — not a fault.
import '../domain/workspace_branding.dart';
import '../domain/workspace_repository.dart';

enum SymbolOutcome { saved, removed, taken, malformed }

class WorkspaceSymbols {
  const WorkspaceSymbols(this._workspaces);
  final WorkspaceRepository _workspaces;

  Future<SymbolOutcome> choose({
    required String workspaceId,
    required String text,
    required String colourHex,
  }) async {
    final letters = text.trim().toUpperCase();
    if (letters.isEmpty ||
        letters.runes.length > 2 ||
        !symbolColours.contains(colourHex.toUpperCase())) {
      return SymbolOutcome.malformed;
    }
    try {
      await _workspaces.setWorkspaceBranding(workspaceId, {
        BrandingKeys.symbolText: letters,
        BrandingKeys.symbolColor: colourHex.toUpperCase(),
      });
      // ignore: catch_no_st
    } on WorkspaceSymbolTaken {
      // trace-exempt: a stated outcome the member reads.
      return SymbolOutcome.taken;
    }
    // One mark at a time: a symbol replaces the photo.
    await _workspaces.clearWorkspaceEmblem(workspaceId);
    return SymbolOutcome.saved;
  }

  Future<SymbolOutcome> remove(String workspaceId) async {
    await _workspaces.setWorkspaceBranding(workspaceId, {
      BrandingKeys.symbolText: null,
      BrandingKeys.symbolColor: null,
    });
    return SymbolOutcome.removed;
  }
}
