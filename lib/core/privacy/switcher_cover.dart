// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2559 C1 -- the app-switcher privacy cover, one seam for iPhone and
// Android.
//
// When the app leaves the foreground the native runner lays an opaque,
// neutral cover over the whole window (iPhone: on `sceneWillResignActive`;
// Android: on pause, plus `setRecentsScreenshotEnabled(false)` on API 33+),
// so the app-switcher preview shows no name, balance or message. On return
// the cover stays until Dart says the CURRENT display frame has been drawn:
// a frame that belonged to another account or another workspace can never
// lift it.
//
// The Dart side speaks ONE method channel, `deskilo/switcher_cover`:
//
// | method | arguments | meaning |
// |---|---|---|
// | `setProtectedContext` | `protected: bool, frameEpoch: int` | what the window shows now, and whether leaving must cover it |
// | `foregroundReady` | `frameEpoch: int` | that frame is on screen; the cover may lift if it is still the current one |
//
// Only those two values cross the channel: never a name, an id or an
// account. The native side keeps the protection, the current frame epoch,
// whether the app is active and whether its cover is up -- nothing else.
// It starts protected with no frame, so a cover raised before Dart ever
// spoke stays until a real frame is acknowledged.
//
// This is exposure protection, not authentication and not a screenshot
// ban: no FLAG_SECURE, no blur, no animation.
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' show Provider;

import '../trace/trace_logger.dart';

/// Which side of the app a frame shows: the person's own home (P) or a
/// workspace host (W). [unknown] while the route is not known yet.
enum DisplaySourceRole { unknown, personal, workspace }

/// What is on screen, as the composition root captured it. It never
/// leaves Dart: the native side only ever sees the epoch the
/// [DisplayFrameClock] gives it.
@immutable
class DisplayFrame {
  const DisplayFrame({
    required this.personal,
    required this.role,
    this.target,
    this.signedOut = false,
    this.settled = true,
  });

  /// The frame before anything is known: protected, never acknowledged.
  const DisplayFrame.unknown()
    : personal = null,
      role = DisplaySourceRole.unknown,
      target = null,
      signedOut = false,
      settled = false;

  /// Who is signed in at the personal home -- its principal, or null.
  final String? personal;

  final DisplaySourceRole role;

  /// The displayed workspace target (installation and workspace), when
  /// [role] is a workspace.
  final String? target;

  /// Nobody is signed in: the sign-in screens carry nothing to hide.
  final bool signedOut;

  /// Whether the frame is resolved (data or a safe error) rather than
  /// still loading. Only a settled frame is acknowledged; a loading one
  /// may still be drawing the previous principal's content.
  final bool settled;

  /// Unknown and signed-in frames are protected; only a frame known to be
  /// signed out is not.
  bool get protected => !signedOut;

  @override
  bool operator ==(Object other) =>
      other is DisplayFrame &&
      other.personal == personal &&
      other.role == role &&
      other.target == target &&
      other.signedOut == signedOut &&
      other.settled == settled;

  @override
  int get hashCode => Object.hash(personal, role, target, signedOut, settled);
}

/// The monotonic display frame epoch. The same frame keeps its epoch; any
/// other frame -- another workspace, another account, the same one again
/// after a detour -- takes the next. It is the display's own counter, not
/// the personal context's account epoch: a workspace switch advances it
/// and leaves the account alone.
class DisplayFrameClock {
  DisplayFrame? _last;
  int _epoch = 0;

  int get epoch => _epoch;

  int epochFor(DisplayFrame frame) {
    if (frame != _last) {
      _last = frame;
      _epoch++;
    }
    return _epoch;
  }
}

/// The channel to the native cover.
class SwitcherCover {
  SwitcherCover({this.channel = const MethodChannel(channelName), bool? web})
    : _off = web ?? kIsWeb;

  /// A cover that never reaches a platform -- tests and Demo.
  SwitcherCover.inert()
    : channel = const MethodChannel(channelName),
      _off = true;

  static const String channelName = 'deskilo/switcher_cover';

  final MethodChannel channel;

  /// The web has no app-switcher hook; a browser thumbnail is out of
  /// reach (#2559 "Web limit").
  final bool _off;

  ({bool protected, int frameEpoch})? _sent;

  /// The last context that reached the platform.
  ({bool protected, int frameEpoch})? get sent => _sent;

  Future<void> setProtectedContext({
    required bool protected,
    required int frameEpoch,
  }) async {
    final next = (protected: protected, frameEpoch: frameEpoch);
    if (next == _sent) return;
    _sent = next;
    await _invoke('setProtectedContext', {
      'protected': protected,
      'frameEpoch': frameEpoch,
    });
  }

  Future<void> foregroundReady(int frameEpoch) =>
      _invoke('foregroundReady', {'frameEpoch': frameEpoch});

  Future<void> _invoke(String method, Map<String, Object> arguments) async {
    if (_off) return;
    try {
      await channel.invokeMethod<void>(method, arguments);
    } on MissingPluginException catch (e, st) {
      // A runner without the channel (desktop, a test binding): it has no
      // switcher preview to cover, which is not an error.
      TraceLogger.instance.warn(
        'switcher_cover',
        'switcher cover $method: no platform channel',
        error: e,
        stackTrace: st,
      );
    } on Object catch (e, st) {
      TraceLogger.instance.error(
        'switcher_cover',
        'switcher cover $method failed',
        error: e,
        stackTrace: st,
      );
    }
  }
}

/// Drives a [SwitcherCover] from the frames the composition root shows:
/// every new frame is announced, and a settled one is acknowledged once it
/// has been drawn -- after it first appears and after every return to the
/// foreground.
class SwitcherCoverController {
  SwitcherCoverController(this.cover, {Future<void> Function()? afterFrame})
    : _afterFrame = afterFrame ?? _endOfFrame;

  static Future<void> _endOfFrame() => WidgetsBinding.instance.endOfFrame;

  final SwitcherCover cover;
  final Future<void> Function() _afterFrame;
  final _clock = DisplayFrameClock();
  DisplayFrame _frame = const DisplayFrame.unknown();
  int? _epoch;

  /// The epoch of the frame on screen, or null before the first one.
  int? get frameEpoch => _epoch;

  Future<void> show(DisplayFrame frame) async {
    final epoch = _clock.epochFor(frame);
    final changed = epoch != _epoch;
    _frame = frame;
    _epoch = epoch;
    if (changed) {
      await cover.setProtectedContext(
        protected: frame.protected,
        frameEpoch: epoch,
      );
    }
    await _acknowledge();
  }

  /// The app is in the foreground again: the native cover waits for the
  /// current frame to be drawn.
  Future<void> resumed() => _acknowledge();

  Future<void> _acknowledge() async {
    final epoch = _epoch;
    if (epoch == null || !_frame.settled) return;
    await _afterFrame();
    // A newer frame replaced this one while it was drawing: its own
    // acknowledgement follows; this one would be stale.
    if (_epoch != epoch || !_frame.settled) return;
    await cover.foregroundReady(epoch);
  }
}

/// THE switcher cover of this app window.
final switcherCoverProvider = Provider<SwitcherCover>((ref) => SwitcherCover());
