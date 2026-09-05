// SPDX-License-Identifier: 0BSD
//
// #887 — a managed member's identity, created or edited by an admin
// with THE identity form (PersonalInfoForm): the same fields, in the
// same words, as the person will see in their own settings once they
// claim the profile.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/trace/guarded.dart';
import '../../../../core/ui/app_snack.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../profile/domain/personal_info.dart';
import '../../../reservations/providers/reservation_providers.dart';
import '../../../profile/presentation/widgets/personal_info_form.dart';
import '../../../workspace/providers/workspace_providers.dart';

class ManagedProfileScreen extends ConsumerStatefulWidget {
  const ManagedProfileScreen({super.key, this.memberId});

  /// Null creates a new managed member; set edits that one's identity.
  final String? memberId;

  @override
  ConsumerState<ManagedProfileScreen> createState() =>
      _ManagedProfileScreenState();
}

class _ManagedProfileScreenState extends ConsumerState<ManagedProfileScreen> {
  bool _saving = false;

  Future<void> _save(PersonalInfo info) async {
    final l10n = AppLocalizations.of(context);
    final workspace = ref.read(currentWorkspaceProvider).value;
    if (workspace == null) return;
    setState(() => _saving = true);
    String? createdId;
    final repository = ref.read(workspaceRepositoryProvider);
    final editing = widget.memberId;
    final ok = await runGuarded(
      context,
      domain: 'workspace',
      message: 'managed profile save failed',
      errorText:
          l10n?.workspaceGenericError ??
          'Something went wrong. Please try again.',
      action: () async {
        if (editing == null) {
          createdId = await repository.createManagedMember(workspace.id, info);
        } else {
          await repository.updateManagedIdentity(editing, info);
        }
      },
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (!ok) return;
    ref.invalidate(workspaceMembersProvider);
    ref.invalidate(memberNamesProvider);
    AppSnack.success(
      context,
      editing == null
          ? (l10n?.managedProfileCreated ?? 'Managed profile created')
          : (l10n?.managedProfileSaved ?? 'Identity saved'),
    );
    if (createdId != null) {
      // Straight to the member page: the next step is the handover.
      context.pushReplacement('/member/$createdId');
    } else if (context.canPop()) {
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final members = ref.watch(workspaceMembersProvider).value ?? const [];
    final existing = members.where((m) => m.id == widget.memberId).firstOrNull;
    final workspaceCountry =
        ref.watch(currentWorkspaceProvider).value?.countryCode ?? '';
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n?.managedProfileTitle ?? 'Managed profile'),
      ),
      body: SingleChildScrollView(
        padding: AppSpacing.gutterAll,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: PersonalInfoForm(
              // Rebuilt when the member arrives so the fields prefill.
              key: ValueKey('managed-form-${existing?.id}'),
              initial: existing?.managedIdentity ?? PersonalInfo.empty,
              workspaceCountry: workspaceCountry,
              saving: _saving,
              intro:
                  l10n?.managedProfileIntro ??
                  'This person has no account yet. You book, invoice and '
                      'manage for them; hand the profile over when they join.',
              onSave: _save,
            ),
          ),
        ),
      ),
    );
  }
}
