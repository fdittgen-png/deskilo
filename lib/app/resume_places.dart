// SPDX-License-Identifier: AGPL-3.0-or-later
//
// A cold start opens where the account was when the app last ran: its
// personal destination, or its place in a workspace when it was in one —
// and then only when that workspace is still the one entered at start, on
// the same installation, still listed and with an active membership.
// Otherwise the personal destination opens. Both places are kept apart, so
// a start restored into a workspace still returns to the personal one.
//
// The places are read and written per account (resume_place_store.dart):
// the record names its owner and is never read for anyone else. A start is
// decided once per process, at the location the app opens on; a link the
// app was opened with is followed instead. Nothing is recorded before that
// decision, so the landing screen of a start never replaces the place it
// is about to restore. All of it belongs to the personal shell.
import 'dart:async';

import 'package:meta/meta.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../core/backend/operation_context.dart';
import '../core/storage/resume_place_store.dart';
import '../core/trace/trace_logger.dart';
import '../features/auth/providers/auth_providers.dart';
import '../features/me/domain/resume_places.dart';
import '../features/me/presentation/me_data_tab.dart' show MeDataView;
import '../features/me/presentation/me_shell.dart' show MeTab;
import '../features/me/providers/personal_return_providers.dart';
import '../features/me/providers/personal_shell_providers.dart';
import '../features/workspace/domain/member.dart';
import '../features/workspace/providers/workspace_providers.dart';
import 'entry_intent.dart';
import 'route_classes.dart';

part 'resume_places.g.dart';

bool _owns(ResumePlaces places, PersonalContext person) => places.belongsTo(
  issuer: person.identity.issuer,
  subject: person.identity.subject,
  home: person.homeInstallationId,
);

/// The signed-in account's places as the device kept them; null when there
/// are none, they are unreadable, or they are somebody else's.
@Riverpod(keepAlive: true)
Future<ResumePlaces?> storedResumePlaces(Ref ref) async {
  final personalAnswer = ref.watch(personalContextProvider.future);
  final store = ref.watch(resumePlaceStoreProvider);
  final person = await personalAnswer;
  if (person == null) return null;
  try {
    final places = ResumePlaces.decode(
      await store.read(person.personalLocalUserId),
    );
    return places != null && _owns(places, person) ? places : null;
  } on Object catch (e, st) {
    TraceLogger.instance.warn(
      'navigation',
      'resume places unreadable',
      error: e,
      stackTrace: st,
    );
    return null;
  }
}

/// Where a cold start goes: not yet known, nowhere ([location] null: the
/// app's own landing), or [location]. [personal] is the personal
/// destination kept for the return when [location] is in a workspace.
@immutable
class StartPlace {
  const StartPlace._({required this.pending})
    : location = null,
      personal = null;

  static const StartPlace waiting = StartPlace._(pending: true);
  static const StartPlace none = StartPlace._(pending: false);

  const StartPlace.at(String this.location, {this.personal}) : pending = false;

  final bool pending;
  final String? location;
  final String? personal;

  @override
  bool operator ==(Object other) =>
      other is StartPlace &&
      other.pending == pending &&
      other.location == location &&
      other.personal == personal;

  @override
  int get hashCode => Object.hash(pending, location, personal);
}

@Riverpod(keepAlive: true)
StartPlace startPlace(Ref ref) {
  if (!ref.watch(personalShellEnabledProvider)) return StartPlace.none;
  final stored = ref.watch(storedResumePlacesProvider);
  if (stored.hasError) return StartPlace.none;
  if (stored.isLoading) return StartPlace.waiting;
  final places = stored.value;
  if (places == null) return StartPlace.none;
  final personal = places.personal ?? kMeHome;
  final last = places.workspace;
  if (places.side != ResumeSide.workspace || last == null) {
    return StartPlace.at(personal);
  }
  return switch (_enterable(ref, last)) {
    null => StartPlace.waiting,
    false => StartPlace.at(personal),
    true => StartPlace.at(last.location, personal: places.personal),
  };
}

/// Whether [last] is the workspace entered at start and may still be
/// entered; null while that is not known yet.
bool? _enterable(Ref ref, WorkspaceResume last) {
  final context = ref.watch(workspaceContextProvider);
  if (context.hasError) return false;
  if (context.isLoading) return null;
  final target = context.value?.target;
  if (target == null ||
      target.installationId != last.installation ||
      target.networkId != last.network) {
    return false;
  }
  final listed = ref.watch(myWorkspacesProvider);
  if (listed.hasError) return false;
  if (listed.isLoading) return null;
  if (!(listed.value ?? const []).any((w) => w.id == target.workspaceId)) {
    return false;
  }
  final member = ref.watch(myMemberProvider);
  if (member.hasError) return false;
  if (member.isLoading) return null;
  final me = member.value;
  return me != null &&
      me.workspaceId == target.workspaceId &&
      me.status == MemberStatus.active;
}

