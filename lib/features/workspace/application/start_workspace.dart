// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1449 — starting a workspace: the one place that says a creation is
// ONE request however many times it is sent.
//
// #1303 gave the server a replay rule — one workspace per request id —
// and the client side of it was a field on a wizard's State passed
// through to a repository call. Nothing stated the rule, so nothing
// could check it: the guarantee that a lost response does not leave two
// workspaces (and two dev/prod pairs) behind rested on a future editor
// noticing why that `final String _requestId` was final.
//
// The refusals were worse. `if (!_nameValid || !_whereValid) return;`
// and `if (code.isEmpty) return;` — both silent. A whole pasted
// invitation with no code in it looked exactly like a button that had
// not been pressed.
import '../../../core/backend/backend_settings.dart';
import '../../../core/i18n/currencies.dart';
import '../../../core/i18n/time_zones.dart';
import '../domain/invitation_answer.dart';
import '../domain/invite_uri.dart';
import '../domain/template_outline.dart';
import '../domain/template_preview.dart';
import '../domain/workspace.dart';
import '../domain/workspace_repository.dart';

/// What creating a workspace meant.
enum StartOutcome {
  /// No name. REFUSED — a workspace is chosen from a list by its name.
  unnamed,

  /// No currency or no timezone. REFUSED — every figure and every
  /// opening hour the space will ever print depends on these two, and
  /// there is no later moment when they are easier to supply.
  unplaced,

  /// The server already said this template cannot be applied here.
  /// REFUSED before the write, not after: #1303 applies the template in
  /// the SAME transaction as the creation, so sending it is not a
  /// creation that then fails to decorate itself — it is no creation at
  /// all.
  templateRefused,

  /// Created, or replayed onto the workspace the first attempt made.
  created,
}

/// #1652 — how far reading one invitation got.
enum InvitationCheckKind {
  /// Nothing usable in the text, or a link this build cannot read.
  unreadable,

  /// A link issued on another server: not sent anywhere from here.
  otherServer,

  /// This server answered the preview.
  answered,
}

/// What reading and checking one invitation found. Nothing is written
/// for any kind.
class InvitationCheck {
  const InvitationCheck(this.kind, this.invitation, {this.answer});
  final InvitationCheckKind kind;
  final InvitationDescriptor invitation;
  final InvitationAnswer? answer;
}

/// A workspace is chosen from a list by its name, so it needs one.
bool isNameable(String name) => name.trim().isNotEmpty;

/// #1636 — a currency the app can format and a zone the clock can
/// install. Three letters and any text used to pass: `EURO` failed on
/// the server, `Europe/Pairs` saved and silently ran on device time.
bool isPlaceable({required String currencyCode, required String timezone}) =>
    isKnownCurrency(currencyCode) && TimeZones.isKnown(timezone.trim());

/// A currency the workspace may bill in.
bool isKnownCurrency(String code) =>
    Currencies.selectable.contains(code.trim().toUpperCase());

/// Whether [outline] leaves the template usable.
///
/// A null outline is not yet known and does not refuse; the wizard asks
/// this to hold Create back, the command asks it to decide whether to
/// write — one sentence read twice.
bool templateUsable(TemplateOutline? outline) => !(outline?.refused ?? false);

/// Becoming an owner, or joining somebody else's space.
class WorkspaceStart {
  const WorkspaceStart(this._workspaces);

  final WorkspaceRepository _workspaces;

  /// What the chosen template would set up, and whether it may be — read
  /// from the field-level inspection (#1655): the outline inside it is
  /// the one `template_outline` answers, and an inspection that rejects
  /// the template (an unknown field, a denied value, a newer schema)
  /// refuses here too, naming the first problem, before Create.
  Future<TemplateOutline> outlineOf(String templateId) async {
    final inspection = await _workspaces.inspectWorkspaceTemplate(templateId);
    if (inspection.usable || inspection.outline.refused) return inspection.outline;
    final first = inspection.problems.firstOrNull;
    return TemplateOutline(
      compatibility: TemplateCompatibility.notSupported,
      reason: first == null ? inspection.status.name : '${first.problem}: ${first.path}',
      groups: const [],
    );
  }

  /// Creates the workspace, and says which outcome it was.
  ///
  /// [requestId] identifies the CREATION, not the attempt: the caller
  /// generates it once and sends the same one on every retry, so a
  /// failure whose response was merely lost replays onto the workspace
  /// that already exists instead of making a second one. Passing a
  /// fresh id per attempt is the bug this parameter exists to prevent,
  /// which is why it is required here and optional on the repository.
  ///
  /// Nothing is written for any outcome but [StartOutcome.created].
  Future<({StartOutcome outcome, String? workspaceId})> create({
    required String name,
    required String countryCode,
    required String currencyCode,
    required String timezone,
    required String requestId,
    WorkspaceEnvironment environment = WorkspaceEnvironment.development,
    bool withTwin = false,
    String? templateId,
    TemplateOutline? outline,
  }) async {
    if (!isNameable(name)) {
      return (outcome: StartOutcome.unnamed, workspaceId: null);
    }
    if (!isPlaceable(currencyCode: currencyCode, timezone: timezone)) {
      return (outcome: StartOutcome.unplaced, workspaceId: null);
    }
    if (templateId != null && !templateUsable(outline)) {
      return (outcome: StartOutcome.templateRefused, workspaceId: null);
    }
    final id = await _workspaces.createWorkspace(
      name: name.trim(),
      countryCode: countryCode,
      currencyCode: currencyCode.trim().toUpperCase(),
      timezone: timezone.trim(),
      environment: environment,
      withTwin: withTwin,
      requestId: requestId,
      templateId: templateId,
    );
    return (outcome: StartOutcome.created, workspaceId: id);
  }

  /// #1652 — reads [pasted] (a code, a link or a whole message) and asks
  /// THIS server what it would do, without writing. An invitation issued
  /// on another server is not sent here at all: the code is a secret of
  /// that server, and no code is ever tried on several.
  Future<InvitationCheck> check(String pasted,
      {required BackendEndpoint? active}) async {
    final invitation = InvitationReader.read(pasted);
    if (!invitation.usable) {
      return InvitationCheck(InvitationCheckKind.unreadable, invitation);
    }
    if (!invitation.belongsTo(active)) {
      return InvitationCheck(InvitationCheckKind.otherServer, invitation);
    }
    final answer = await _workspaces.previewInvitation(invitation.code);
    return InvitationCheck(InvitationCheckKind.answered, invitation,
        answer: answer);
  }

  /// The explicit Join: the existing admission path, once, on the server
  /// the invitation belongs to. A retry after a lost answer is the same
  /// call and answers already-member rather than joining twice.
  Future<InvitationAnswer> join(InvitationDescriptor invitation,
      {required BackendEndpoint? active}) {
    if (!invitation.usable || !invitation.belongsTo(active)) {
      throw StateError('the invitation does not belong to this server');
    }
    return _workspaces.joinByInvitation(invitation.code);
  }
}
