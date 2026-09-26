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
import '../../application/creation_intent.dart';
import '../../application/start_workspace.dart';
import '../widgets/onboarding_creation.dart';
import '../widgets/onboarding_join_form.dart';
import '../../../../core/ui/wizard_navigation.dart';
import '../../domain/template_outline.dart';
import '../../providers/workspace_providers.dart';
import '../country_names.dart';
import '../widgets/template_picker.dart';
import '../../../../core/ui/wizard_scaffold.dart';
import '../../../../core/ui/wizard_form_layout.dart';
import '../../../../core/ui/wizard_progress.dart';

/// First-run screen for a signed-in user without a workspace: create one
/// (become owner) or join via invite code (spec §11 onboarding).
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key, this.navigation});
  final WizardNavigationController? navigation;

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _createFormKey = GlobalKey<FormState>();
  final _joinFormKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _nameFocus = FocusNode();
  final _currencyFocus = FocusNode();
  final _timezoneFocus = FocusNode();
  final _currency = TextEditingController();
  final _timezone = TextEditingController();
  // #917/#1636 — one test workspace until its owner chooses otherwise.
  CreationShape _shape = CreationShape.test;
  late String _derivedCurrency, _derivedTimezone;

  /// #1636 — what was last sent, and whether its outcome is unknown.
  CreationIntent? _sent;
  bool _uncertain = false, _intentChanged = false;

  String? _templateId;
  bool _templateResolved = false;

  /// A retry retains the request id, so creation stays idempotent; a
  /// resumed draft brings its own.
  String _requestId = newRequestId();
  final _inviteCode = TextEditingController();
  late String _countryCode;
  bool _joinMode = false;
  bool _busy = false;
  String? _failure;
  final _feedbackKey = GlobalKey();

  int _step = 0;
  final _completed = <int>{};
  final _skipped = <int>{};

  bool _failedWithTemplate = false;

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
    _currency.text = _derivedCurrency = country.currencyCode;
    _timezone.text = _derivedTimezone = country.defaultTimezone;
    _resume();
  }

  /// #1636 — a creation sent before a restart, by THIS account, whose
  /// answer never arrived: its fields and its request id come back, and
  /// the confirm step says so.
  Future<void> _resume() async {
    final draft = await ref.read(creationDraftsProvider).pending();
    if (draft == null || !mounted) return;
    setState(() {
      _restore(draft.intent);
      _uncertain = true;
      _completed.addAll([_nameStep, _whereStep, 2]);
      _step = _confirmStep;
    });
  }

  void _restore(CreationIntent intent) {
    _sent = intent;
    _requestId = intent.requestId;
    _name.text = intent.name;
    _countryCode = intent.countryCode;
    _currency.text = intent.currencyCode;
    _timezone.text = intent.timezone;
    _shape = intent.shape;
    _templateId = intent.templateId;
    _templateResolved = true;
    _intentChanged = false;
  }

  CreationIntent get _intent => CreationIntent(
        requestId: _requestId,
        name: _name.text,
        countryCode: _countryCode,
        currencyCode: _currency.text,
        timezone: _timezone.text,
        shape: _shape,
        templateId: _templateId,
      );

  @override
  void dispose() {
    _nameFocus.dispose();
    _currencyFocus.dispose();
    _timezoneFocus.dispose();
    _name.dispose();
    _currency.dispose();
    _timezone.dispose();
    _inviteCode.dispose();
    super.dispose();
  }

  Future<void> _run(Future<bool> Function() action) async {
    if (_busy) return;
    Object? error;
    setState(() { _busy = true; _failure = null; });
    final l10n = AppLocalizations.of(context);
    var accepted = false;
    final succeeded = await runGuarded(
      context,
      domain: 'workspace',
      message: 'onboarding action failed',
      action: () async {
          try {
            accepted = await action();
          } catch (e, st) {
            // trace-exempt: rethrown with its stack; runGuarded traces it.
            // Kept to tell a template refusal from an unknown outcome.
            error = e;
            Error.throwWithStackTrace(e, st);
          }
          if (!accepted || !mounted) return;
          if (!_joinMode) await ref.read(creationDraftsProvider).confirmed();
          widget.navigation?.completed = true;
          ref.invalidate(myWorkspacesProvider);
          await ref.read(myWorkspacesProvider.future);
          if (!mounted) return;
          // First-run visits are bounced to /plan by the router redirect; when
          // opened from Profiles (#89) we pop back to the profile list instead.
          if (mounted && context.canPop()) context.pop();
      },
    );
    if (!succeeded || !accepted) {
      if (mounted) {
        setState(() {
          _busy = false;
          _failure = _joinMode
              ? l10n?.workspaceGenericError ?? 'Something went wrong. Please try again.'
              : l10n?.onboardingUnconfirmed ??
                  'The result could not be confirmed. Your entries are kept. Retry to check the same request.';
          // #1636 — only the server refusing the template means nothing
          // was made; any other failure may have created it.
          final refused = error != null && isTemplateRefusal(error!);
          _failedWithTemplate = _templateId != null && refused;
          if (!_joinMode && error != null) _uncertain = !refused;
        });
        WidgetsBinding.instance.addPostFrameCallback((_) {
          final target = _feedbackKey.currentContext;
          if (mounted && target != null) Scrollable.ensureVisible(target);
        });
      }
      return;
    }
    if (mounted) setState(() => _busy = false);
  }

  bool get _nameValid => isNameable(_name.text);
  bool get _whereValid => isPlaceable(
        currencyCode: _currency.text,
        timezone: _timezone.text,
      );

  void _next() {
    final valid = switch (_step) {
      _nameStep => _nameValid,
      _whereStep => _whereValid,
      _ => true,
    };
    if (!valid) {
      _createFormKey.currentState?.validate();
      (_step == _nameStep ? _nameFocus : _currency.text.trim().length != 3
          ? _currencyFocus : _timezoneFocus).requestFocus();
      return;
    }
    _completed.add(_step);
    _skipped.remove(_step);
    _goTo((_step + 1).clamp(0, _confirmStep));
  }

  void _goTo(int step) {
    if (_busy || step == _step) return;
    _skipped.remove(step);
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _step = step);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _step != step || _busy) return;
      if (step == _nameStep) _nameFocus.requestFocus();
      if (step == _whereStep) _currencyFocus.requestFocus();
    });
  }

  WizardStepState _stateOf(int step) {
    if (_skipped.contains(step)) return WizardStepState.skipped;
    if (_completed.contains(step) && (step != 0 || _nameValid) &&
        (step != 1 || _whereValid)) { return WizardStepState.completed; }
    return step > _step && (!_nameValid || !_whereValid)
        ? WizardStepState.unavailable : WizardStepState.available;
  }

  Future<void> _create() async {
    final intent = _intent;
    final sent = _sent;
    if (_uncertain && sent != null && !intent.sameMaterial(sent)) {
      setState(() => _intentChanged = true);
      return;
    }
    await _run(() async {
      _sent = intent;
      await ref.read(creationDraftsProvider).sent(intent);
      final result = await ref.read(workspaceStartProvider).create(
            name: intent.name,
            countryCode: intent.countryCode,
            currencyCode: intent.currencyCode,
            timezone: intent.timezone,
            requestId: intent.requestId,
            environment: intent.shape.environment,
            withTwin: intent.shape.withTwin,
            templateId: intent.templateId,
            outline: _outlineFor == _templateId ? _outlineValue : null,
          );
      return result.outcome == StartOutcome.created;
    });
  }

  void _retryAsSent() {
    final sent = _sent;
    if (sent == null || _busy) return;
    setState(() => _restore(sent));
    _create();
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
      onPressed: _busy ? null : () async => signOutAndForget(ref),
    );
    final modeSwitch = SegmentedButton<bool>(
      direction: MediaQuery.textScalerOf(context).scale(1) > 1.3
          ? Axis.vertical : Axis.horizontal,
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
      onSelectionChanged: _busy ? null : (selection) =>
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
          children: [modeSwitch, const SizedBox(height: 24),
            if (_failure != null) _feedback, _joinForm(l10n)],
        )),
      );
    }
    return WizardNavigation(controller: widget.navigation,
      busy: _busy, hasDraft: _name.text.isNotEmpty || _completed.isNotEmpty,
      discardMessage: l10n?.onboardingDiscardDraft ??
          'Your entries will be lost. This does not cancel a request already sent.',
      onStepBack: _step == 0 ? null : () => _goTo(_step - 1),
      builder: (back) => WizardScaffold(
      leading: Navigator.of(context).canPop() ? BackButton(onPressed: back) : null,
      scrollForm: true,
      busy: _busy,
      status: _failure == null ? null : _feedback,
      animateStep: true,
      stepStates: [for (var i = 0; i <= _confirmStep; i++) _stateOf(i)],
      formMaxWidth: _step == 2 ? double.infinity : WizardFormLayout.shortFormWidth,
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
                _goTo(i);
              }
            },
      onBack: _step == 0 || _busy ? null : back,
      onNext: _busy ? null : _next,
      onFinish: _create,
      finishEnabled: !_busy && !_templateRefused,
      finishKey: const ValueKey('onboarding-create'),
      finishLabel: l10n?.onboardingCreateButton ?? 'Create workspace',
      body: Form(
        key: _createFormKey,
        child: switch (_step) {
          _nameStep => _nameStepBody(l10n, modeSwitch),
          _whereStep => _whereStepBody(l10n),
          _confirmStep => _confirmStepBody(l10n),
          _ => _startFromStepBody(),
        },
      ),
    ));
  }

  Widget get _feedback => Semantics(key: _feedbackKey, liveRegion: true,
    child: InlineBanner(key: const ValueKey('onboarding-error'),
      icon: Icons.error_outline, text: _failure!));

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
            focusNode: _nameFocus,
            decoration: InputDecoration(
              labelText: l10n?.workspaceNameLabel ?? 'Workspace name',
            ),
            onChanged: (_) => setState(() {}),
            validator: (v) => (v == null || v.trim().isEmpty)
                ? (l10n?.authFieldRequired ?? 'Required')
                : null,
          ),
          const SizedBox(height: AppSpacing.md),
          TextButton.icon(
            key: const ValueKey('onboarding-use-suggested'),
            onPressed: _busy || !_nameValid
                ? null
                : () {
                    _completed.add(_nameStep);
                    _skipped.addAll([1, 2]);
                    _goTo(_confirmStep);
                  },
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
            isExpanded: true,
            itemHeight: null,
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
                // #1636 — only a value still at its derived default follows
                // the country; an owner's own choice stays.
                if (_currency.text.trim() == _derivedCurrency) {
                  _currency.text = country.currencyCode;
                }
                if (_timezone.text.trim() == _derivedTimezone) {
                  _timezone.text = country.defaultTimezone;
                }
                _derivedCurrency = country.currencyCode;
                _derivedTimezone = country.defaultTimezone;
              });
            },
          ),
          const SizedBox(height: 12),
          PlaceFields(
            currency: _currency,
            currencyFocus: _currencyFocus,
            timezone: _timezone,
            timezoneFocus: _timezoneFocus,
          ),
          const SizedBox(height: 12),
          CreationShapeSelector(
            value: _shape,
            enabled: !_busy,
            onChanged: (shape) => setState(() => _shape = shape),
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
        return Column(
          key: const ValueKey('onboarding-confirm'),
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_uncertain && _sent != null)
              CreationPendingBanner(
                  changed: _intentChanged || !_intent.sameMaterial(_sent!),
                  onRetryAsSent: _retryAsSent),
            Text(l10n?.onboardingConfirmIntro ?? 'This is what will be created:',
                style: Theme.of(context).textTheme.titleMedium),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.business_outlined),
              title: Text(_name.text.trim()),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.public),
              title: Text(localizedCountryName(l10n, _countryCode)),
              subtitle: Text(
                  '${_currency.text.trim().toUpperCase()} · ${_timezone.text.trim()}'),
            ),
            CreationSummary(shape: _shape),
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
                builder: (context, snap) => TemplateOutlineView(outline: snap.data),
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

  Widget _joinForm(AppLocalizations? l10n) => OnboardingJoinForm(
    formKey: _joinFormKey, code: _inviteCode, busy: _busy, onJoin: _join,
    onScan: () async {
      final code = await context.push<String>('/scan-join');
      if (!mounted || code == null || code.isEmpty) return;
      _inviteCode.text = code;
      await _join();
    },
  );
}
