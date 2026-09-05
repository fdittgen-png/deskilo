// SPDX-License-Identifier: 0BSD
//
// #886 — Settings → Personal information: the person's own identity as
// every document prints it.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/help/help_dot.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/trace/guarded.dart';
import '../../../../core/ui/app_snack.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../workspace/providers/workspace_providers.dart';
import '../../domain/personal_info.dart';
import '../../providers/profile_providers.dart';
import '../widgets/personal_info_form.dart';

class PersonalInfoScreen extends ConsumerStatefulWidget {
  const PersonalInfoScreen({super.key});

  @override
  ConsumerState<PersonalInfoScreen> createState() => _PersonalInfoScreenState();
}

class _PersonalInfoScreenState extends ConsumerState<PersonalInfoScreen> {
  bool _saving = false;

  Future<void> _save(PersonalInfo info) async {
    final l10n = AppLocalizations.of(context);
    setState(() => _saving = true);
    final ok = await runGuarded(
      context,
      domain: 'profile',
      message: 'personal information update failed',
      errorText:
          l10n?.workspaceGenericError ??
          'Something went wrong. Please try again.',
      action: () =>
          ref.read(profileRepositoryProvider).updatePersonalInfo(info),
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (!ok) return;
    ref.invalidate(myProfileProvider);
    AppSnack.success(
      context,
      l10n?.personalInfoSaved ?? 'Personal information saved',
    );
    if (context.canPop()) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final profile = ref.watch(myProfileProvider);
    final workspaceCountry =
        ref.watch(currentWorkspaceProvider).value?.countryCode ?? '';
    return Scaffold(
      appBar: AppBar(
        title: HelpDotTitle(
          l10n?.personalInfoTitle ?? 'Personal information',
          l10n?.helpTopicSettings ?? 'Settings & profile',
        ),
      ),
      body: profile.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text(
            l10n?.workspaceGenericError ??
                'Something went wrong. Please try again.',
          ),
        ),
        data: (p) => SingleChildScrollView(
          padding: AppSpacing.gutterAll,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: PersonalInfoForm(
                initial: p?.identity ?? PersonalInfo.empty,
                workspaceCountry: workspaceCountry,
                saving: _saving,
                onSave: _save,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
