// SPDX-License-Identifier: 0BSD
//
// The editor behind one validation rule. It lived inside
// validation_settings_screen.dart until #840 added the chained-validation
// switches and pushed that file past its budget; the screen keeps the
// list and the summaries, this file keeps the form.
import 'package:flutter/material.dart';

import '../../../../core/help/help_dot.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/validation_policy.dart';
import '../../domain/workspace_event.dart';
import 'validation_scope_picker.dart';

/// One pickable validator: the id the policy stores, and the name shown.
typedef AdminChoice = ({String id, String name});

/// Edits one policy row. Pops the edited [ValidationPolicy] on save, null
/// on cancel. Save is blocked (with a message) when the required count can
/// never be reached by the eligible pool — owners + eligible admins, plus
/// one for the subject's own accept on admin-initiated events.
class PolicyEditorSheet extends StatefulWidget {
  const PolicyEditorSheet({
    super.key,
    required this.title,
    required this.initial,
    required this.admins,
    required this.people,
    required this.ownerCount,
    required this.scopesOn,
    required this.chainOn,
  });

  final String title;
  final ValidationPolicy initial;
  final List<AdminChoice> admins;

  /// #732 — every active non-owner, for the LISTED scope.
  final List<AdminChoice> people;
  final int ownerCount;
  final bool scopesOn;

  /// #840 — the owner exception and one-at-a-time asking.
  final bool chainOn;

  @override
  State<PolicyEditorSheet> createState() => PolicyEditorSheetState();
}

class PolicyEditorSheetState extends State<PolicyEditorSheet> {
  static const _maxRequired = 10;

  late int _requiredCount = widget.initial.requiredCount.clamp(1, _maxRequired);
  late bool _adminsMayValidate = widget.initial.adminsMayValidate;
  late bool _ownerRequired = widget.initial.ownerRequired;

  /// #732 — 'admins' | 'listed' | 'members'; without the feature the
  /// rule reads as 'admins' whatever is stored.
  late String _scope =
      widget.scopesOn ? widget.initial.validatorScope : 'admins';
  late final Set<String> _selectedPeople = {
    for (final id in widget.initial.eligibleAdminIds)
      if (widget.people.any((a) => a.id == id)) id,
  };

  /// #629 — only the reservation_delete row offers these.
  late bool _autoValidateAdmin = widget.initial.autoValidateAdmin;
  late bool _autoValidateOwner = widget.initial.autoValidateOwner;

  /// #840 — off unless the workspace turned the feature on AND said so
  /// on this rule: a stored true with the feature off never applies.
  late bool _ownerMaySelfValidate =
      widget.chainOn && widget.initial.ownerMaySelfValidate;
  late bool _sequential = widget.chainOn && widget.initial.sequential;

  /// The DELIBERATE exception to "nobody validates their own event"
  /// (0086) is scoped to booking deletions; every other card hides it.
  bool get _offersAutoValidation =>
      widget.initial.eventType == EventType.reservationDelete.dbName;

  /// Empty = all admins. Stored ids of members no longer pickable are
  /// dropped so the pool math below never counts ghosts.
  late final Set<String> _selectedAdminIds = {
    for (final id in widget.initial.eligibleAdminIds)
      if (widget.admins.any((a) => a.id == id)) id,
  };

  bool _notEnough = false;

  /// Distinct members who could contribute an accept under the current
  /// switches (mirrors respond_to_event eligibility, migration 0017).
  int get _poolSize =>
      widget.ownerCount +
      switch (_scope) {
        'members' => widget.people.length,
        'listed' => _selectedPeople.length,
        _ => !_adminsMayValidate
            ? 0
            : _selectedAdminIds.isEmpty
                ? widget.admins.length
                : _selectedAdminIds.length,
      };

