// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #886 — Settings → Personal information: the person's own identity as
// every document prints it.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/help/help_anchors.dart';
import '../../../../core/help/help_dot.dart';
import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/privacy/recording_banner.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/time/clock.dart';
import '../../../../core/trace/guarded.dart';
import '../../../../core/ui/app_snack.dart';
import '../../../workspace/domain/workspace_field.dart';
import '../../../workspace/presentation/widgets/workspace_fields_section.dart';
import '../../../workspace/providers/workspace_fields_providers.dart';
import '../../../workspace/providers/workspace_providers.dart';
import '../../domain/personal_info.dart';
import '../../providers/profile_providers.dart';
import '../widgets/birthday_field.dart';
import '../widgets/personal_info_form.dart';

class PersonalInfoScreen extends ConsumerStatefulWidget {
  const PersonalInfoScreen({super.key});

  @override
  ConsumerState<PersonalInfoScreen> createState() => _PersonalInfoScreenState();
}

class _PersonalInfoScreenState extends ConsumerState<PersonalInfoScreen> {
  bool _saving = false;
  WorkspaceFieldsController? _fields;

  /// #3278 — the birthday being edited; null until the profile has loaded.
  DateTime? _birthday;
  bool _birthdayLoaded = false;

  @override
  void dispose() {
    _fields?.dispose();
    super.dispose();
  }

  Future<void> _save(PersonalInfo info) async {
    // #1514 — this form was prefilled from the recording seam.
    if (refusedWhileRecording(context, ref)) return;
    final l10n = context.l10n;
    setState(() => _saving = true);
    final ok = await runGuarded(
      context,
      domain: 'profile',
      message: 'personal information update failed',
      errorText:
          l10n.workspaceGenericError,
      action: () =>
          ref.read(profileRepositoryProvider).updatePersonalInfo(info),
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (!ok) return;
    ref.invalidate(myProfileProvider);

    // #3278 — the birthday saves through its own call, reported on its own.
    final before = ref.read(myProfileProvider).value?.birthday;
    if (_birthdayLoaded && _birthday != before) {
      final birthdaySaved = await runGuarded(
        context,
        domain: 'profile',
        message: 'birthday update failed',
        errorText: l10n.personalBirthdaySaveFailed,
        action: () =>
            ref.read(profileRepositoryProvider).updateBirthday(_birthday),
      );
      if (!mounted) return;
      if (!birthdaySaved) return;
      ref.invalidate(myProfileProvider);
    }

    // #1288 — the workspace's own questions save through their own call.
    // TWO server writes, so the second is reported on its own: a Save
    // made of several writes must not be shown as one that either
    // happened or did not.
    final answers = _fields?.answers;
    final member = ref.read(myMemberProvider).value;
    if (answers != null && answers.isNotEmpty && member != null) {
      final saved = await runGuarded(
        context,
        domain: 'profile',
        message: 'workspace questions update failed',
        // Its own sentence, not the generic one: the profile half
        // already saved, and a member has to be told which half did not.
        errorText: l10n.workspaceFieldsSaveFailed,
        action: () => ref.read(workspaceFieldsRepositoryProvider).saveAnswers(
              memberId: member.id,
              context: WorkspaceFieldContext.profile,
              answers: answers,
            ),
      );
      if (!mounted) return;
      if (saved) ref.invalidate(memberFieldAnswersProvider(member.id));
      if (!saved) return;
    }

    AppSnack.success(
      context,
      l10n.personalInfoSaved,
    );
    if (context.canPop()) context.pop();
  }

  /// The workspace's own questions, or nothing while the feature is off,
  /// no question is defined, or either side is still loading.
  Widget? _questions() {
    final fields = ref.watch(workspaceFieldsProvider).value;
    final member = ref.watch(myMemberProvider).value;
    final workspace = ref.watch(currentWorkspaceProvider).value;
    if (fields == null || member == null || workspace == null) return null;
    final asked = fieldsForContext(fields, WorkspaceFieldContext.profile);
    if (asked.isEmpty) return null;
    final answers = ref.watch(memberFieldAnswersProvider(member.id)).value;
    if (answers == null) return null;
    final controller = _fields ??= WorkspaceFieldsController(initial: answers);
    return WorkspaceFieldsSection(
      fields: asked,
      controller: controller,
      workspaceName: workspace.name,
      locale: Localizations.localeOf(context).languageCode,
      enabled: !_saving,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final profile = ref.watch(myProfileProvider);
    final workspaceCountry =
        ref.watch(currentWorkspaceProvider).value?.countryCode ?? '';
    return Scaffold(
      appBar: AppBar(
        title: HelpDotTitle(
          l10n.personalInfoTitle,
          l10n.helpTopicSettings,
          anchor: HelpAnchor.profilePersonalInfo,
        ),
      ),
      body: profile.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text(
            l10n.workspaceGenericError,
          ),
        ),
        data: (p) {
          if (!_birthdayLoaded) {
            _birthday = p?.birthday;
            _birthdayLoaded = true;
          }
          return SingleChildScrollView(
          padding: AppSpacing.gutterAll,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: PersonalInfoForm(
                initial: p?.identity ?? PersonalInfo.empty,
                workspaceCountry: workspaceCountry,
                saving: _saving,
                onSave: _save,
                extraSection: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    BirthdayField(
                      key: const ValueKey('personal-info-birthday-field'),
                      value: _birthday,
                      today: ref.read(clockProvider).now(),
                      enabled: !_saving,
                      onChanged: (d) => setState(() => _birthday = d),
                    ),
                    ?_questions(),
                  ],
                ),
              ),
            ),
          ),
        );
        },
      ),
    );
  }
}
