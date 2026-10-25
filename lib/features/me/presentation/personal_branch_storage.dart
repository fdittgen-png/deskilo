// SPDX-License-Identifier: AGPL-3.0-or-later
//
// A destination page of the personal shell keeps its scroll offsets in the
// signed-in account's bucket for that destination, which outlives the shell:
// built again after a stay in a space, its lists open where they were left.
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/auth_providers.dart';
import '../providers/personal_return_providers.dart';

class PersonalBranchStorage extends ConsumerWidget {
  const PersonalBranchStorage({
    super.key,
    required this.branch,
    required this.child,
  });

  /// The destination, by its wire name.
  final String branch;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) => PageStorage(
    bucket: ref
        .watch(personalReturnProvider)
        .bucketFor(ref.watch(authStateProvider).value, branch),
    child: child,
  );
}
