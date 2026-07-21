// SPDX-License-Identifier: 0BSD
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show AuthException;

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/trace/trace_logger.dart';
import '../../../../core/ui/app_snack.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/social_provider.dart';
import '../../providers/auth_providers.dart';

/// Email + password sign-in / sign-up. Navigation after success is handled
/// by the router's auth redirect, not by this screen.
class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _displayName = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _isSignUp = false;
  bool _busy = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _displayName.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _busy = true);
    final l10n = AppLocalizations.of(context);
    final repo = ref.read(authRepositoryProvider);
    try {
      if (_isSignUp) {
        await repo.signUp(
          email: _email.text.trim(),
          password: _password.text,
          displayName: _displayName.text.trim(),
        );
      } else {
        await repo.signInWithPassword(
          email: _email.text.trim(),
          password: _password.text,
        );
      }
    } on AuthException catch (e, st) {
      // Real server answer (wrong password, signups disabled, …) — show
      // the server's message rather than a blanket failure (#99).
      debugPrint('auth rejected: $e\n$st');
      // Expected user errors (wrong password, …) — warn, not error; the
      // server message is surfaced in the snackbar below.
      TraceLogger.instance.warn('auth', 'auth rejected by server',
          error: e, stackTrace: st);
      if (!mounted) return;
      AppSnack.error(
        context,
        '${l10n?.authGenericError ?? 'Authentication failed.'}'
        '\n${e.message}',
      );
    } catch (e, st) {
      // No server involved: connectivity, DNS, TLS … (#99 was a missing
      // INTERNET permission surfacing as this generic path).
      debugPrint('auth failed before reaching the server: $e\n$st');
      TraceLogger.instance.error(
          'auth', 'auth failed before reaching the server',
          error: e, stackTrace: st);
      if (!mounted) return;
      AppSnack.error(
        context,
        l10n?.authNetworkError ??
            'Could not reach the server. Check your connection and '
                'try again.',
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
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
                  Text(
                    l10n?.appTitle ?? 'DesKilo',
                    style: Theme.of(context).textTheme.headlineMedium,
                    textAlign: TextAlign.center,
                  ),
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
                  // no vendor SDKs, F-Droid-clean. The session lands via
                  // the deskilo:// callback; errors (provider not enabled
                  // on the server) surface as a snack.
                  Row(children: [
                    const Expanded(child: Divider()),
                    Padding(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 8),
                      child: Text(
                        l10n?.authContinueWith ?? 'or continue with',
                        style: Theme.of(context).textTheme.bodySmall,
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
                  const SizedBox(height: 12),
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