  void _save() {
    // +1: on admin-initiated events the subject's accept counts too.
    if (_requiredCount > _poolSize + 1) {
      setState(() => _notEnough = true);
      return;
    }
    Navigator.of(context).pop(
      widget.initial.copyWith(
        requiredCount: _requiredCount,
        adminsMayValidate: _adminsMayValidate,
        eligibleAdminIds: switch (_scope) {
          'listed' => _selectedPeople.toList()..sort(),
          'members' => const [],
          _ => _adminsMayValidate
              ? (_selectedAdminIds.toList()..sort())
              : const [],
        },
        validatorScope: _scope,
        ownerRequired: _ownerRequired,
        autoValidateAdmin: _offersAutoValidation && _autoValidateAdmin,
        autoValidateOwner: _offersAutoValidation && _autoValidateOwner,
        ownerMaySelfValidate: widget.chainOn && _ownerMaySelfValidate,
        sequential: widget.chainOn && _sequential,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.lg,
            AppSpacing.lg,
            AppSpacing.sm,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(widget.title, style: theme.textTheme.titleLarge),
              const SizedBox(height: 8),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: HelpDotTitle(
                  l10n?.validationRequiredCount ?? 'Required validations',
                  l10n?.helpHintValidationTopic ?? 'confirmations',
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.remove),
                      onPressed: _requiredCount > 1
                          ? () => setState(() {
                                _requiredCount--;
                                _notEnough = false;
                              })
                          : null,
                    ),
                    Text(
                      '$_requiredCount',
                      style: theme.textTheme.titleMedium,
                    ),
                    IconButton(
                      icon: const Icon(Icons.add),
                      onPressed: _requiredCount < _maxRequired
                          ? () => setState(() {
                                _requiredCount++;
                                _notEnough = false;
                              })
                          : null,
                    ),
                  ],
                ),
              ),
              // #732 — who validates: the scope, then the persons.
              if (widget.scopesOn)
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Expanded(
                    child: ValidationScopePicker(
                      scope: _scope,
                      people: [
                        for (final p in widget.people) (id: p.id, name: p.name)
                      ],
                      selected: _selectedPeople,
                      onScope: (v) => setState(() {
                        _scope = v;
                        _notEnough = false;
                      }),
                      onToggle: (id, selected) => setState(() {
                        selected
                            ? _selectedPeople.add(id)
                            : _selectedPeople.remove(id);
                        _notEnough = false;
                      }),
                    ),
                  ),
                  HelpDot(l10n?.helpHintMembersTip4Topic ?? 'Role management'),
                ]),
              if (_scope == 'admins')
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: HelpDotTitle(
                  l10n?.validationAdminsMay ?? 'Admins may validate',
                  l10n?.helpHintValidationTopic ?? 'confirmations',
                ),
                subtitle: _adminsMayValidate
                    ? null
                    : Text(l10n?.validationOwnerOnly ?? 'Owner only'),
                value: _adminsMayValidate,
                onChanged: (value) => setState(() {
                  _adminsMayValidate = value;
                  _notEnough = false;
                }),
              ),
              if (_scope == 'admins' && _adminsMayValidate)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      FilterChip(
                        label: Text(l10n?.validationAllAdmins ?? 'All admins'),
                        selected: _selectedAdminIds.isEmpty,
                        onSelected: (_) => setState(() {
                          _selectedAdminIds.clear();
                          _notEnough = false;
                        }),
                      ),
                      for (final admin in widget.admins)
                        FilterChip(
                          label: Text(admin.name),
                          selected: _selectedAdminIds.contains(admin.id),
                          onSelected: (selected) => setState(() {
                            selected
                                ? _selectedAdminIds.add(admin.id)
                                : _selectedAdminIds.remove(admin.id);
                            _notEnough = false;
                          }),
                        ),
                      HelpDot(
                        l10n?.helpHintValidationTopic ?? 'confirmations',
                      ),
                    ],
                  ),
                ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: HelpDotTitle(
                  l10n?.validationOwnerRequired ??
                      'Owner must always validate',
                  l10n?.helpHintValidationTopic ?? 'confirmations',
                ),
                value: _ownerRequired,
                onChanged: (value) =>
                    setState(() => _ownerRequired = value),
              ),
              // #840 — the rule that holds whatever else is set, stated
              // where it is decided instead of only in the guide.
              Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                child: Text(
                  l10n?.validationNoSelfDesc ??
                      'Whoever creates an event never validates it. It waits '
                          'for someone else, or expires undecided.',
                  key: const Key('validation-no-self'),
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              ),
              if (widget.chainOn) ...[
                SwitchListTile(
                  key: const Key('validation-owner-self'),
                  contentPadding: EdgeInsets.zero,
                  title: HelpDotTitle(
                    l10n?.validationOwnerSelf ??
                        'The owner may validate their own',
                    l10n?.helpHintValidationTopic ?? 'confirmations',
                  ),
                  subtitle: Text(
                    l10n?.validationOwnerSelfDesc ??
                        'The single exception, and the owner\'s alone: an '
                            'admin never validates their own act.',
                  ),
                  value: _ownerMaySelfValidate,
                  onChanged: (value) =>
                      setState(() => _ownerMaySelfValidate = value),
                ),
                SwitchListTile(
                  key: const Key('validation-sequential'),
                  contentPadding: EdgeInsets.zero,
                  title: HelpDotTitle(
                    l10n?.validationSequential ?? 'One after another',
                    l10n?.helpHintValidationTopic ?? 'confirmations',
                  ),
                  subtitle: Text(
                    l10n?.validationSequentialDesc ??
                        'The next validation is asked for once the previous '
                            'one passed, and the trail numbers each step.',
                  ),
                  value: _sequential,
                  onChanged: (value) =>
                      setState(() => _sequential = value),
                ),
              ],
              // #629 — booking deletions only, both OFF by default.
              if (_offersAutoValidation) ...[
                SwitchListTile(
                  key: const Key('auto-validate-owner'),
                  contentPadding: EdgeInsets.zero,
                  title: HelpDotTitle(
                    l10n?.validationAutoValidateOwner ??
                        'Owners delete without validation',
                    l10n?.helpHintValidationTopic ?? 'confirmations',
                  ),
                  subtitle: Text(
                    l10n?.validationAutoValidateDesc ??
                        'Their own deletion request settles itself and '
                            'stays marked as auto-validated.',
                  ),
                  value: _autoValidateOwner,
                  onChanged: (value) =>
                      setState(() => _autoValidateOwner = value),
                ),
                SwitchListTile(
                  key: const Key('auto-validate-admin'),
                  contentPadding: EdgeInsets.zero,
                  title: HelpDotTitle(
                    l10n?.validationAutoValidateAdmin ??
                        'Admins delete without validation',
                    l10n?.helpHintValidationTopic ?? 'confirmations',
                  ),
                  value: _autoValidateAdmin,
                  onChanged: (value) =>
                      setState(() => _autoValidateAdmin = value),
                ),
              ],
              if (_notEnough)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.xs),
                  child: Text(
                    l10n?.validationNotEnough ??
                        'Not enough eligible validators.',
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(color: theme.colorScheme.error),
                  ),
                ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(l10n?.commonCancel ?? 'Cancel'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _save,
                    child: Text(l10n?.commonSave ?? 'Save'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
