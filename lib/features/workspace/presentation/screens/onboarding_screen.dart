// SPDX-License-Identifier: MIT
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/country/country_catalog.dart';
import '../../../../core/trace/trace_logger.dart';
import '../../../../core/ui/app_snack.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../auth/providers/auth_providers.dart';
import '../../providers/workspace_providers.dart';
import '../country_names.dart';

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
  final _currency = TextEditingController(text: 'EUR');
  final _timezone = TextEditingController(text: 'Europe/Berlin');
  final _inviteCode = TextEditingController();
  String _countryCode = 'DE';
  bool _joinMode = false;
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    _currency.dispose();
    _timezone.dispose();
    _inviteCode.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _busy = true);
    final l10n = AppLocalizations.of(context);
    try {
      await action();
      ref.invalidate(myWorkspacesProvider);
      // First-run visits are bounced to /plan by the router redirect; when
      // opened from Profiles (#89) we pop back to the profile list instead.
      if (mounted && context.canPop()) context.pop();
    } catch (e, st) {
      debugPrint('onboarding action failed: $e\n$st');
      TraceLogger.instance.error('workspace', 'onboarding action failed',
          error: e, stackTrace: st);
      if (!mounted) return;
      AppSnack.error(
        context,
        l10n?.workspaceGenericError ??
            'Something went wrong. Please try again.',
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _create() async {
    if (!(_createFormKey.currentState?.validate() ?? false)) return;
    await _run(
      () => ref.read(workspaceRepositoryProvider).createWorkspace(
            name: _name.text.trim(),
            countryCode: _countryCode,
            currencyCode: _currency.text.trim().toUpperCase(),
            timezone: _timezone.text.trim(),
          ),
    );
  }

  Future<void> _join() async {
    if (!(_joinFormKey.currentState?.validate() ?? false)) return;
    await _run(
      () => ref
          .read(workspaceRepositoryProvider)
          .joinWorkspace(_inviteCode.text.trim().toUpperCase()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n?.onboardingTitle ?? 'Welcome to DesKilo'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: l10n?.authSignOut ?? 'Sign out',
            onPressed: () => ref.read(authRepositoryProvider).signOut(),
          ),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SegmentedButton<bool>(
                  segments: [
                    ButtonSegment(
                      value: false,
                      label: Text(
                        l10n?.onboardingCreateTab ?? 'Create a workspace',
                      ),
                    ),
                    ButtonSegment(
                      value: true,
                      label: Text(
                        l10n?.onboardingJoinTab ?? 'Join a workspace',
                      ),
                    ),
                  ],
                  selected: {_joinMode},
                  onSelectionChanged: (selection) =>
                      setState(() => _joinMode = selection.first),
                ),
                const SizedBox(height: 24),
                if (!_joinMode)
                  Form(
                    key: _createFormKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextFormField(
                          controller: _name,
                          decoration: InputDecoration(
                            labelText:
                                l10n?.workspaceNameLabel ?? 'Workspace name',
                          ),
                          validator: (v) => (v == null || v.trim().isEmpty)
                              ? (l10n?.authFieldRequired ?? 'Required')
                              : null,
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          initialValue: _countryCode,
                          decoration: InputDecoration(
                            labelText: l10n?.workspaceCountryLabel ?? 'Country',
                          ),
                          items: [
                            for (final country in CountryCatalog.countries)
                              DropdownMenuItem(
                                value: country.code,
                                child:
                                    Text(
                                      localizedCountryName(
                                          l10n, country.code),
                                    ),
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
                          controller: _currency,
                          decoration: InputDecoration(
                            labelText:
                                l10n?.workspaceCurrencyLabel ?? 'Currency',
                          ),
                          validator: (v) =>
                              (v == null || v.trim().length != 3)
                                  ? (l10n?.authFieldRequired ?? 'Required')
                                  : null,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _timezone,
                          decoration: InputDecoration(
                            labelText:
                                l10n?.workspaceTimezoneLabel ?? 'Time zone',
                          ),
                          validator: (v) => (v == null || v.trim().isEmpty)
                              ? (l10n?.authFieldRequired ?? 'Required')
                              : null,
                        ),
                        const SizedBox(height: 24),
                        FilledButton(
                          onPressed: _busy ? null : _create,
                          child: Text(
                            l10n?.onboardingCreateButton ??
                                'Create workspace',
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  Form(
                    key: _joinFormKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextFormField(
                          controller: _inviteCode,
                          decoration: InputDecoration(
                            labelText:
                                l10n?.workspaceInviteCodeLabel ?? 'Invite code',
                          ),
                          textCapitalization: TextCapitalization.characters,
                          validator: (v) => (v == null || v.trim().isEmpty)
                              ? (l10n?.authFieldRequired ?? 'Required')
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
                                  final code = await context
                                      .push<String>('/scan-join');
                                  if (code == null || code.isEmpty) return;
                                  _inviteCode.text = code;
                                  await _join();
                                },
                          icon: const Icon(Icons.qr_code_scanner),
                          label: Text(
                            l10n?.onboardingScanButton ?? 'Scan QR code',
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
