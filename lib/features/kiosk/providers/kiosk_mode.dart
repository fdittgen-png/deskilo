// SPDX-License-Identifier: 0BSD
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'kiosk_mode.g.dart';

/// The gate decision for a kiosk account (field request): kiosk mode
/// never auto-loads — the person setting up the tablet confirms it or
/// rejects it and uses the app normally.
enum KioskModeDecision { pending, accepted, rejected }

/// Deliberately IN-MEMORY: the decision dies with the process, so once
/// kiosk mode is accepted the only way out is restarting the pad — and
/// every restart asks again, which is also how a rejected pad can be
/// turned back into a kiosk.
@Riverpod(keepAlive: true)
class KioskMode extends _$KioskMode {
  @override
  KioskModeDecision build() => KioskModeDecision.pending;

  void accept() => state = KioskModeDecision.accepted;

  void reject() => state = KioskModeDecision.rejected;
}
