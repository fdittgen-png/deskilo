// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/context_l10n.dart';
import '../../../core/trace/guarded.dart';
import '../providers/directory_providers.dart';

class MemberEmploymentTile extends ConsumerWidget {
  const MemberEmploymentTile({
    super.key,
    required this.member,
    required this.editable,
  });
  final String member;
  final bool editable;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final value = ref.watch(employmentStatusProvider(member));
    if (value.hasError) {
      return TextButton(
        key: const ValueKey('member-employment-tile-retry'),
        onPressed: () => ref.invalidate(employmentStatusProvider(member)),
        child: Text(l.commonRetry),
      );
    }
    return SwitchListTile(
      key: const ValueKey('member-employment-tile-portal-employed'),
      value: value.value ?? false,
      title: Text(l.portalEmployed),
      subtitle: Text(
        l.portalEmploymentHint,
      ),
      onChanged: editable && value.hasValue
          ? (employed) async {
              final ok = await runGuarded(
                context,
                domain: 'members',
                message: 'save member employment failed',
                errorText:
                    l.portalActionFailed,
                action: () => ref
                    .read(accountContactActionsProvider())
                    .employment(member, employed: employed),
              );
              if (ok && context.mounted) {
                ref.invalidate(employmentStatusProvider(member));
              }
            }
          : null,
    );
  }
}
