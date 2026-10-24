// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2557 C3 — the own-data export of each workspace my personal account
// names, one source per workspace, each asked on its own host (ADR 0024:
// the decision lives here, the widget says what the person asked for).
//
// The person, the installation and the workspace are captured at the
// click: an answer that arrives after the signed-in account changed is
// dropped, never offered as the new account's file. A source that fails
// fails alone; the others and the personal part are not touched.
import '../../../core/trace/trace_logger.dart';
import '../domain/personal_workspace_refs.dart';
import '../domain/workspace_export.dart';

/// The workspaces whose own records I may export: every workspace my
/// account names with a relationship, in the order the home lists them.
/// A reference on my home with no relationship there, or one I left,
/// holds no record of mine to export.
List<WorkspaceExportSource> workspaceExportSourcesOf(
  PersonalWorkspaceRefs refs,
) => List.unmodifiable([
  for (final ref in refs.refs)
    if (!(ref.hostedHere && ref.status == null) &&
        ref.status != RefStatus.exited)
      WorkspaceExportSource(
        installationId: ref.installationId,
        workspaceId: ref.workspaceId,
        hostedHere: ref.hostedHere,
        label: ref.label,
      ),
]);

/// What asking one workspace for its export came to.
sealed class WorkspaceExportOutcome {
  const WorkspaceExportOutcome();
}

/// The host answered with the export: deliver [export] as a file.
final class WorkspaceExportReady extends WorkspaceExportOutcome {
  const WorkspaceExportReady(this.export);
  final WorkspaceExport export;
}

/// The host refused or did not answer; nothing was exported.
final class WorkspaceExportNotDone extends WorkspaceExportOutcome {
  const WorkspaceExportNotDone(this.failure);
  final WorkspaceExportFailure failure;
}

/// The signed-in account changed while the host answered: the answer
/// belongs to the account that asked, and is dropped.
final class WorkspaceExportSuperseded extends WorkspaceExportOutcome {
  const WorkspaceExportSuperseded();
}

/// Asks one workspace's host for my own records there.
class WorkspaceExportCommand {
  const WorkspaceExportCommand({required this.repository});

  final WorkspaceExportRepository repository;

  /// Asks [source]'s host; [principal] is the signed-in account now, read
  /// at the click and again at the answer.
  Future<WorkspaceExportOutcome> run(
    WorkspaceExportSource source, {
    required String? Function() principal,
  }) async {
    final asked = principal();
    if (asked == null) {
      return const WorkspaceExportNotDone(WorkspaceExportFailure.forbidden);
    }
    WorkspaceExportOutcome outcome;
    try {
      outcome = WorkspaceExportReady(await repository.export(source));
    } on WorkspaceExportRefused catch (e, st) {
      TraceLogger.instance.warn(
        'me',
        'a workspace export was refused',
        error: e,
        stackTrace: st,
      );
      outcome = WorkspaceExportNotDone(e.failure);
    } on Object catch (e, st) {
      TraceLogger.instance.warn(
        'me',
        'a workspace export did not come',
        error: e,
        stackTrace: st,
      );
      outcome = const WorkspaceExportNotDone(WorkspaceExportFailure.failed);
    }
    if (principal() != asked) return const WorkspaceExportSuperseded();
    return outcome;
  }
}
