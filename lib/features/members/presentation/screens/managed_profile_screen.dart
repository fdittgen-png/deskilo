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
import '../../../../core/trace/refusal_text.dart';
import '../../../../core/ui/app_snack.dart';
import '../../../../core/ui/inline_banner.dart';
import '../../../../core/ui/loading_view.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../profile/domain/personal_info.dart';
import '../../../reservations/providers/reservation_providers.dart';
import '../../../profile/presentation/widgets/personal_info_form.dart';
import '../../../workspace/providers/workspace_providers.dart';
import '../widgets/managed_access_editor.dart';
import '../../../workspace/domain/workspace_feature.dart';

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
    // #1561 — and the identity itself, or the member page it returns to
    // keeps printing the address that was just replaced.
    if (editing != null) ref.invalidate(managedIdentityProvider(editing));
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

  /// #1561 — THE form. It seeds its controllers in `initState`, and
  /// `update_managed_identity` (0161) replaces the whole stored row, so
  /// it is built only once [initial] is the identity being edited: a
  /// form opened on `PersonalInfo.empty` while the read is in flight
  /// saves blanks over a complete identity.
  Widget _form(
    AppLocalizations? l10n,
    PersonalInfo initial,
    String workspaceCountry,
  ) =>
      PersonalInfoForm(
        managed: true,
        key: ValueKey('managed-form-${widget.memberId}'),
        initial: initial,
        workspaceCountry: workspaceCountry,
        saving: _saving,
        intro: l10n?.managedProfileIntro ??
            'This person has no account yet. You book, invoice and '
                'manage for them; hand the profile over when they join.',
        onSave: _save,
      );

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final members = ref.watch(workspaceMembersProvider).value ?? const [];
    final existing = members.where((m) => m.id == widget.memberId).firstOrNull;
    final workspaceCountry =
        ref.watch(currentWorkspaceProvider).value?.countryCode ?? '';
    final editing = widget.memberId;
    // #915 — the identity comes from behind the access rule; #1561 — and
    // which answer the rule gave decides what this screen offers at all.
    final read =
        editing == null ? null : ref.watch(managedIdentityProvider(editing));
    final value = read?.value;
    final Widget slot;
    if (read == null) {
      slot = _form(l10n, PersonalInfo.empty, workspaceCountry);
    } else if (read.hasError && !read.isLoading) {
      slot = InlineBanner(
        icon: Icons.cloud_off_outlined,
        // A known refusal says so; anything else is a fault worth retrying.
        text: knownRefusalText(l10n, read.error!) ??
            l10n?.managedProfileIdentityUnavailable ??
            'These details could not be read, so there is nothing to '
                'edit yet. Nothing has been changed.',
        actionLabel: l10n?.commonRetry ?? 'Try again',
        onAction: () => ref.invalidate(managedIdentityProvider(editing!)),
      );
    } else if (value == null) {
      slot = const SizedBox(height: 160, child: LoadingView());
    } else if (value.refused) {
      slot = InlineBanner(
        icon: Icons.lock_outline,
        text: l10n?.refusalPermission ??
            'You do not have the permission for this. An owner of the '
                'space can grant it in Role management.',
      );
    } else {
      slot = _form(l10n, value.identity, workspaceCountry);
    }
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n?.managedProfileTitle ?? 'Managed profile'),
      ),
      body: SingleChildScrollView(
        padding: AppSpacing.gutterAll,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                slot,
                // #914 — who may administer this one, once the profile
                // exists to be administered.
                if (existing != null &&
                    ref
                        .watch(enabledFeaturesSyncProvider)
                        .contains(WorkspaceFeature.managedProfileAccess))
                  ManagedAccessEditor(member: existing),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
