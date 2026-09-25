// SPDX-License-Identifier: AGPL-3.0-or-later
import '../../../../core/demo/presentation/demo_entry_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show AuthException;

import '../../../../core/nfc/nfc_uid_reader.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/trace/trace_logger.dart';
import '../../../../core/ui/app_snack.dart';
import '../../../../core/ui/inline_banner.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/auth_outcome.dart';
import '../../domain/social_provider.dart';
import '../../providers/auth_providers.dart';
import '../auth_outcome_text.dart';
import '../widgets/badge_sign_in_sheet.dart';

/// Email + password sign-in / sign-up. Navigation after success is handled
/// by the router's auth redirect, not by this screen.
class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  /// Asked ONCE. Probing the reader on every rebuild would restart a
  /// platform query behind every keystroke in the e-mail field.
  final Future<bool> _badgeReader = NfcUidReader().isAvailable();

  final _formKey = GlobalKey<FormState>();
  final _displayName = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _isSignUp = false;
  bool _busy = false;
  bool _obscurePassword = true;

  /// What the last submission came back with, kept ON the form until the
  /// next one: a refusal, a rate limit or a dead network is something to
  /// act on, and a snackbar that has slid away is not a record of it.
  AuthResult? _lastResult;

  @override
  void dispose() {
    _displayName.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _busy = true;
      _lastResult = null;
    });
    final repo = ref.read(authRepositoryProvider);
    AuthResult result;
    try {
      result = _isSignUp
          ? await repo.signUp(
              email: _email.text.trim(),
              password: _password.text,
              displayName: _displayName.text.trim(),
            )
          : await repo.signInWithPassword(
              email: _email.text.trim(),
              password: _password.text,
            );
    } catch (e, st) {
      // The repository answers refusals as values; anything that still
      // throws is a bug or a fake, and nothing was judged.
      TraceLogger.instance.error(
        'auth',
        'auth operation threw past the repository',
        error: e,
        stackTrace: st,
      );
      result = const AuthResult.unavailable();
    }
    if (!mounted) return;
    setState(() {
      _busy = false;
      _lastResult = result;
    });
  }

  /// Forgot-password flow: a one-time recovery code is emailed and,
  /// entered here, is the temporary credential that sets a brand-new
  /// password (code-based on purpose — no Site-URL/deep-link fragility).
  Future<void> _resetPasswordSheet() async {
    final l10n = AppLocalizations.of(context);
    final email = TextEditingController(text: _email.text.trim());
    final code = TextEditingController();
    final newPassword = TextEditingController();
    var sent = false;
    String? fieldError;
    final repo = ref.read(authRepositoryProvider);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) => Padding(
          padding: EdgeInsets.only(
            left: AppSpacing.xl,
            right: AppSpacing.xl,
            top: AppSpacing.xl,
            bottom:
                MediaQuery.of(sheetContext).viewInsets.bottom + AppSpacing.xl,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l10n?.authResetTitle ?? 'Reset password',
                style: Theme.of(sheetContext).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                sent
                    ? (l10n?.authResetCodeSent ??
                        'Code sent — check your email.')
                    : (l10n?.authResetExplainer ??
                        "We'll email you a one-time code. Use it here to "
                            'set a new password.'),
                style: Theme.of(sheetContext).textTheme.bodySmall,
              ),
              const SizedBox(height: 12),
              TextField(
                key: const ValueKey('reset-email'),
                controller: email,
                enabled: !sent,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: l10n?.authEmailLabel ?? 'Email',
                ),
              ),
              if (sent) ...[
                const SizedBox(height: 12),
                TextField(
                  key: const ValueKey('reset-code'),
                  controller: code,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText:
                        l10n?.authResetCodeLabel ?? 'Code from the email',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  key: const ValueKey('reset-password'),
                  controller: newPassword,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText:
                        l10n?.authResetNewPasswordLabel ?? 'New password',
                  ),
                ),
              ],
              if (fieldError != null) ...[
                const SizedBox(height: 8),
                Text(
                  fieldError!,
                  style: TextStyle(
                    color: Theme.of(sheetContext).colorScheme.error,
                  ),
                ),
              ],
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () async {
                  if (!sent) {
                    try {
                      await repo.requestPasswordReset(email.text.trim());
                    } catch (e, st) {
                      debugPrint('password reset request failed: $e\n$st');
                      TraceLogger.instance.error(
                          'auth', 'password reset request failed',
                          error: e, stackTrace: st);
                      if (!sheetContext.mounted) return;
                      AppSnack.error(
                        sheetContext,
                        l10n?.authNetworkError ??
                            'Could not reach the server. Check your '
                                'connection and try again.',
                      );
                      return;
                    }
                    setSheetState(() => sent = true);
                    return;
                  }
                  if (newPassword.text.length < 8) {
                    setSheetState(() => fieldError =
                        l10n?.authPasswordTooShort ?? 'At least 8 characters');
                    return;
                  }
                  try {
                    await repo.confirmPasswordReset(
                      email: email.text.trim(),
                      code: code.text.trim(),
                      newPassword: newPassword.text,
                    );
                  } catch (e, st) {
                    // Expected user error (wrong/expired code) — warn.
                    debugPrint('password reset rejected: $e\n$st');
                    TraceLogger.instance.warn(
                        'auth', 'password reset rejected',
                        error: e, stackTrace: st);
                    setSheetState(() => fieldError =
                        l10n?.authResetInvalidCode ??
                            'That code is invalid or expired.');
                    return;
                  }
                  if (!sheetContext.mounted) return;
                  Navigator.of(sheetContext).pop();
                },
                child: Text(
                  sent
                      ? (l10n?.authResetSubmit ?? 'Set new password')
                      : (l10n?.authResetSendCode ?? 'Send code'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (!mounted) return;
    if (ref.read(authRepositoryProvider).currentUserId != null) {
      AppSnack.success(
        context,
        l10n?.authResetDone ?? 'Password updated — you are signed in.',
      );
    }
  }

  /// Browser OAuth (0051): the flow finishes out-of-app; the router
  /// reacts to the auth-state change when the callback returns.
  Future<void> _social(SocialProvider provider) async {
    final l10n = AppLocalizations.of(context);
    try {
      await ref.read(authRepositoryProvider).signInWithSocial(provider);
    } on AuthException catch (e, st) {
      TraceLogger.instance
          .error('auth', 'social sign-in failed', error: e, stackTrace: st);
      if (!mounted) return;
      AppSnack.error(
        context,
        l10n?.authSocialUnavailable(provider.label) ??
            '${provider.label} sign-in is not available yet — the server '
                'has not enabled it.',
      );
    } catch (e, st) {
      TraceLogger.instance
          .error('auth', 'social sign-in failed', error: e, stackTrace: st);
      if (!mounted) return;
      AppSnack.error(
        context,
        l10n?.authNetworkError ??
            'Could not reach the server. Check your connection.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: AppSpacing.xlAll,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const _Wordmark(),
                  const SizedBox(height: 8),
                  Text(
                    _isSignUp
                        ? (l10n?.authSignUpTitle ?? 'Create account')
                        : (l10n?.authSignInTitle ?? 'Sign in'),
                    style: Theme.of(context).textTheme.titleMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  if (_isSignUp) ...[
                    TextFormField(
                      controller: _displayName,
                      decoration: InputDecoration(
                        labelText:
                            l10n?.authDisplayNameLabel ?? 'Display name',
                      ),
                      textInputAction: TextInputAction.next,
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? (l10n?.authFieldRequired ?? 'Required')
                          : null,
                    ),
                    const SizedBox(height: 12),
                  ],
                  TextFormField(
                    controller: _email,
                    decoration: InputDecoration(
                      labelText: l10n?.authEmailLabel ?? 'Email',
                    ),
                    keyboardType: TextInputType.emailAddress,
                    autofillHints: const [AutofillHints.email],
                    textInputAction: TextInputAction.next,
                    validator: (v) => (v == null || !v.contains('@'))
                        ? (l10n?.authFieldRequired ?? 'Required')
                        : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _password,
                    decoration: InputDecoration(
                      labelText: l10n?.authPasswordLabel ?? 'Password',
                      suffixIcon: IconButton(
                        tooltip: _obscurePassword
                            ? (l10n?.authShowPassword ?? 'Show password')
                            : (l10n?.authHidePassword ?? 'Hide password'),
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                        onPressed: () => setState(
                          () => _obscurePassword = !_obscurePassword,
                        ),
                      ),
                    ),
                    obscureText: _obscurePassword,
                    autofillHints: const [AutofillHints.password],
                    onFieldSubmitted: (_) => _submit(),
                    validator: (v) => (v == null || v.length < 8)
                        ? (l10n?.authPasswordTooShort ??
                            'At least 8 characters')
                        : null,
                  ),
                  if (!_isSignUp)
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: _busy ? null : _resetPasswordSheet,
                        child: Text(
                          l10n?.authForgotPassword ?? 'Forgot password?',
                        ),
                      ),
                    ),
                  const SizedBox(height: 24),
                  // The last answer stays in the form (#1649): six
                  // different sentences for six different outcomes, and
                  // never the server's own words.
                  if (_lastResult case final result?
                      when authOutcomeText(result, l10n) != null) ...[
                    InlineBanner(
                      key: const ValueKey('auth-outcome'),
                      icon: result.outcome == AuthOutcome.verificationRequired
                          ? Icons.mark_email_unread_outlined
                          : Icons.error_outline,
                      severity:
                          result.outcome == AuthOutcome.verificationRequired
                              ? InlineBannerSeverity.info
                              : InlineBannerSeverity.error,
                      text: authOutcomeText(result, l10n)!,
                    ),
                    const SizedBox(height: 12),
                  ],
                  FilledButton(
                    onPressed: _busy ? null : _submit,
                    child: _busy
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(
                            _isSignUp
                                ? (l10n?.authSignUpButton ?? 'Create account')
                                : (l10n?.authSignInButton ?? 'Sign in'),
                          ),
                  ),
                  const SizedBox(height: 12),
                  // Social sign-in (0051): browser-based Supabase OAuth —
                  // no vendor SDKs. The session lands via
                  // the deskilo:// callback; errors (provider not enabled
                  // on the server) surface as a snack.
                  Row(children: [
                    const Expanded(child: Divider()),
                    // #1205 — Flexible, not a bare Padding: at a large
                    // text scale "or continue with" is wider than the
                    // rules leave it, and a fixed child in a Row answers
                    // that by overflowing off the right of a phone.
                    // Flexible lets the sentence wrap to two lines
                    // instead, which is what the rest of this form does.
                    Flexible(
                      child: Padding(
                        padding:
                            const EdgeInsets.symmetric(horizontal: 8),
                        child: Text(
                          l10n?.authContinueWith ?? 'or continue with',
                          style: Theme.of(context).textTheme.bodySmall,
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                    const Expanded(child: Divider()),
                  ]),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    alignment: WrapAlignment.center,
                    children: [
                      for (final provider in SocialProvider.values)
                        OutlinedButton(
                          key: ValueKey('auth-social-${provider.name}'),
                          onPressed:
                              _busy ? null : () => _social(provider),
                          child: Text(provider.label),
                        ),
                    ],
                  ),
                  // #662 — badge sign-in, offered only when this device
                  // can actually read one, and never while creating an
                  // account (a brand-new member holds no badge).
                  //
                  // Deliberately NOT gated on the workspace flag: before
                  // sign-in the app has no workspace, so it has no flags,
                  // and `enabledFeatures` would decide on behalf of a
                  // workspace it never read. The badge names the
                  // workspace, so the flag is enforced server-side
                  // (0124) and a workspace that has not opted in refuses
                  // at the scan — with the same words a stranger's card
                  // gets.
                  if (!_isSignUp)
                    FutureBuilder<bool>(
                      future: _badgeReader,
                      builder: (context, snapshot) =>
                          snapshot.data == true
                              ? Padding(
                                  padding: const EdgeInsets.only(top: 12),
                                  child: OutlinedButton.icon(
                                    key: const ValueKey('auth-badge'),
                                    onPressed: _busy
                                        ? null
                                        : () =>
                                            showBadgeSignInSheet(context),
                                    icon: const Icon(
                                      Icons.contactless_outlined,
                                    ),
                                    label: Text(
                                      l10n?.badgeSignInEntry ??
                                          'Sign in with a badge',
                                    ),
                                  ),
                                )
                              : const SizedBox.shrink(),
                    ),
                  const SizedBox(height: 12),
                  // #1379 — no account is needed to look around, so the
                  // offer sits beside the two that do need one.
                  const DemoEntryButton(),
                  TextButton(
                    onPressed: _busy
                        ? null
                        : () => setState(() => _isSignUp = !_isSignUp),
                    child: Text(
                      _isSignUp
                          ? (l10n?.authToggleToSignIn ??
                              'Already have an account? Sign in')
                          : (l10n?.authToggleToSignUp ??
                              'New here? Create an account'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// #1205 — the logo and the name, as one lockup.
///
/// The boot splash shows the app's face for a second and used to hand
/// over to a sign-in screen that dropped it, so the brand vanished at
/// exactly the moment a new member is deciding whether they opened the
/// right app. Same artwork as the launcher icon, now beside the name
/// rather than instead of it.
class _Wordmark extends StatelessWidget {
  const _Wordmark();

  /// Tied to the title's own size rather than fixed, so the mark grows
  /// with the text scale instead of shrinking beside it.
  static const double _size = 40;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scaled = MediaQuery.textScalerOf(context).scale(_size);
    return Row(
      // A lockup, not a banner: the pair stays together in the middle
      // of the column however wide the screen is.
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        ClipRRect(
          borderRadius: AppRadius.mdAll,
          child: Image.asset(
            'assets/icon/icon_full.png',
            key: const ValueKey('signin-logo'),
            width: scaled,
            height: scaled,
            // The word beside it is the accessible name; announcing the
            // mark as well would say "DesKilo" twice.
            excludeFromSemantics: true,
            // The asset ships with the app; if it ever goes missing,
            // signing in must not fail over a logo.
            errorBuilder: (_, _, _) => SizedBox.square(
              dimension: scaled,
              child: const Icon(Icons.event_seat_outlined),
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Flexible(
          child: Text(
            l10n?.appTitle ?? 'DesKilo',
            style: Theme.of(context).textTheme.headlineMedium,
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }
}
