// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';

import '../../../../core/ids/request_id.dart';
import '../../../../core/locale/device_locale.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/country/country_catalog.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/trace/guarded.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../auth/providers/sign_out.dart';
import '../../../../core/ui/inline_banner.dart';
import '../../application/start_workspace.dart';
import '../../domain/invite_uri.dart';
import '../../domain/template_outline.dart';
import '../../domain/template_preview.dart';
import '../../providers/workspace_providers.dart';
import '../country_names.dart';
import '../../domain/workspace.dart';
import '../widgets/template_group_label.dart';
import '../widgets/template_picker.dart';
import '../../../../core/ui/wizard_scaffold.dart';

/// First-run screen for a signed-in user without a workspace: create one
/// (become owner) or join via invite code (spec §11 onboarding).
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _createFormKey = GlobalKey<FormState>();
  final _joinFormKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  // #1303 S1 — seeded from the device's country in initState; never a
  // hardcoded Germany.
  final _currency = TextEditingController();
  final _timezone = TextEditingController();
  // #917 — a new space is for trying things out until its owner
  // says otherwise. The safe answer to "is this real?" is no.
  WorkspaceEnvironment _environment = WorkspaceEnvironment.development;
  // #987 — the other side of the pair, created at the same time.
  bool _withTwin = true;

  /// #1120 — the template the new space starts from; null = empty canvas.
  /// 'tiny' is the builtin and the default, resolved by key once the list
  /// arrives.
  String? _templateId;
  bool _templateResolved = false;

  /// #1303 — the id this creation is known by, generated ONCE for the
  /// session: a retry after a failure or a lost response sends the same id,
  /// so the server returns the workspace it already made instead of
  /// making a second one (and a second dev/prod pair).
  final String _requestId = newRequestId();
  final _inviteCode = TextEditingController();
  late String _countryCode;
  bool _joinMode = false;
  bool _busy = false;

  /// #1303 S2 — the create flow's step: name, where, start from, confirm.
  int _step = 0;

  /// A creation carrying a template failed: the confirm step offers to
  /// create without one, so nobody is stuck on a template that cannot apply.
  bool _failedWithTemplate = false;

  /// #1303 S3 — what the chosen template sets up, asked once per choice.
  String? _outlineFor;
  Future<TemplateOutline>? _outline;
  TemplateOutline? _outlineValue;

  Future<TemplateOutline> _outlineOf(String templateId) {
    if (_outlineFor != templateId || _outline == null) {
      _outlineFor = templateId;
      _outlineValue = null;
      _outline = ref
          .read(workspaceStartProvider)
          .outlineOf(templateId)
          .then((outline) {
        if (mounted && _outlineFor == templateId) {
          setState(() => _outlineValue = outline);
        }
        return outline;
      });
    }
    return _outline!;
  }

  /// The server already said this template cannot be applied: Create is
  /// held back and "Create without a template" is offered instead.
  bool get _templateRefused =>
      _templateId != null &&
      _outlineFor == _templateId &&
      !templateUsable(_outlineValue);

  static const _nameStep = 0;
  static const _whereStep = 1;
  static const _confirmStep = 3;

  @override
  void initState() {
    super.initState();
    final country = initialCountryFor(ref.read(deviceLocaleProvider));
    _countryCode = country.code;
    _currency.text = country.currencyCode;
    _timezone.text = country.defaultTimezone;
  }

  @override
  void dispose() {
    _name.dispose();
    _currency.dispose();
    _timezone.dispose();
    _inviteCode.dispose();
    super.dispose();
  }

  /// Runs [action]; false from it means the command REFUSED and nothing
  /// was written, so there is nothing to refresh and nowhere to go.
  Future<void> _run(Future<bool> Function() action) async {
    setState(() => _busy = true);
    final l10n = AppLocalizations.of(context);
    if (!await runGuarded(
      context,
      domain: 'workspace',
      message: 'onboarding action failed',
      errorText: l10n?.workspaceGenericError ??
          'Something went wrong. Please try again.',
      action: () async {
          if (!await action()) return;
          ref.invalidate(myWorkspacesProvider);
          // First-run visits are bounced to /plan by the router redirect; when
          // opened from Profiles (#89) we pop back to the profile list instead.
          if (mounted && context.canPop()) context.pop();
      },
    )) {
      if (mounted) {
        setState(() {
          _busy = false;
          _failedWithTemplate = _templateId != null;
        });
      }
      return;
    }
    if (mounted) setState(() => _busy = false);
  }

  // #1449 — the same sentences the command refuses on, read once: the
  // wizard uses them to hold a step, the command to hold the write.
  bool get _nameValid => isNameable(_name.text);
  bool get _whereValid => isPlaceable(
        currencyCode: _currency.text,
        timezone: _timezone.text,
      );

  /// Next from [_step]; a step that is not filled in shows why and stays.
  void _next() {
    final valid = switch (_step) {
      _nameStep => _nameValid,
      _whereStep => _whereValid,
      _ => true,
    };
    if (!valid) {
      _createFormKey.currentState?.validate();
      return;
    }
    setState(() => _step = (_step + 1).clamp(0, _confirmStep));
  }

  /// #1449 — application/start_workspace.dart holds the rules: a name, a
  /// currency and a timezone, a template the server has not refused, and
  /// the request id that makes a retry ONE creation. The screen says
  /// what was chosen.
  Future<void> _create() async {
    await _run(() async {
      final result = await ref.read(workspaceStartProvider).create(
            name: _name.text,
            countryCode: _countryCode,
            currencyCode: _currency.text,
            timezone: _timezone.text,
            requestId: _requestId,
            environment: _environment,
            withTwin: _withTwin,
            // #1120 — a new space starts with a room. #1303 — applied in
            // the same transaction as the creation; the twin receives it
            // through the deployment refresh, like every other piece of
            // configuration.
            templateId: _templateId,
            outline: _outlineFor == _templateId ? _outlineValue : null,
          );
      return result.outcome == StartOutcome.created;
    });
  }

  Future<void> _join() async {
    if (!(_joinFormKey.currentState?.validate() ?? false)) return;
    await _run(() async =>
        await ref.read(workspaceStartProvider).join(_inviteCode.text) ==
        JoinOutcome.joined);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final signOut = IconButton(
      icon: const Icon(Icons.logout),
      tooltip: l10n?.authSignOut ?? 'Sign out',
      onPressed: () async => signOutAndForget(ref),
    );
    final modeSwitch = SegmentedButton<bool>(
      segments: [
        ButtonSegment(
          value: false,
          label: Text(l10n?.onboardingCreateTab ?? 'Create a workspace'),
        ),
        ButtonSegment(
          value: true,
          label: Text(l10n?.onboardingJoinTab ?? 'Join a workspace'),
        ),
      ],
      selected: {_joinMode},
      onSelectionChanged: (selection) =>
          setState(() => _joinMode = selection.first),
    );
    if (_joinMode) {
      return Scaffold(
        appBar: AppBar(
          title: Text(l10n?.onboardingTitle ?? 'Welcome to DesKilo'),
          actions: [signOut],
        ),
        body: _centered(Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [modeSwitch, const SizedBox(height: 24), _joinForm(l10n)],
        )),
      );
    }
    // #1303 S2 — creating is a staged flow: a person sees what will be
    // created before it is, and Back keeps everything they typed.
    return WizardScaffold(
      title: l10n?.onboardingTitle ?? 'Welcome to DesKilo',
      actions: [signOut],
      steps: [
        (name: 'name', label: l10n?.onboardingStepName ?? 'Name'),
        (name: 'where', label: l10n?.onboardingStepWhere ?? 'Where'),
        (name: 'start', label: l10n?.onboardingStartFrom ?? 'Start from'),
        (name: 'confirm', label: l10n?.onboardingStepConfirm ?? 'Confirm'),
      ],
      index: _step,
      onStepTap: _busy
          ? null
          : (i) {
              if (i <= _step || (_nameValid && _whereValid)) {
                setState(() => _step = i);
              }
            },
      onBack: _step == 0 || _busy ? null : () => setState(() => _step--),
      onNext: _busy ? null : _next,
      onFinish: _busy ? null : _create,
      finishEnabled: !_templateRefused,
      finishKey: const ValueKey('onboarding-create'),
      finishLabel: l10n?.onboardingCreateButton ?? 'Create workspace',
      body: _centered(Form(
        key: _createFormKey,
        child: switch (_step) {
          _nameStep => _nameStepBody(l10n, modeSwitch),
          _whereStep => _whereStepBody(l10n),
          _confirmStep => _confirmStepBody(l10n),
          _ => _startFromStepBody(),
        },
      )),
    );
  }

  Widget _centered(Widget child) => Center(
        child: SingleChildScrollView(
          padding: AppSpacing.xlAll,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: child,
          ),
        ),
      );

  Widget _nameStepBody(AppLocalizations? l10n, Widget modeSwitch) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          modeSwitch,
          const SizedBox(height: 24),
          TextFormField(
            key: const ValueKey('onboarding-name'),
            controller: _name,
            decoration: InputDecoration(
              labelText: l10n?.workspaceNameLabel ?? 'Workspace name',
            ),
            onChanged: (_) => setState(() {}),
            validator: (v) => (v == null || v.trim().isEmpty)
                ? (l10n?.authFieldRequired ?? 'Required')
                : null,
          ),
          const SizedBox(height: AppSpacing.md),
          // The suggested settings are the device's country and the builtin
          // template: most people need nothing else, and still see the
          // confirm step before anything is created.
          TextButton.icon(
            key: const ValueKey('onboarding-use-suggested'),
            onPressed: _busy || !_nameValid
                ? null
                : () => setState(() => _step = _confirmStep),
            icon: const Icon(Icons.fast_forward_outlined),
            label: Text(
                l10n?.onboardingUseSuggested ?? 'Use the suggested settings'),
          ),
        ],
      );

  Widget _whereStepBody(AppLocalizations? l10n) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DropdownButtonFormField<String>(
            initialValue: _countryCode,
            decoration: InputDecoration(
              labelText: l10n?.workspaceCountryLabel ?? 'Country',
            ),
            items: [
              for (final country in CountryCatalog.countries)
                DropdownMenuItem(
                  value: country.code,
                  child: Text(localizedCountryName(l10n, country.code)),
                ),
            ],
            onChanged: (code) {
              if (code == null) return;
              final country = CountryCatalog.byCode(code);
              setState(() {
                _countryCode = code;
                _currency.text = country.currencyCode;
                _timezone.text = country.defaultTimezone;
              });
            },
          ),
          const SizedBox(height: 12),
          TextFormField(
            key: const ValueKey('onboarding-currency'),
            controller: _currency,
            decoration: InputDecoration(
              labelText: l10n?.workspaceCurrencyLabel ?? 'Currency',
            ),
            validator: (v) => (v == null || v.trim().length != 3)
                ? (l10n?.authFieldRequired ?? 'Required')
                : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            key: const ValueKey('onboarding-timezone'),
            controller: _timezone,
            decoration: InputDecoration(
              labelText: l10n?.workspaceTimezoneLabel ?? 'Time zone',
            ),
            validator: (v) => (v == null || v.trim().isEmpty)
                ? (l10n?.authFieldRequired ?? 'Required')
                : null,
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<WorkspaceEnvironment>(
            key: const ValueKey('onboarding-environment'),
            initialValue: _environment,
            // The labels carry a dash and a clause; without this the row
            // sizes to its natural width and overflows a narrow form.
            isExpanded: true,
            decoration: InputDecoration(
              labelText: l10n?.environmentLabel ?? 'Workspace type',
              helperMaxLines: 4,
              helperText: l10n?.environmentHint ??
                  'A development workspace says so on every screen and '
                      'watermarks every document.',
            ),
            items: [
              DropdownMenuItem(
                value: WorkspaceEnvironment.development,
                child: Text(l10n?.environmentDev ??
                    'Development — for trying things out'),
              ),
              DropdownMenuItem(
                value: WorkspaceEnvironment.production,
                child: Text(l10n?.environmentProd ??
                    'Production — the invoices are owed'),
              ),
            ],
            onChanged: _busy
                ? null
                : (v) => setState(() => _environment = v ?? _environment),
          ),
          // #987 — the pair: one to try things out, one that is real, both
          // yours from the start.
          CheckboxListTile(
            key: const ValueKey('onboarding-with-twin'),
            value: _withTwin,
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            title: Text(l10n?.onboardingWithTwin ??
                'Create the development and production pair'),
            subtitle: Text(l10n?.onboardingWithTwinHint ??
                'Two workspaces with the same name: one to try things out, '
                    'one that is real. You own both.'),
            onChanged:
                _busy ? null : (v) => setState(() => _withTwin = v ?? true),
          ),
        ],
      );

  Widget _startFromStepBody() => Consumer(builder: (context, ref, _) {
        _resolveDefaultTemplate(ref);
        return TemplatePicker(
          selectedId: _templateId,
          onChanged: (id) => setState(() {
            _templateId = id;
            _templateResolved = true;
            _failedWithTemplate = false;
          }),
        );
      });

  /// 'tiny' is the builtin and the default, resolved by key once the list
  /// arrives — whichever step first reads it.
  void _resolveDefaultTemplate(WidgetRef ref) {
    final list = ref.watch(workspaceTemplatesProvider).value;
    if (!_templateResolved && list != null) {
      _templateResolved = true;
      _templateId =
          list.where((t) => t.key == 'tiny').map((t) => t.id).firstOrNull;
    }
  }

  Widget _confirmStepBody(AppLocalizations? l10n) =>
      Consumer(builder: (context, ref, _) {
        _resolveDefaultTemplate(ref);
        final templates = ref.watch(workspaceTemplatesProvider).value ?? const [];
        final template =
            templates.where((t) => t.id == _templateId).firstOrNull;
        final environment = _environment == WorkspaceEnvironment.production
            ? (l10n?.environmentProd ?? 'Production — the invoices are owed')
            : (l10n?.environmentDev ?? 'Development — for trying things out');
        return Column(
          key: const ValueKey('onboarding-confirm'),
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l10n?.onboardingConfirmIntro ?? 'This is what will be created:',
                style: Theme.of(context).textTheme.titleMedium),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.business_outlined),
              title: Text(_name.text.trim()),
              subtitle: Text(environment),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.public),
              title: Text(localizedCountryName(l10n, _countryCode)),
              subtitle: Text(
                  '${_currency.text.trim().toUpperCase()} · ${_timezone.text.trim()}'),
            ),
            if (_withTwin)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.copy_all_outlined),
                title: Text(l10n?.onboardingWithTwin ??
                    'Create the development and production pair'),
              ),
            ListTile(
              key: const ValueKey('onboarding-confirm-template'),
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.grid_view_outlined),
              title: Text(template?.name ??
                  (l10n?.onboardingStartEmpty ?? 'Empty space')),
              subtitle: template == null
                  ? null
                  : Text([
                      l10n?.libraryCounts(template.counts.levels,
                              template.counts.desks, template.counts.seats) ??
                          '${template.counts.levels} levels · '
                              '${template.counts.desks} desks · '
                              '${template.counts.seats} seats',
                      if (template.carriesConfiguration)
                        l10n?.libraryCarriesSettings ?? 'with its settings',
                    ].join(' · ')),
            ),
            if (template != null)
              FutureBuilder<TemplateOutline>(
                future: _outlineOf(template.id),
                builder: (context, snap) => _outlineView(l10n, snap.data),
              ),
            if (_failedWithTemplate || _templateRefused)
              OutlinedButton(
                key: const ValueKey('onboarding-create-without-template'),
                onPressed: _busy
                    ? null
                    : () {
                        setState(() {
                          _templateId = null;
                          _templateResolved = true;
                          _failedWithTemplate = false;
                        });
                        _create();
                      },
                child: Text(l10n?.onboardingCreateWithoutTemplate ??
                    'Create without a template'),
              ),
          ],
        );
      });

  /// Nothing while the outline loads or when it could not be read: the
  /// creation checks the template again either way.
  Widget _outlineView(AppLocalizations? l10n, TemplateOutline? outline) {
    if (outline == null) return const SizedBox.shrink();
    if (outline.refused) {
      return InlineBanner(
        key: const ValueKey('onboarding-template-refused'),
        icon: Icons.block,
        text: [
          l10n?.libraryNotSupported ?? 'This template cannot be applied here.',
          ?outline.reason,
        ].join(' '),
      );
    }
    final groups =
        outline.groups.map((g) => templateGroupLabel(l10n, g)).join(', ');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (outline.compatibility == TemplateCompatibility.partial)
          InlineBanner(
            key: const ValueKey('onboarding-template-partial'),
            icon: Icons.info_outline,
            severity: InlineBannerSeverity.info,
            text: l10n?.libraryPartial ??
                'Part of this template cannot be applied here and is left out.',
          ),
        if (groups.isNotEmpty)
          Text(
            l10n?.onboardingTemplateSetsUp(groups) ?? 'Sets up: $groups',
            key: const ValueKey('onboarding-confirm-groups'),
          ),
      ],
    );
  }

  Widget _joinForm(AppLocalizations? l10n) => Form(
        key: _joinFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              controller: _inviteCode,
              decoration: InputDecoration(
                labelText: l10n?.workspaceInviteCodeLabel ?? 'Invite code',
                helperText: l10n?.workspaceInvitePasteHint ??
                    'Paste the whole invitation message — '
                        'the ID is found automatically.',
                helperMaxLines: 2,
              ),
              maxLines: null,
              textCapitalization: TextCapitalization.characters,
              validator: (v) => InviteUriCodec.extractCode(v ?? '').isEmpty
                  ? (l10n?.workspaceInviteCodeInvalid ??
                      'No workspace ID found — paste the invitation or '
                          'type the ID.')
                  : null,
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _busy ? null : _join,
              child: Text(l10n?.onboardingJoinButton ?? 'Join'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _busy
                  ? null
                  : () async {
                      final code = await context.push<String>('/scan-join');
                      if (code == null || code.isEmpty) return;
                      _inviteCode.text = code;
                      await _join();
                    },
              icon: const Icon(Icons.qr_code_scanner),
              label: Text(l10n?.onboardingScanButton ?? 'Scan QR code'),
            ),
          ],
        ),
      );
}
