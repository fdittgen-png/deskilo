// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1636 (0307) — "I'll do it later" on an optional setup section. The
// checklist's next step moves on; the section's state does not change,
// and the server drops the choice by itself once the section changes.
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../domain/local_setup.dart';
import '../domain/workspace_readiness.dart';
import '../providers/local_setup_providers.dart';

part 'set_readiness_aside.g.dart';

class ReadinessAside {
  const ReadinessAside(this._repository);
  final LocalSetupRepository _repository;

  /// Sets [section] aside for later. Returns false, writing nothing, for
  /// a section that cannot be set aside; a server refusal propagates.
  Future<bool> later(String workspaceId, ReadinessSection section) async {
    final code = readinessSectionCode(section.area);
    if (code == null || !section.canSetAside || section.acknowledged) {
      return false;
    }
    await _repository.acknowledgeSection(workspaceId, code);
    return true;
  }

  /// Takes [section] back, so it can be next again.
  Future<bool> undo(String workspaceId, ReadinessSection section) async {
    final code = readinessSectionCode(section.area);
    if (code == null || !section.acknowledged) return false;
    await _repository.clearAcknowledgement(workspaceId, code);
    return true;
  }
}

/// #1636 (0307) — setting readiness sections aside, and taking them back.
@riverpod
ReadinessAside readinessAside(Ref ref) =>
    ReadinessAside(ref.watch(localSetupRepositoryProvider));
