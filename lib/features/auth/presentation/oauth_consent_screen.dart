// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/links/link_launcher.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/trace/trace_logger.dart';
import '../../../core/ui/inline_banner.dart';
import '../../../core/ui/loading_view.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/oauth_consent.dart';
import '../providers/auth_providers.dart';
import '../providers/oauth_consent_providers.dart';

/// One existing consent route, dispatched by the protected server purpose.
/// Identity consent never asks for business MCP eligibility or a workspace.
class OAuthConsentScreen extends ConsumerStatefulWidget {
  const OAuthConsentScreen({super.key, required this.authorizationId});
  final String authorizationId;

  @override
  ConsumerState<OAuthConsentScreen> createState() => _OAuthConsentScreenState();
}

class _OAuthConsentScreenState extends ConsumerState<OAuthConsentScreen> {
  bool _busy = false;
  bool _failed = false;
  bool _returnAttempted = false;
  Uri? _returnUri;
  int _generation = 0;

  @override
  void didUpdateWidget(covariant OAuthConsentScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.authorizationId != widget.authorizationId) {
      _generation++;
      _busy = _failed = _returnAttempted = false;
      _returnUri = null;
    }
  }

  bool _current(OAuthConsentContext context, int generation) => mounted &&
      generation == _generation &&
      ref.read(authStateProvider).value == context.localUserId;

  Future<void> _go(Uri uri, OAuthConsentContext context,
      {bool automatic = false}) async {
    if (_busy || (automatic && _returnAttempted)) return;
    final generation = _generation;
    if (!_current(context, generation) || !context.permitsIdentityReturn(uri)) return;
    setState(() {
      _busy = true;
      _failed = false;
      _returnAttempted = true;
      _returnUri = uri;
    });
    final launched = await ref.read(linkLauncherProvider)(uri);
    if (!_current(context, generation)) return;
    setState(() { _busy = false; _failed = !launched; });
  }

  Future<void> _answer(OAuthConsentContext context, bool approve) async {
    if (_busy || _returnAttempted) return;
    final generation = _generation;
    if (!_current(context, generation)) return;
    setState(() { _busy = true; _failed = false; });
    Uri? result;
    try {
      result = await ref.read(decideOAuthConsentProvider).answer(
          widget.authorizationId, context, approve: approve);
    } catch (e, st) {
      TraceLogger.instance.error('auth', 'OAuth consent could not continue',
          error: e.runtimeType, stackTrace: st);
    }
    if (!_current(context, generation)) return;
    setState(() { _busy = false; _failed = result == null; });
    if (result != null) await _go(result, context);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(authStateProvider, (previous, next) {
      if (previous?.value == next.value) return;
      setState(() {
        _generation++;
        _busy = _failed = _returnAttempted = false;
        _returnUri = null;
      });
    });
    final l10n = AppLocalizations.of(context);
    final value = ref.watch(oauthConsentProvider(widget.authorizationId));
    return Scaffold(
      appBar: AppBar(title: Text(l10n?.identityConsentTitle ?? 'Continue with Deskilo')),
      body: value.when(
        loading: () => const LoadingView(),
        error: (e, st) => Padding(
          padding: AppSpacing.gutterAll,
          child: _unavailable(l10n),
        ),
        data: (request) {
          if (request.context.purpose != OAuthConsentPurpose.identityFederation) {
            return const LoadingView();
          }
          final destination = request.context.targetAuthUrl!;
          if (request.returnUri != null && !_returnAttempted) {
            final generation = _generation;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted && generation == _generation) {
                _go(request.returnUri!, request.context, automatic: true);
              }
            });
          }
          return ListView(
            padding: AppSpacing.gutterAll,
            children: [
              Text(l10n?.identityConsentAsks(destination.authority) ??
                  'Use your Deskilo identity to sign in to ${destination.authority}.',
                  key: const ValueKey('identity-consent-destination'),
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: AppSpacing.md),
              Text(l10n?.identityConsentPurpose ??
                  'Workspace and assistant access are approved separately.'),
              if (_failed) ...[
                const SizedBox(height: AppSpacing.md),
                _unavailable(l10n),
                if (_returnUri != null)
                  OutlinedButton(
                    key: const ValueKey('identity-consent-retry-return'),
                    onPressed: _busy ? null : () => _go(_returnUri!, request.context),
                    child: Text(l10n?.commonRetry ?? 'Try again'),
                  ),
              ],
              const SizedBox(height: AppSpacing.lg),
              if (_busy || _returnAttempted)
                Semantics(liveRegion: true, child: Text(
                  _failed ? (l10n?.identityConsentReturnFailed ?? 'Could not open the destination.') :
                  _returnAttempted ? (l10n?.identityConsentReturning ?? 'Returning to sign-in…') :
                  (l10n?.identityConsentCompleting ?? 'Saving your choice…'),
                ))
              else ...[
                FilledButton(
                  key: const ValueKey('identity-consent-approve'),
                  onPressed: () => _answer(request.context, true),
                  child: Text(l10n?.authSignInButton ?? 'Sign in'),
                ),
                const SizedBox(height: AppSpacing.sm),
                OutlinedButton(
                  key: const ValueKey('identity-consent-deny'),
                  onPressed: () => _answer(request.context, false),
                  child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _unavailable(AppLocalizations? l10n) => InlineBanner(
    key: const ValueKey('identity-consent-unavailable'),
    icon: Icons.info_outline,
    severity: InlineBannerSeverity.error,
    text: l10n?.identityConsentUnavailable ??
        'This sign-in request is unavailable. Return to the destination and start again.',
  );
}