bool _isLanding(Uri at) =>
    !at.hasQuery && (at.path == kDefaultHome || at.path == kMeHome);

/// The personal destination [at] belongs to: one of Me's five, with the
/// data view it shows; Me's home for a page under Overview.
String _destinationOf(Uri at) {
  for (final tab in MeTab.destinations.skip(1)) {
    if (at.path != tab.path && !at.path.startsWith('${tab.path}/')) continue;
    final view = MeDataView.values
        .where((v) => v.wire == at.queryParameters['view'])
        .firstOrNull;
    return tab == MeTab.data && view != null
        ? '${tab.path}?view=${view.wire}'
        : tab.path;
  }
  return MeTab.home.path;
}

/// Spends the start place once and keeps the account's places as the
/// person moves.
class ResumeKeeper {
  ResumeKeeper._(this._ref);

  final Ref _ref;
  bool _started = false;
  Uri? _at;
  ResumePlaces? _places;
  String? _written;

  /// Whether this process's start was decided.
  bool get started => _started;

  /// The router arrived at [location].
  void arrive(Uri location) {
    _at = location;
    if (!_started) {
      final start = _ref.read(startPlaceProvider);
      if (start.pending && _isLanding(location)) return;
      _start(start);
    }
    _keep();
  }

  void _settled(StartPlace start) {
    final at = _at;
    if (_started || start.pending || at == null) return;
    // A start that moves the person is spent on its arrival.
    if (start.location != null && start.location != '$at') return;
    _start(start);
    _keep();
  }

  void _start(StartPlace start) {
    _started = true;
    if (start.personal case final personal?) {
      _ref
          .read(personalReturnProvider)
          .leave(_ref.read(authStateProvider).value, Uri.parse(personal));
    }
  }

  void _keep() {
    final at = _at;
    if (!_started || at == null || !_ref.read(personalShellEnabledProvider)) {
      return;
    }
    final person = _ref.read(personalContextProvider).value;
    if (person == null) return;
    var places = _places;
    if (places == null || !_owns(places, person)) {
      // The account's own record first, or its other side is lost.
      final stored = _ref.read(storedResumePlacesProvider);
      if (stored.isLoading) return;
      places = stored.value;
      if (places == null || !_owns(places, person)) {
        places = ResumePlaces(
          issuer: person.identity.issuer,
          subject: person.identity.subject,
          home: person.homeInstallationId,
        );
      }
    }
    final next = _placed(places, at);
    if (next == null) return;
    _places = next;
    final record = next.encode();
    if (record == _written) return;
    _written = record;
    unawaited(_write(person.personalLocalUserId, record));
  }

  ResumePlaces? _placed(ResumePlaces places, Uri at) {
    if (ResumePlaces.isPersonal(at.path)) {
      return places.atPersonal(_destinationOf(at));
    }
    if (classifyRoute(at.path) != RouteClass.workspace) return null;
    final target = _ref.read(readyWorkspaceContextProvider)?.target;
    final location = EntryIntent.validatedLocation(at.path);
    if (target == null || location == null) return null;
    return places.atWorkspace(
      WorkspaceResume(
        installation: target.installationId,
        network: target.networkId,
        location: location,
      ),
    );
  }

  Future<void> _write(String account, String record) async {
    try {
      await _ref.read(resumePlaceStoreProvider).write(account, record);
    } on Object catch (e, st) {
      TraceLogger.instance.warn(
        'navigation',
        'resume places not kept',
        error: e,
        stackTrace: st,
      );
    }
  }
}

@Riverpod(keepAlive: true)
ResumeKeeper resumeKeeper(Ref ref) {
  final keeper = ResumeKeeper._(ref);
  ref
    ..listen(startPlaceProvider, (_, next) => keeper._settled(next))
    ..listen(readyWorkspaceContextProvider, (_, _) => keeper._keep())
    ..listen(storedResumePlacesProvider, (_, _) => keeper._keep());
  return keeper;
}

/// The location the app opens on goes where the account was last, once.
String? startRedirect(Ref ref, Uri requested) {
  if (ref.read(resumeKeeperProvider).started || !_isLanding(requested)) {
    return null;
  }
  final to = ref.read(startPlaceProvider).location;
  return to == null || to == '$requested' ? null : to;
}
