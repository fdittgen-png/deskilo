// SPDX-License-Identifier: 0BSD
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/backend/backend_settings.dart';
import '../../../../core/instance/instance_builder.dart';
import '../../../../core/instance/instance_bundle.dart';
import '../../../../core/instance/instance_bundle_asset.dart';
import '../../../../core/instance/management_api.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/trace/trace_logger.dart';
import '../../../../core/ui/app_snack.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../auth/providers/auth_providers.dart';
import '../../../../core/ui/wizard_scaffold.dart';
import '../../../workspace/providers/workspace_providers.dart';

/// #977 — a new instance for a person who runs a coworking space, not a
/// database: paste one access token, name the project, and the wizard
/// creates it, installs every migration, deploys every function, sets
/// the sign-in rules and points this device at it. Each step is
/// retryable on its own; the token lives in this state and nowhere
/// else.
class NewInstanceScreen extends ConsumerStatefulWidget {
  const NewInstanceScreen({super.key});

  @override
  ConsumerState<NewInstanceScreen> createState() => _NewInstanceScreenState();
}

enum _Step { account, project, schema, functions, signIn, done }

class _NewInstanceScreenState extends ConsumerState<NewInstanceScreen> {
  static const String supabaseUrl = 'https://supabase.com';
  static const String tokensUrl = 'https://supabase.com/dashboard/account/tokens';

  final _token = TextEditingController();
  final _name = TextEditingController();
  _Step _step = _Step.account;
  bool _busy = false;
  String? _error;

  SupabaseManagement? _api;
  List<SupabaseOrganization> _orgs = const [];
  String? _org;
  List<SupabaseProject> _existing = const [];
  String _region = 'eu-west-1';
  String _password = '';
  SupabaseProject? _project;
  String _status = '';
  InstanceBundle? _bundle;
  InstanceProgress? _progress;
  int _schemaDone = 0;
  bool _schemaInstalled = false;
  bool _functionsDeployed = false;
  bool _signInConfigured = false;
  ({String url, String key})? _endpoint;

  @override
  void initState() {
    super.initState();
    _password = generateDatabasePassword();
    final workspace = ref.read(currentWorkspaceProvider).value;
    _name.text = workspace?.name ?? '';
    _region = defaultRegionFor(workspace?.countryCode ?? '');
  }

  @override
  void dispose() {
    _token.dispose();
    _name.dispose();
    super.dispose();
  }

  InstanceBuilder get _builder => InstanceBuilder(_api!);

  /// Runs one step: busy flag, typed failure into [_error], trace.
  Future<bool> _run(String what, Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
      return true;
    } on InstanceStepFailure catch (e, st) {
      TraceLogger.instance.warn('instance', '$what failed at ${e.item}',
          error: e, stackTrace: st);
      if (mounted) setState(() => _error = _stepFailed(e.item, e.message));
    } on ManagementApiException catch (e, st) {
      TraceLogger.instance.warn('instance', '$what refused', error: e, stackTrace: st);
      if (mounted) {
        setState(() => _error = e.unauthorized
            ? (AppLocalizations.of(context)?.instanceTokenRefused ??
                'Supabase refused the token. Create one at Account → Access '
                    'Tokens and paste it whole.')
            : e.message);
      }
    } catch (e, st) {
      TraceLogger.instance.error('instance', '$what failed', error: e, stackTrace: st);
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    return false;
  }

  String _stepFailed(String item, String message) =>
      AppLocalizations.of(context)?.instanceStepFailed(item, message) ??
      'Stopped at $item: $message';

  Future<void> _checkToken() async {
    final token = _token.text.trim();
    if (token.isEmpty) return;
    _api = ref.read(supabaseManagementFactoryProvider)(token);
    await _run('list organisations', () async {
      final orgs = await _api!.listOrganizations();
      final projects = await _api!.listProjects();
      setState(() {
        _orgs = orgs;
        _org = orgs.length == 1 ? orgs.single.id : _org;
        _existing = projects;
      });
    });
  }

