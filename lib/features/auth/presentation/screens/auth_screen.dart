// SPDX-License-Identifier: MIT
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show AuthException;

import '../../../../l10n/app_localizations.dart';
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
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${l10n?.authGenericError ?? 'Authentication failed.'}'
            '\n${e.message}',
          ),
        ),
      );
    } catch (e, st) {
      // No server involved: connectivity, DNS, TLS … (#99 was a missing
      // INTERNET permission surfacing as this generic path).
      debugPrint('auth failed before reaching the server: $e\n$st');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            l10n?.authNetworkError ??
                'Could not reach the server. Check your connection and '
                    'try again.',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
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
                    ),
                    obscureText: true,
                    autofillHints: const [AutofillHints.password],
                    onFieldSubmitted: (_) => _submit(),
                    validator: (v) => (v == null || v.length < 8)
                        ? (l10n?.authPasswordTooShort ??
                            'At least 8 characters')
                        : null,
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
