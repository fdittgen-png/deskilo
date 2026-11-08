// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3403 -- the workspace's own tax reference is not ready yet (its context is
// still being captured). Thrown by the helper a guarded action reads the
// reference through; `runGuarded` answers it with a sentence, so the person
// is told instead of facing a silent no-op.
class WorkspaceContextNotReady implements Exception {
  const WorkspaceContextNotReady();

  @override
  String toString() => 'workspace context not ready';
}