  Future<void> _createProject() async {
    final org = _org;
    if (org == null) return;
    await _run('create project', () async {
      final project = await _builder.createProject(
        organizationId: org,
        name: _name.text.trim(),
        region: _region,
        databasePassword: _password,
        onStatus: (s) {
          if (mounted) setState(() => _status = s);
        },
      );
      setState(() => _project = project);
    });
  }

  Future<void> _useExisting(SupabaseProject project) async {
    await _run('wait for project', () async {
      final ready = await _builder.waitUntilReady(project.ref,
          onStatus: (s) {
        if (mounted) setState(() => _status = s);
      });
      setState(() => _project = ready);
    });
  }

  Future<void> _installSchema() async {
    final ref = _project?.ref;
    if (ref == null) return;
    await _run('install schema', () async {
      _bundle ??= await this.ref.read(instanceBundleLoaderProvider)();
      await _builder.installSchema(ref, _bundle!, skip: _schemaDone,
          onProgress: (p) {
        if (mounted) {
          setState(() {
            _progress = p;
            _schemaDone = p.done;
          });
        }
      });
      setState(() => _schemaInstalled = true);
    });
  }

  Future<void> _deployFunctions() async {
    final ref = _project?.ref;
    if (ref == null) return;
    await _run('deploy functions', () async {
      _bundle ??= await this.ref.read(instanceBundleLoaderProvider)();
      await _builder.deployFunctions(ref, _bundle!, onProgress: (p) {
        if (mounted) setState(() => _progress = p);
      });
      setState(() => _functionsDeployed = true);
    });
  }

  Future<void> _configureSignIn() async {
    final ref = _project?.ref;
    if (ref == null) return;
    await _run('configure auth', () async {
      await _builder.configureAuth(ref);
      final endpoint = await _builder.endpointOf(ref);
      setState(() {
        _signInConfigured = true;
        _endpoint = endpoint;
      });
    });
  }

  Future<void> _useHere() async {
    final endpoint = _endpoint;
    if (endpoint == null) return;
    final l10n = AppLocalizations.of(context);
    final ok = await _run('switch device', () async {
      await ref
          .read(activeBackendProvider.notifier)
          .setEndpoint(BackendEndpoint(endpoint.url, endpoint.key));
      await ref.read(authRepositoryProvider).signOut();
    });
    if (!ok || !mounted) return;
    AppSnack.success(
      context,
      l10n?.backendServerSaved ??
          'Saved. Close and reopen the app to use the new server.',
    );
    context.go('/server');
  }

