// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1649 — the real thing, against a disposable LOCAL Supabase with
// Mailpit: a sign-up sends a confirmation link and no session; following
// the link confirms; the password then signs in; a recovery code from
// the e-mail sets a new password; the new one signs in and the old one
// is refused; an update failure injected AFTER the code was redeemed is
// reported as exactly that, and the retry completes. MockClient tests
// prove the mapping; only this proves the wire.
//
// Runs only with a local stack up (`supabase start`, config.toml:
// confirmations on, Mailpit on 54324) and DESKILO_LOCAL_AUTH=1; skipped
// otherwise, and never against a hosted project. E-mails stay in Mailpit.
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:deskilo/features/auth/data/supabase_auth_repository.dart';
import 'package:deskilo/features/auth/domain/auth_outcome.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../helpers/real_async.dart';

const _enabled = 'DESKILO_LOCAL_AUTH';
final _armed = Platform.environment[_enabled] == '1';
final _apiUrl =
    Platform.environment['SUPABASE_LOCAL_URL'] ?? 'http://127.0.0.1:54321';
final _mailpit =
    Platform.environment['MAILPIT_URL'] ?? 'http://127.0.0.1:54324';
// The CLI's demo anon key — a local stack's, never a project's.
final _anonKey = Platform.environment['SUPABASE_LOCAL_ANON_KEY'] ??
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwi'
        'cm9sZSI6ImFub24iLCJleHAiOjE5ODM4MTI5OTZ9.'
        'CRXP1A7WOeoJeXxjNni43kdQwgnWNReilDMblYTn_I0';

class _MemoryStorage extends GotrueAsyncStorage {
  final Map<String, String> _items = {};

  @override
  Future<String?> getItem({required String key}) async => _items[key];

  @override
  Future<void> setItem({required String key, required String value}) async =>
      _items[key] = value;

  @override
  Future<void> removeItem({required String key}) async => _items.remove(key);
}

/// Forwards everything, except that while [failUserUpdate] is on, the
/// password update answers 500 — the failure the adapter must report as
/// "code accepted, password not saved", not as a bad code.
class _Injecting extends http.BaseClient {
  final _inner = http.Client();
  bool failUserUpdate = false;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    if (failUserUpdate &&
        request.method == 'PUT' &&
        request.url.path.endsWith('/auth/v1/user')) {
      return Future.value(http.StreamedResponse(
        Stream.value(utf8.encode('{"message":"injected"}')),
        500,
        headers: {'content-type': 'application/json'},
      ));
    }
    return _inner.send(request);
  }
}

/// The Mailpit message to [email] whose text matches [pattern], polled
/// for real through [untilReal] — the mailer is a separate process.
Future<String> mailTo(String email, Pattern pattern) async {
  String? found;
  await untilReal(() async {
    final search = await http.get(Uri.parse(
        '$_mailpit/api/v1/search?query=${Uri.encodeQueryComponent('to:$email')}'));
    final messages =
        (jsonDecode(search.body) as Map)['messages'] as List? ?? const [];
    for (final m in messages) {
      final id = (m as Map)['ID'];
      final full = await http.get(Uri.parse('$_mailpit/api/v1/message/$id'));
      final text = (jsonDecode(full.body) as Map)['Text'] as String? ?? '';
      if (text.contains(pattern)) {
        found = text;
        return true;
      }
    }
    return false;
  }, what: 'an e-mail to $email matching $pattern');
  return found!;
}

void main() {
  test('sign-up → confirmation link → sign-in; recovery code → new '
      'password; injected update failure → not saved, then retried',
      () async {
    final client = _Injecting();
    final repo = SupabaseAuthRepository(SupabaseClient(
      _apiUrl,
      _anonKey,
      httpClient: client,
      authOptions: AuthClientOptions(pkceAsyncStorage: _MemoryStorage()),
    ));
    // A fresh address per run: the stack is disposable, the run is not
    // the only one it ever saw.
    final email = 'fixture-${Random.secure().nextInt(1 << 32)}@example.test';
    const first = 'first-password-1649';
    const second = 'second-password-1649';
    const third = 'third-password-1649';

    // 1. Confirmations on: an e-mail, no session.
    final signedUp = await repo.signUp(
        email: email, password: first, displayName: 'Fixture');
    expect(signedUp.outcome, AuthOutcome.verificationRequired);
    expect(repo.currentUserId, isNull);
    final refused = await repo.signInWithPassword(email: email, password: first);
    expect(refused.refusal, AuthRefusal.emailNotConfirmed);

    // 2. The link in the e-mail confirms; the same password now signs in.
    final confirmation = await mailTo(email, 'type=signup');
    final link = RegExp(r'https?://\S+type=signup\S*').firstMatch(confirmation)!;
    final follow = http.Request('GET', Uri.parse(link[0]!))
      ..followRedirects = false;
    final landed = await follow.send();
    expect(landed.statusCode, inInclusiveRange(300, 399),
        reason: 'gotrue confirms and redirects');
    final signedIn = await repo.signInWithPassword(email: email, password: first);
    expect(signedIn.outcome, AuthOutcome.authenticated);
    await repo.signOut();

    // 3. Recovery: the code from the e-mail sets a new password.
    expect((await repo.requestPasswordReset(email)).outcome,
        AuthOutcome.recoveryVerificationRequired);
    final recovery = await mailTo(email, RegExp(r'\b\d{6}\b'));
    final code = RegExp(r'\b(\d{6})\b').firstMatch(recovery)![1]!;
    final completed = await repo.confirmPasswordReset(
        email: email, code: code, newPassword: second);
    expect(completed.outcome, AuthOutcome.completed);
    await repo.signOut();
    expect((await repo.signInWithPassword(email: email, password: second))
        .outcome, AuthOutcome.authenticated);
    await repo.signOut();
    expect((await repo.signInWithPassword(email: email, password: first))
        .refusal, AuthRefusal.credentials);

    // 4. Same again, with the update failing after the code was redeemed.
    expect((await repo.requestPasswordReset(email)).outcome,
        AuthOutcome.recoveryVerificationRequired);
    final again = await mailTo(email, RegExp('(?!$code)\\b\\d{6}\\b'));
    final code2 = RegExp(r'\b(\d{6})\b')
        .allMatches(again)
        .map((m) => m[1]!)
        .firstWhere((c) => c != code);
    client.failUserUpdate = true;
    final notSaved = await repo.confirmPasswordReset(
        email: email, code: code2, newPassword: third);
    expect(notSaved.outcome,
        AuthOutcome.recoverySessionReadyButPasswordNotUpdated);
    expect(repo.currentUserId, isNull, reason: 'held back until saved');
    client.failUserUpdate = false;
    expect((await repo.updateRecoveredPassword(third)).outcome,
        AuthOutcome.completed);
    expect(repo.currentUserId, isNotNull);
    await repo.signOut();
    expect((await repo.signInWithPassword(email: email, password: third))
        .outcome, AuthOutcome.authenticated);
    expect((await repo.signInWithPassword(email: email, password: second))
        .refusal, AuthRefusal.credentials);
  },
      skip: _armed ? false : 'needs a local Supabase + Mailpit; set $_enabled=1',
      timeout: const Timeout(Duration(minutes: 2)));
}
