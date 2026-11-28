// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4518 -- the contacts, the contact roles and the terms of the suppliers of the current business. The Demo overrides the repository.
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/supplier_contact_commands.dart';
import '../data/supabase_supplier_contact_repository.dart';
import '../domain/supplier_contact.dart';
import 'credit_providers.dart' show moneyClientProvider;

export '../data/in_memory_supplier_contact_repository.dart' show InMemorySupplierContacts;

/// The repository of the contacts. The Demo overrides it.
final supplierContactRepositoryProvider = Provider<SupplierContactRepository>(
  (ref) => SupabaseSupplierContactRepository(ref.watch(moneyClientProvider)),
);

/// What a person does to the contacts of a supplier, the roles and the terms.
final supplierContactCommandsProvider = Provider<SupplierContactCommands>(
  (ref) => SupplierContactCommands(ref.watch(supplierContactRepositoryProvider)),
);

/// Every role of [workspaceId], active and retired, in the business's order.
final supplierContactRolesProvider = FutureProvider.autoDispose.family<List<SupplierContactRole>, String>(
  (ref, workspaceId) => ref.watch(supplierContactCommandsProvider).roles(workspaceId),
  retry: (_, _) => null,
);

typedef SupplierKey = ({String workspaceId, String supplierId});

/// Every contact of one supplier, active and retired.
final supplierContactsProvider = FutureProvider.autoDispose.family<List<SupplierContact>, SupplierKey>(
  (ref, key) => ref.watch(supplierContactCommandsProvider).contacts(key.workspaceId, key.supplierId),
  retry: (_, _) => null,
);

/// What one supplier agreed once.
final supplierTermsProvider = FutureProvider.autoDispose.family<SupplierTerms, SupplierKey>(
  (ref, key) => ref.watch(supplierContactCommandsProvider).terms(key.workspaceId, key.supplierId),
  retry: (_, _) => null,
);
