// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1853 / #1867 — the one arbiter of the help surface.
//
// At most one kind of help speaks at a time, in this order:
//   1. a real blocker — something on screen the person must resolve
//      first (a refusal, a missing prerequisite) — outranks everything;
//   2. the active guide step of a guided task outranks advice;
//   3. tips and occasions (HelpHint carousels, the Get started card)
//      speak only when neither of the above does.
// The tip carousels and the Get started card read [helpSlotProvider] and
// stay silent while it is not [HelpSlot.tips]; the guide host shrinks to
// a "resolve this first" notice while it is [HelpSlot.blocker]. So two
// help bubbles never compete, and no second help framework is added.
// tankstellen#4480 later extracts this contract for every project.

import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'help_arbiter.g.dart';

/// Which kind of help the surface shows now.
enum HelpSlot { blocker, guide, tips }

class HelpArbiterState {
  const HelpArbiterState({this.blockers = const {}, this.guideActive = false});

  /// Ids of the blockers currently shown.
  final Set<String> blockers;
  final bool guideActive;

  HelpSlot get slot => blockers.isNotEmpty
      ? HelpSlot.blocker
      : guideActive
      ? HelpSlot.guide
      : HelpSlot.tips;
}

@Riverpod(keepAlive: true)
class HelpArbiter extends _$HelpArbiter {
  @override
  HelpArbiterState build() => const HelpArbiterState();

  /// A blocker with [id] is on screen; it outranks the guide and tips.
  void blockerShown(String id) {
    if (state.blockers.contains(id)) return;
    state = HelpArbiterState(
      blockers: {...state.blockers, id},
      guideActive: state.guideActive,
    );
  }

  void blockerCleared(String id) {
    if (!state.blockers.contains(id)) return;
    state = HelpArbiterState(
      blockers: {...state.blockers}..remove(id),
      guideActive: state.guideActive,
    );
  }

  /// Whether a guided task is being followed.
  void guide({required bool active}) {
    if (state.guideActive == active) return;
    state = HelpArbiterState(blockers: state.blockers, guideActive: active);
  }
}

/// What the single help surface shows now.
@riverpod
HelpSlot helpSlot(Ref ref) => ref.watch(helpArbiterProvider).slot;
