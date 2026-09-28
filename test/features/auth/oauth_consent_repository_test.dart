// SPDX-License-Identifier: AGPL-3.0-or-later
// #1648: the pinned SDK is exercised over HTTP fixtures. Purpose checks precede
// auto-approval, changed clients and foreign returns are refused, and failures
// expose no provider response text. Real Auth proof lives in the runtime helper.
import 'dart:convert';
import 'package:deskilo/features/auth/data/supabase_oauth_consent_repository.dart';
import 'package:deskilo/features/auth/domain/oauth_consent.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _id = 'abcdefghijklmnopqrstuvwxyzABCDEF';
const _user = {'id': 'user-1', 'aud': 'authenticated', 'role': 'authenticated',
  'created_at': '2026-09-27T00:00:00Z', 'app_metadata': <String,Object?>{},
  'user_metadata': <String,Object?>{}};
const _context = {'purpose':'identity_federation','client_id':'identity-client',
  'local_user_id':'user-1','target_installation_id':'organization',
  'target_auth_url':'https://organization.example/auth/v1'};
const _callback = 'https://organization.example/auth/v1/callback';

void main() {
  late SupabaseClient client;
  late SupabaseOAuthConsentRepository repository;
  late Map<String,Object?> context;
  late Object details;
  late List<String> calls;
  setUp(() async {
    calls = [];
    context = Map.of(_context);
    details = {'authorization_id':_id, 'client':{'id':'identity-client'},
      'user':_user,'scope':'openid profile','redirect_uri':_callback};
    client = SupabaseClient('https://canonical.example','test-key',
      authOptions: const AuthClientOptions(autoRefreshToken:false),
      httpClient: MockClient((request) async {
        calls.add(request.url.path);
        final Object answer;
        if (request.url.path.endsWith('/token')) {
          answer = {'access_token':'at','refresh_token':'rt','token_type':'bearer',
            'expires_in':3600,'user':_user};
        } else if (request.url.path.endsWith('/rpc/oauth_authorization_context')) {
          expect(jsonDecode(request.body), {'p_authorization_id':_id});
          answer = context;
        } else if (request.url.path.endsWith('/consent')) {
          answer = {'redirect_url':'$_callback?code=one-use&state=opaque'};
        } else {
          answer = details;
        }
        return http.Response(jsonEncode(answer),200,
          headers:{'content-type':'application/json'}, request:request);
      }));
    await client.auth.signInWithPassword(email:'person@example.test',password:'fixture');
    calls.clear();
    repository = SupabaseOAuthConsentRepository(client);
  });
  tearDown(() async => client.dispose());

  test('checks protected context before details and sends actual approval', () async {
    final initial = await repository.context(_id);
    final request = await repository.identityRequest(_id,initial);
    expect(request.returnUri,isNull);
    final result = await repository.approve(_id,initial);
    expect(result.host,'organization.example');
    expect(calls.take(3),[
      '/rest/v1/rpc/oauth_authorization_context',
      '/rest/v1/rpc/oauth_authorization_context',
      '/auth/v1/oauth/authorizations/$_id',
    ]);
    expect(calls.last,'/auth/v1/oauth/authorizations/$_id/consent');
  });

  test('already-approved redirect still requires protected identity purpose', () async {
    details = {'redirect_url':'$_callback?code=one-use'};
    final initial = await repository.context(_id);
    expect((await repository.identityRequest(_id,initial)).returnUri?.path,
        '/auth/v1/callback');
    context['purpose']='mcp';
    final before = calls.length;
    await expectLater(repository.identityRequest(_id,initial),
        throwsA(isA<OAuthConsentUnavailable>()));
    expect(calls.length,before+1,reason:'no SDK auto-approval after purpose changed');
  });

  test('foreign redirect and mismatched details fail closed', () async {
    final initial = await repository.context(_id);
    for (final answer in [
      {'redirect_url':'https://other.example/callback?code=secret'},
      {'authorization_id':_id,'client':{'id':'other-client'},'user':_user,
        'scope':'openid profile','redirect_uri':_callback},
      {'authorization_id':_id,'client':{'id':'identity-client'},'user':_user,
        'scope':'openid email','redirect_uri':_callback},
    ]) {
      details=answer;
      await expectLater(repository.identityRequest(_id,initial),
          throwsA(isA<OAuthConsentUnavailable>()));
    }
  });

  test('approval rechecks registration before issuing a code', () async {
    final initial = await repository.context(_id);
    context['target_installation_id']='another-installation';
    await expectLater(repository.approve(_id,initial),
        throwsA(isA<OAuthConsentUnavailable>()));
    expect(calls.where((path)=>path.endsWith('/consent')),isEmpty);
  });
}
