// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2211 — Me › Me: the explicit publish step of the public-profile tier. A
// signed-out visitor sees nothing of me until I switch this on, and then only
// my name, profession and bio. Switching on asks first and names the
// audience; switching off withdraws at once.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/context_l10n.dart';
import '../../../core/trace/guarded.dart';
import '../../../core/ui/app_snack.dart';
import '../../auth/providers/auth_providers.dart';
import '../providers/me_providers.dart';
import '../providers/public_profile_providers.dart';

class PublicProfileTile extends ConsumerWidget {
  const PublicProfileTile({super.key});

  Future<void> _set(BuildContext context, WidgetRef ref, bool publish) async {
    final l10n = context.l10n;
    if (publish) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (dialog) => AlertDialog(
          title: Text(
            l10n.publicProfilePublishTitle,
          ),
          content: Text(
            l10n.publicProfilePublishBody,
          ),
          actions: [
            TextButton(
              key: const ValueKey('public-profile-cancel'),
              onPressed: () => Navigator.of(dialog).pop(false),
              child: Text(MaterialLocalizations.of(dialog).cancelButtonLabel),
            ),
            FilledButton(
              key: const ValueKey('public-profile-confirm'),
              onPressed: () => Navigator.of(dialog).pop(true),
              child: Text(l10n.publicProfilePublishAction),
            ),
          ],
        ),
      );
      if (ok != true || !context.mounted) return;
    }
    final done = await runGuarded(
      context,
      domain: 'me',
      message: 'publish public profile failed',
      action: () => ref.read(meActionsProvider).publishProfile(publish),
    );
    if (done) ref.invalidate(myPublicProfileProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final published = ref.watch(myPublicProfileProvider).value ?? false;
    final me = ref.watch(authStateProvider).value;
    final link = me == null ? null : publicProfileLink(me);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SwitchListTile(
          key: const ValueKey('visibility-public-profile'),
          secondary: const Icon(Icons.public),
          title: Text(l10n.publicProfileTitle),
          subtitle: Text(
            published
                ? (l10n.publicProfileOn)
                : (l10n.publicProfileOff),
          ),
          value: published,
          onChanged: (v) => _set(context, ref, v),
        ),
        if (published && link != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(72, 0, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: SelectableText(
                    link,
                    key: const ValueKey('public-profile-link'),
                    maxLines: 1,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
                IconButton(
                  key: const ValueKey('public-profile-copy'),
                  tooltip: l10n.publicProfileCopy,
                  icon: const Icon(Icons.copy_outlined),
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: link));
                    if (context.mounted) {
                      AppSnack.success(
                        context,
                        l10n.publicProfileCopied,
                      );
                    }
                  },
                ),
              ],
            ),
          ),
      ],
    );
  }
}
