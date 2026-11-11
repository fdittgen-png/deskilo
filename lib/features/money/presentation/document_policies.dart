// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/state/policy_read.dart';
import '../providers/money_providers.dart';

/// #3742 — the policies a document is drawn from (the owner's template and
/// reminder rules), read before it is: a failure is asked again, a read
/// still running is awaited. Every action that prints, shares, previews or
/// sends calls this first, under its print guard.
Future<void> readDocumentPolicies(WidgetRef ref) async {
  await readPolicy(ref, invoicePdfTemplateProvider, invoicePdfTemplateProvider.future);
  await readPolicy(ref, dunningRulesProvider, dunningRulesProvider.future);
}
