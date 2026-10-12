// SPDX-License-Identifier: AGPL-3.0-or-later
part of 'directory_screen.dart';

// #2386 — part 1 of _DirectoryScreenState, split out of directory_screen.dart so no
// file holds the whole class.
extension _DirectoryScreenStatePart1 on _DirectoryScreenState {

  void _armPresence({required bool visible}) {
    if (visible == (_presenceTimer != null)) return;
    _presenceTimer?.cancel();
    _presenceTimer = visible
        ? Timer.periodic(PresenceRules.heartbeatInterval, (_) {
            if (!mounted) return;
            ref.invalidate(memberProfilesProvider);
            _update(() {});
          })
        : null;
  }

  Future<void> _refresh(WidgetRef ref) async {
    ref
      ..invalidate(workspaceMembersProvider)
      ..invalidate(memberNamesProvider)
      ..invalidate(memberEmailsProvider)
      ..invalidate(memberProfilesProvider)
      ..invalidate(reservationsForMonthProvider)
      ..invalidate(directoryReservationsProvider)
      ..invalidate(targetNamesProvider);
    await ref.read(workspaceMembersProvider.future);
  }

  /// Opens a member's booking through the shared helper, which owns the
  /// "Show on plan" jump (#422 — opening the sheet directly discarded
  /// the popped target and the button silently did nothing here).
  void _openReservation(BuildContext context, Reservation reservation) {
    unawaited(showReservationDetail(context, ref, reservation));
  }

  Future<void> _openLink(BuildContext context, WidgetRef ref, Uri uri) async {
    final l10n = context.l10n;
    try {
      final handled = await ref.read(linkLauncherProvider)(uri);
      if (!handled) throw StateError('no handler for $uri');
    } on Object catch (e, st) {
      debugPrint('whatsapp launch failed: $e\n$st');
      TraceLogger.instance.error(
        'members',
        'whatsapp launch failed',
        error: e,
        stackTrace: st,
      );
      if (!context.mounted) return;
      AppSnack.error(
        context,
        l10n.workspaceGenericError,
      );
    }
  }
}