  bool get _nextEnabled => switch (_step) {
        _Step.account => _org != null && !_busy,
        _Step.project => _project != null && !_busy,
        _Step.schema => _schemaInstalled && !_busy,
        _Step.functions => _functionsDeployed && !_busy,
        _Step.signIn => _signInConfigured && !_busy,
        _Step.done => false,
      };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final steps = <WizardStepSpec>[
      (name: 'account', label: l10n?.instanceStepAccount ?? 'Account'),
      (name: 'project', label: l10n?.instanceStepProject ?? 'Project'),
      (name: 'schema', label: l10n?.instanceStepSchema ?? 'Schema'),
      (name: 'functions', label: l10n?.instanceStepFunctions ?? 'Functions'),
      (name: 'signin', label: l10n?.instanceStepSignIn ?? 'Sign-in'),
      (name: 'done', label: l10n?.instanceStepDone ?? 'Done'),
    ];
    return WizardScaffold(
      title: l10n?.instanceWizardTitle ?? 'Create a new instance',
      steps: steps,
      index: _step.index,
      nextEnabled: _nextEnabled,
      onNext: _step == _Step.done
          ? null
          : () => setState(() {
                _error = null;
                _step = _Step.values[_step.index + 1];
              }),
      onBack: _step == _Step.account || _busy
          ? null
          : () => setState(() {
                _error = null;
                _step = _Step.values[_step.index - 1];
              }),
      onFinish: _step == _Step.done && _endpoint != null && !_busy ? _useHere : null,
      finishLabel: l10n?.instanceUseHere ?? 'Use this instance on this device',
      finishKey: const ValueKey('instance-use-here'),
      body: ListView(
        padding: AppSpacing.gutterAll,
        children: [
          ..._body(l10n),
          if (_error case final error?)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.md),
              child: Card(
                key: const ValueKey('instance-error'),
                color: Theme.of(context).colorScheme.errorContainer,
                child: Padding(
                  padding: AppSpacing.mdAll,
                  child: Text(error),
                ),
              ),
            ),
          if (_busy)
            const Padding(
              padding: EdgeInsets.only(top: AppSpacing.md),
              child: LinearProgressIndicator(),
            ),
        ],
      ),
    );
  }

  List<Widget> _body(AppLocalizations? l10n) => switch (_step) {
        _Step.account => _account(l10n),
        _Step.project => _projectStep(l10n),
        _Step.schema => _installStep(
            l10n,
            intro: l10n?.instanceInstallSchema(_bundle?.schema.length ?? 0) ??
                'Install the schema: every migration of the app, in order.',
            buttonKey: 'instance-install-schema',
            done: _schemaInstalled,
            onRun: _installSchema,
            retry: _schemaDone > 0,
          ),
        _Step.functions => _installStep(
            l10n,
            intro: l10n?.instanceDeployFunctions(_bundle?.functions.length ?? 0) ??
                'Deploy the functions: payments, e-invoices, push, badges.',
            buttonKey: 'instance-deploy-functions',
            done: _functionsDeployed,
            onRun: _deployFunctions,
            retry: false,
          ),
        _Step.signIn => _signInStep(l10n),
        _Step.done => _doneStep(l10n),
      };

  Widget _text(String s, {TextStyle? style}) =>
      Padding(padding: const EdgeInsets.only(bottom: AppSpacing.sm), child: Text(s, style: style));

  Widget _link(String url, {required String label}) => Row(children: [
        Expanded(child: SelectableText(url)),
        IconButton(
          tooltip: label,
          icon: const Icon(Icons.copy_outlined),
          onPressed: () => Clipboard.setData(ClipboardData(text: url)),
        ),
      ]);

  List<Widget> _account(AppLocalizations? l10n) => [
        _text(l10n?.instanceAccountIntro ??
            'Create a free account at supabase.com, then make a personal '
                'access token (Account → Access Tokens) and paste it here. '
                'The wizard uses it to create and set up the project; it is '
                'never stored.'),
        _link(supabaseUrl, label: l10n?.commonCopy ?? 'Copy'),
        _link(tokensUrl, label: l10n?.commonCopy ?? 'Copy'),
        TextField(
          key: const ValueKey('instance-token'),
          controller: _token,
          obscureText: true,
          decoration: InputDecoration(
            labelText: l10n?.instanceTokenLabel ?? 'Personal access token',
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        FilledButton.tonalIcon(
          key: const ValueKey('instance-check-token'),
          onPressed: _busy ? null : _checkToken,
          icon: const Icon(Icons.verified_user_outlined),
          label: Text(l10n?.instanceCheckToken ?? 'Check the token'),
        ),
        if (_orgs.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          _text(l10n?.instanceOrganisationLabel ?? 'Organisation',
              style: Theme.of(context).textTheme.labelLarge),
          RadioGroup<String>(
            groupValue: _org,
            onChanged: (v) => setState(() => _org = v),
            child: Column(
              children: [
                for (final org in _orgs)
                  RadioListTile<String>(
                    key: ValueKey('instance-org-${org.id}'),
                    value: org.id,
                    title: Text(org.name),
                  ),
              ],
            ),
          ),
        ],
      ];

  List<Widget> _projectStep(AppLocalizations? l10n) => [
        TextField(
          key: const ValueKey('instance-project-name'),
          controller: _name,
          decoration: InputDecoration(
            labelText: l10n?.instanceProjectName ?? 'Project name',
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        DropdownButtonFormField<String>(
          key: const ValueKey('instance-region'),
          initialValue: _region,
          decoration: InputDecoration(
            labelText: l10n?.instanceRegion ?? 'Region (the nearest to the space)',
            border: const OutlineInputBorder(),
          ),
          items: [
            for (final r in supabaseRegions)
              DropdownMenuItem(value: r.code, child: Text(r.label)),
          ],
          onChanged: (v) => setState(() => _region = v ?? _region),
        ),
        const SizedBox(height: AppSpacing.sm),
        _text(l10n?.instanceDatabasePassword ??
            'Database password, chosen for you — copy it somewhere safe; '
                'the app never needs it again.'),
        _link(_password, label: l10n?.commonCopy ?? 'Copy'),
        FilledButton.icon(
          key: const ValueKey('instance-create-project'),
          onPressed: _busy || _project != null || _name.text.trim().isEmpty
              ? null
              : _createProject,
          icon: const Icon(Icons.add_circle_outline),
          label: Text(l10n?.instanceCreateProject ?? 'Create the project'),
        ),
        if (_status.isNotEmpty && _project == null)
          _text(l10n?.instanceProjectStatus(_status) ?? 'Project status: $_status'),
        if (_project case final p?)
          _text(l10n?.instanceProjectReady(p.ref) ?? 'Project ready: ${p.ref}',
              style: Theme.of(context).textTheme.titleSmall),
        if (_existing.isNotEmpty && _project == null) ...[
          const SizedBox(height: AppSpacing.md),
          _text(l10n?.instanceUseExisting ?? 'Or use an existing project:',
              style: Theme.of(context).textTheme.labelLarge),
          for (final p in _existing)
            ListTile(
              key: ValueKey('instance-existing-${p.ref}'),
              leading: const Icon(Icons.dns_outlined),
              title: Text(p.name),
              subtitle: Text([p.region, p.status].join(' · ')),
              onTap: _busy ? null : () => _useExisting(p),
            ),
        ],
      ];

  List<Widget> _installStep(
    AppLocalizations? l10n, {
    required String intro,
    required String buttonKey,
    required bool done,
    required Future<void> Function() onRun,
    required bool retry,
  }) =>
      [
        _text(intro),
        if (_progress case final p? when !done)
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              LinearProgressIndicator(value: p.total == 0 ? null : p.done / p.total),
              const SizedBox(height: AppSpacing.xs),
              _text(l10n?.instanceProgress(p.done, p.total, p.current) ??
                  '${p.done} / ${p.total} · ${p.current}'),
            ],
          ),
        FilledButton.icon(
          key: ValueKey(buttonKey),
          onPressed: _busy || done ? null : onRun,
          icon: Icon(done ? Icons.check_circle_outline : Icons.play_arrow_outlined),
          label: Text(done
              ? (l10n?.commonDone ?? 'Done')
              : retry && _error != null
                  ? (l10n?.instanceRetry ?? 'Retry from where it stopped')
                  : (l10n?.commonStart ?? 'Start')),
        ),
      ];

  List<Widget> _signInStep(AppLocalizations? l10n) => [
        _text(l10n?.instanceSignInExplain ??
            'Sign-in settings: e-mail confirmation on (a sign-up must click '
                'the link in its mail), and the app\'s links allowed for '
                'password resets and magic links.'),
        FilledButton.icon(
          key: const ValueKey('instance-apply-signin'),
          onPressed: _busy || _signInConfigured ? null : _configureSignIn,
          icon: Icon(_signInConfigured ? Icons.check_circle_outline : Icons.tune),
          label: Text(_signInConfigured
              ? (l10n?.commonDone ?? 'Done')
              : (l10n?.instanceApplySignIn ?? 'Apply the sign-in settings')),
        ),
      ];

  List<Widget> _doneStep(AppLocalizations? l10n) => [
        _text(l10n?.instanceDoneIntro ??
            'The instance is ready. Use it on this device, then share the '
                'server QR from the Server screen so members join the same '
                'one.'),
        if (_endpoint case final e?) ...[
          _link(e.url, label: l10n?.commonCopy ?? 'Copy'),
          _text('${e.key.substring(0, e.key.length.clamp(0, 18))}…',
              style: const TextStyle(fontFamily: 'monospace')),
        ],
      ];
}
