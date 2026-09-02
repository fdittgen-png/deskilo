// SPDX-License-Identifier: 0BSD
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/trace/trace_logger.dart';
import '../../workspace/domain/member.dart';
import '../../workspace/providers/workspace_providers.dart';
import '../domain/invoice.dart';
import '../domain/invoicing_wizard.dart';
import 'money_providers.dart';

part 'invoicing_wizard_providers.g.dart';

/// #827 — what every active member would be invoiced for [period], ALL
/// kinds (the wizard narrows to its run's kind). A member whose preview
/// fails is left out and traced, never a blocked run.
@riverpod
Future<Map<String, ({List<InvoiceLine> lines, int totalCents})>>
    wizardPreviews(Ref ref, String period) async {
  final workspace = await ref.watch(currentWorkspaceProvider.future);
  if (workspace == null) return const {};
  final members = await ref.watch(workspaceMembersProvider.future);
  final repo = ref.read(moneyRepositoryProvider);
  final out = <String, ({List<InvoiceLine> lines, int totalCents})>{};
  await Future.wait([
    for (final m in members)
      if (m.status == MemberStatus.active && !m.isKiosk)
        () async {
          try {
            out[m.id] = await repo.previewInvoice(
              workspaceId: workspace.id,
              memberId: m.id,
              period: period,
            );
          } catch (e, st) {
            TraceLogger.instance.warn('money', 'wizard preview failed',
                error: e, stackTrace: st);
          }
        }(),
  ]);
  return out;
}

/// #827 — the wizard's session: the run, the step, the tally. Kept
/// alive so a sheet opened from a step (a match, a settlement) returns
/// to the same place with the same numbers.
@Riverpod(keepAlive: true)
class InvoicingWizardController extends _$InvoicingWizardController {
  @override
  WizardState build() => const WizardState();

  /// A fresh run: step one, an empty tally.
  void start(WizardRun run) => state = WizardState(run: run);

  void setRun(WizardRun run) => state = state.copyWith(run: run);

  void goTo(WizardStep step) => state = state.copyWith(
        step: step,
        visited: {...state.visited, step},
      );

  void next() {
    final i = WizardStep.values.indexOf(state.step);
    if (i + 1 < WizardStep.values.length) goTo(WizardStep.values[i + 1]);
  }

  void back() {
    final i = WizardStep.values.indexOf(state.step);
    if (i > 0) goTo(WizardStep.values[i - 1]);
  }

  /// Counts one more of something the person just did.
  void bump(WizardTally Function(WizardTally tally) change) =>
      state = state.copyWith(tally: change(state.tally));
}
