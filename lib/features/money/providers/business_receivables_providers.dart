// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4167 (A) -- Me › My businesses: the receivables of every business of this
// installation the person may read, one source each. A business answers, refuses
// (the person has no finance right there) or is unavailable, and each says so: a
// refusal or a failure is never a zero. Development spaces are test data and are
// not read here, so production and development never share a figure.
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/backend/context_client_providers.dart';
import '../../../core/backend/operation_context.dart';
import '../../../core/trace/trace_logger.dart';
import '../application/business_detail_loader.dart';
import '../data/supabase_business_payables_repository.dart';
import '../data/supabase_business_receivables_repository.dart';
import '../domain/business_payables.dart';
import '../domain/business_receivables.dart';

/// The production businesses of the person's own installation. None by default;
/// the composition (`businessWorkspacesFromApp`, lib/app) names them from the
/// person's workspaces and leaves the development spaces out.
final myBusinessWorkspacesProvider =
    FutureProvider.autoDispose<List<({String networkId, String id, String name})>>(
      (ref) async => const [],
      retry: (_, _) => null,
    );

/// The server read of a business's receivables, through the verified client of
/// the installation the person is signed in to.
final businessReceivablesRepositoryProvider =
    Provider<BusinessReceivablesRepository>(
      (ref) => SupabaseBusinessReceivablesRepository(
        ref.watch(personalClientProvider),
      ),
    );

/// The installation the person is signed in to: the identity half of every
/// business source. The Demo answers with its own.
final businessInstallationIdProvider = FutureProvider<String>(
  (ref) => ref.watch(installationIdReaderProvider)(
    ref.watch(personalClientProvider),
  ),
  retry: (_, _) => null,
);

/// One source per production business of the person; none is read for a
/// development space.
final myBusinessReceivablesProvider =
    FutureProvider.autoDispose<List<BusinessReceivablesSource>>((ref) async {
      final repository = ref.watch(businessReceivablesRepositoryProvider);
      final installation = await ref.watch(businessInstallationIdProvider.future);
      final all = await ref.watch(myBusinessWorkspacesProvider.future);
      return Future.wait([
        for (final w in all)
          _read(
            repository,
            WorkspaceTarget.stored(
              networkId: w.networkId,
              installationId: installation,
              workspaceId: w.id,
            ),
            w.name,
          ),
      ]);
    }, retry: (_, _) => null);

Future<BusinessReceivablesSource> _read(
  BusinessReceivablesRepository repository,
  WorkspaceTarget target,
  String name,
) async {
  try {
    return BusinessReceivablesAnswered(
      target,
      name,
      await repository.summary(target.workspaceId),
    );
  } on BusinessReceivablesRefusal catch (e, st) {
    TraceLogger.instance.log(TraceLevel.debug, 'money', 'business_receivables_providers: BusinessReceivablesRefusal handled', error: e, stackTrace: st);
    return BusinessReceivablesRefused(target, name);
  } on Object catch (e, st) {
    TraceLogger.instance.warn(
      'money',
      'the receivables of business ${target.workspaceId} could not be read',
      error: e,
      stackTrace: st,
    );
    return BusinessReceivablesUnavailable(target, name);
  }
}

/// The server reads of what a business has to pay.
final businessPayablesRepositoryProvider =
    Provider<BusinessPayablesRepository>(
      (ref) => SupabaseBusinessPayablesRepository(
        ref.watch(personalClientProvider),
      ),
    );

/// Each business's payables, one per production business, the two directions
/// each with its own outcome: a refusal or a failure of one never says anything
/// about the other, and neither is a zero.
final myBusinessPayablesProvider =
    FutureProvider.autoDispose<List<BusinessPayables>>((ref) async {
      final repository = ref.watch(businessPayablesRepositoryProvider);
      final installation = await ref.watch(businessInstallationIdProvider.future);
      final all = await ref.watch(myBusinessWorkspacesProvider.future);
      return Future.wait([
        for (final w in all)
          _readPayables(
            repository,
            WorkspaceTarget.stored(
              networkId: w.networkId,
              installationId: installation,
              workspaceId: w.id,
            ),
            w.name,
          ),
      ]);
    }, retry: (_, _) => null);

Future<BusinessPayables> _readPayables(
  BusinessPayablesRepository repository,
  WorkspaceTarget target,
  String name,
) async {
  final id = target.workspaceId;
  final (suppliers, members) = await (
    _section(id, 'suppliers', () => repository.supplierBalances(id)),
    _section(id, 'members', () => repository.memberReimbursements(id)),
  ).wait;
  return BusinessPayables(
    target: target,
    name: name,
    suppliers: suppliers,
    members: members,
  );
}

Future<PayablesSection<T>> _section<T>(
  String workspaceId,
  String direction,
  Future<T> Function() read,
) async {
  try {
    return PayablesAnswered(await read());
  } on BusinessPayablesRefusal catch (e, st) {
    TraceLogger.instance.log(TraceLevel.debug, 'money', 'business_receivables_providers: BusinessPayablesRefusal handled', error: e, stackTrace: st);
    return const PayablesRefused();
  } on Object catch (e, st) {
    TraceLogger.instance.warn(
      'money',
      'the $direction payables of business $workspaceId could not be read',
      error: e,
      stackTrace: st,
    );
    return const PayablesUnavailable();
  }
}

/// The paged reads behind the rows of My businesses.
final businessDetailLoaderProvider = Provider<BusinessDetailLoader>(
  (ref) => BusinessDetailLoader(
    () => ref.read(businessReceivablesRepositoryProvider),
    () => ref.read(businessPayablesRepositoryProvider),
  ),
);
