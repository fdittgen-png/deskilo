// SPDX-License-Identifier: 0BSD
//
// #1289 / #1449 — choosing an emblem is a decision: what the file is
// allowed to become, and what to say when it may not.
//
// The re-encode itself needs the engine's codec, which this layer may
// not import, so the caller hands it in — the same shape as the brand
// seed's contrast check. What stays here is the rule: **nothing reaches
// storage as it arrived**, and a refusal has a reason the member reads.
import 'dart:typed_data';

import '../../../core/images/emblem_refusal.dart';
import '../domain/workspace_repository.dart';

/// Redraws [bytes] into the PNG that may be stored, or throws the
/// refusal. `emblemPngOf` is the implementation.
typedef EmblemReEncoder = Future<Uint8List> Function(Uint8List bytes);

/// Why an emblem was not stored, or that it was.
enum EmblemOutcome {
  stored,
  removed,

  /// The file is not an image this platform can decode.
  notAnImage,

  /// Re-encoded and still too heavy for a mark shown at 28 pixels.
  tooHeavy,
}

class Emblems {
  const Emblems(this._workspaces, this._reEncode);
  final WorkspaceRepository _workspaces;
  final EmblemReEncoder _reEncode;

  /// Stores [bytes] as the workspace's emblem, redrawn.
  ///
  /// The re-encoder's refusals are the two a member can act on — a file
  /// that is not an image, and an image too heavy once redrawn — so they
  /// come back as outcomes rather than exceptions. Anything else is a
  /// fault and is left to the caller's guard.
  Future<EmblemOutcome> choose({
    required String workspaceId,
    required Uint8List bytes,
  }) async {
    final Uint8List png;
    try {
      png = await _reEncode(bytes);
      // A stated refusal carries no fault, and its reason is the whole
      // payload: there is no stack worth keeping.
      // ignore: catch_no_st
    } on EmblemException catch (e) {
      // trace-exempt: a stated refusal, turned into the sentence the
      // member reads; the caller traces it.
      return switch (e.refusal) {
        EmblemRefusal.notAnImage => EmblemOutcome.notAnImage,
        EmblemRefusal.tooHeavy => EmblemOutcome.tooHeavy,
      };
    }
    await _workspaces.setWorkspaceEmblem(workspaceId, png);
    return EmblemOutcome.stored;
  }

  /// Removes it; a space with no emblem renders as one that never had
  /// an emblem.
  Future<EmblemOutcome> remove(String workspaceId) async {
    await _workspaces.clearWorkspaceEmblem(workspaceId);
    return EmblemOutcome.removed;
  }
}
