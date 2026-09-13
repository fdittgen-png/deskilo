// SPDX-License-Identifier: 0BSD
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/trace/trace_logger.dart';

part 'shell_bar_visibility.g.dart';

/// Whether the shell's bottom bar is swiped away — the full-screen view
/// (#1173, ported from the Sparkilo shell's own).
///
/// Sliding the bar out gives its whole strip back to the content, which
/// on the plan canvas is the difference between four rows of seats and
/// five. The raised Reserve button stays exactly where it is, so the one
/// piece of chrome the user needs to get the bar back is the one piece
/// still on screen.
///
/// ## Never a trap
///
/// A hidden bar with no affordance is a dead end, so there are three
/// independent ways back and one of them is not a gesture:
///
///  1. an upward drag anywhere in the bottom strip,
///  2. a long-press on the Reserve button,
///  3. that button's `Show navigation` semantics action, which switch
///     access and TalkBack reach without any gesture at all.
///
/// Tap keeps its current meaning everywhere, so nothing anybody does
/// today changes.
///
/// The choice persists across launches — a member who wants the room
/// should not have to re-hide it every morning — which is exactly why
/// the ways back have to be this redundant.

/// Seam for the two shell flags, so widget tests never reach a platform
/// channel (the `FrontCameraStore` shape).
abstract class ShellFlagStore {
  Future<bool> read();
  Future<void> write(bool value);
}

class PrefsShellFlagStore implements ShellFlagStore {
  const PrefsShellFlagStore(this.key);

  final String key;

  @override
  Future<bool> read() async =>
      (await SharedPreferences.getInstance()).getBool(key) ?? false;

  @override
  Future<void> write(bool value) async =>
      (await SharedPreferences.getInstance()).setBool(key, value);
}

@Riverpod(keepAlive: true)
ShellFlagStore shellBarHiddenStore(Ref ref) =>
    const PrefsShellFlagStore('shell_bar_hidden');

@Riverpod(keepAlive: true)
ShellFlagStore shellSwipeCoachStore(Ref ref) =>
    const PrefsShellFlagStore('shell_swipe_coach_seen');

/// The swiped-away state. Loading reads as SHOWN: the safe state, since
/// it is the one that carries its own way out.
@Riverpod(keepAlive: true)
class ShellBarHidden extends _$ShellBarHidden {
  @override
  Future<bool> build() => ref.watch(shellBarHiddenStoreProvider).read();

  /// Hide or show the bar, remembering the choice.
  Future<void> set(bool hidden) async {
    if (state.value == hidden) return;
    state = AsyncData(hidden);
    try {
      await ref.read(shellBarHiddenStoreProvider).write(hidden);
    } catch (e, st) {
      // The bar still moved; only the memory of it is lost.
      TraceLogger.instance.warn(
        'shell',
        'bar visibility not persisted',
        error: e,
        stackTrace: st,
      );
    }
  }

  /// Swap the state — the long-press and semantics paths.
  Future<void> toggle() => set(!(state.value ?? false));
}

/// Whether the swipe coach mark has been shown (#1173).
///
/// Once ever, like the tip carousels of #610: a gesture needs
/// introducing exactly one time, and a hint that returns is an
/// annoyance rather than help. Loading reads as SEEN, so a member can
/// never be shown a hint that cannot be remembered as dismissed.
@Riverpod(keepAlive: true)
class ShellSwipeCoachSeen extends _$ShellSwipeCoachSeen {
  @override
  Future<bool> build() => ref.watch(shellSwipeCoachStoreProvider).read();

  Future<void> markSeen() async {
    if (state.value == true) return;
    state = const AsyncData(true);
    try {
      await ref.read(shellSwipeCoachStoreProvider).write(true);
    } catch (e, st) {
      TraceLogger.instance.warn(
        'shell',
        'swipe coach flag not persisted',
        error: e,
        stackTrace: st,
      );
    }
  }
}

/// How the bar animates out, and back.
///
/// Long enough to read as the bar leaving rather than vanishing, short
/// enough that a member who hid it by accident is not waiting.
const Duration kShellBarHideDuration = Duration(milliseconds: 220);

/// Minimum fling speed that counts as a swipe, in logical pixels per
/// second. Below it the finger was resting, not throwing.
const double kShellBarSwipeVelocity = 200;
