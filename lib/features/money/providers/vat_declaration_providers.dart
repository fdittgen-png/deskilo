// SPDX-License-Identifier: 0BSD
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../workspace/providers/workspace_providers.dart';
import '../domain/vat_declaration.dart';
import 'money_providers.dart';

part 'vat_declaration_providers.g.dart';

/// The workspace's VAT declarations (0107), newest period first. Own
/// file so money_providers.dart stays at its file_length snapshot.
@riverpod
Future<List<VatDeclaration>> vatDeclarations(Ref ref) async {
  final workspace = await ref.watch(currentWorkspaceProvider.future);
  if (workspace == null) return const [];
  return ref
      .watch(moneyRepositoryProvider)
      .fetchVatDeclarations(workspace.id);
}
