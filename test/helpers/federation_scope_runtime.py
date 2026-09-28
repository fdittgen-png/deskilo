# SPDX-License-Identifier: AGPL-3.0-or-later
"""#1648: actual canonical Auth enforces identity-client scopes before issuing tokens.

Uses the existing disposable Stack; never accepts a remote project or real user.
This proves the hook and raw API containment only, not target federation or UI.
Run with an explicit local DOCKER_HOST and --disposable. No credentials printed.
"""
import argparse
import base64
import hashlib
import json
import secrets
import shutil
import sys
import tempfile
import urllib.error
import urllib.parse
import urllib.request
import uuid
from pathlib import Path
REPO = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(REPO / 'scripts/recovery'))
from runtime import Stack, NoRedirect
from reporting import environment
parser = argparse.ArgumentParser(description='Verify identity scope policy with disposable real Auth')
parser.add_argument('--disposable', action='store_true', required=True)
parser.parse_args()
fixture = Path(tempfile.mkdtemp(prefix='deskilo-federation-scope-')).resolve()
s=Stack(fixture / 'canonical', REPO, 'hook-auth')
checks=[]
def raw(method,path,body=None,authorization=None,form=False):
    headers={'apikey':s.credentials['ANON_KEY']}
    if authorization: headers['Authorization']=authorization
    if body is not None:
        headers['Content-Type']='application/x-www-form-urlencoded' if form else 'application/json'
        body=(urllib.parse.urlencode(body) if form else json.dumps(body)).encode()
    req=urllib.request.Request(s.url+path,headers=headers,data=body,method=method)
    opener=urllib.request.build_opener(urllib.request.ProxyHandler({}),NoRedirect())
    try:
        with opener.open(req,timeout=30) as r: return r.status,r.headers,r.read()
    except urllib.error.HTTPError as e:return e.code,e.headers,e.read()
def claims(token):
    part=token.split('.')[1]
    return json.loads(base64.urlsafe_b64decode(part+'='*(-len(part)%4)))
try:
    s.create()
    config=s.path/'supabase/config.toml'
    text=config.read_text().replace('site_url = "https://fdittgen-png.github.io/deskilo/"','site_url = "http://127.0.0.1:1"')
    text+='\n[auth.oauth_server]\nenabled = true\nauthorization_url_path = "/oauth/consent"\nallow_dynamic_registration = false\n[auth.hook.custom_access_token]\nenabled = true\nuri = "pg-functions://postgres/public/identity_federation_token_hook"\n'
    config.write_text(text)
    s.start()
    checks.append('actual_auth_hook_config_started')
    signup=json.loads(s.request('POST','/auth/v1/signup',body={'email':'hook@deskilo.test','password':secrets.token_urlsafe(24)+'aA1!'},token=s.credentials['ANON_KEY']))
    native=signup['access_token']
    assert s.sql('select count(*) from public.workspaces') == '0'
    assert s.sql('select count(*) from public.database_administrators') == '0'
    checks.append('native_signup_without_admin_or_workspace')
    redirect='http://127.0.0.1:2/callback'
    client=json.loads(s.request('POST','/auth/v1/admin/oauth/clients',body={'client_name':'Deskilo identity federation test','client_type':'confidential','redirect_uris':[redirect],'token_endpoint_auth_method':'client_secret_basic','grant_types':['authorization_code','refresh_token'],'response_types':['code']},expect=(200,201)))
    cid=str(uuid.UUID(client['client_id']))
    basic='Basic '+base64.b64encode((cid+':'+client['client_secret']).encode()).decode()
    s.sql("select public.operator_register_identity_federation_client('"+cid+"','"+str(uuid.uuid4())+"','http://127.0.0.1:2'); select public.operator_set_identity_federation_client('"+cid+"',true);")
    checks.append('operator_bootstrap_without_app_admin')
    def exchange(scope):
        verifier=secrets.token_urlsafe(48)
        challenge=base64.urlsafe_b64encode(hashlib.sha256(verifier.encode()).digest()).decode().rstrip('=')
        state=secrets.token_urlsafe(24);nonce=secrets.token_urlsafe(24)
        query=urllib.parse.urlencode({'client_id':cid,'redirect_uri':redirect,'response_type':'code','scope':scope,'state':state,'nonce':nonce,'code_challenge':challenge,'code_challenge_method':'S256'})
        status,headers,_=raw('GET','/auth/v1/oauth/authorize?'+query)
        assert status in (302,303), 'authorize did not redirect'
        aid=urllib.parse.parse_qs(urllib.parse.urlparse(headers['Location']).query)['authorization_id'][0]
        details=json.loads(s.request('GET','/auth/v1/oauth/authorizations/'+aid,token=native))
        if 'redirect_url' in details: approved=details
        else:
            assert details['client']['id']==cid
            approved=json.loads(s.request('POST','/auth/v1/oauth/authorizations/'+aid+'/consent',token=native,body={'action':'approve'}))
        values=urllib.parse.parse_qs(urllib.parse.urlparse(approved['redirect_url']).query)
        assert values['state']==[state]
        body={'grant_type':'authorization_code','code':values['code'][0],'redirect_uri':redirect,'code_verifier':verifier}
        status,_,data=raw('POST','/auth/v1/oauth/token',body,authorization=basic,form=True)
        return status,json.loads(data),body,nonce
    status,tokens,used,nonce=exchange('openid profile')
    assert status==200 and tokens.get('id_token'), 'allowed token issuance failed'
    ident=claims(tokens['id_token']);access=claims(tokens['access_token'])
    assert ident['sub']==signup['user']['id'] and ident['client_id']==cid and ident['nonce']==nonce
    assert ident['iss']==s.url+'/auth/v1'
    assert ident['aud'] in (cid, [cid])
    assert 'email' not in ident and access['client_id']==cid
    checks.append('real_allowed_access_and_id_tokens_without_email_claim')
    status,_,_=raw('POST','/auth/v1/oauth/token',used,authorization=basic,form=True)
    assert status==400
    checks.append('real_authorization_code_reuse_rejected')
    status,_,data=raw('POST','/auth/v1/oauth/token',
        {'grant_type':'refresh_token','refresh_token':tokens['refresh_token']},
        authorization=basic,form=True)
    refreshed=json.loads(data)
    assert status==200 and claims(refreshed['access_token'])['client_id']==cid
    assert set(claims(refreshed['access_token'])['scope'].split()) == {'openid', 'profile'}
    # Pinned Auth refresh returns access/refresh tokens, not a fresh ID token.
    assert 'id_token' not in refreshed
    checks.append('real_refresh_preserves_identity_scope')
    for scope in ['openid email','openid profile email','openid phone']:
        status,denied,_,_=exchange(scope)
        assert status>=400 and 'access_token' not in denied and 'id_token' not in denied, 'disallowed scope minted tokens'
    checks.append('real_overridden_scopes_refused_before_token_issuance')
    status,_,profile_data=raw('GET','/rest/v1/profiles?select=id',authorization='Bearer '+native)
    assert status==200 and any(row['id']==signup['user']['id'] for row in json.loads(profile_data))
    for token in [tokens['access_token'], tokens['id_token']]:
        status,_,_=raw('GET','/rest/v1/profiles?select=id',authorization='Bearer '+token)
        assert status in (401,403)
    checks.append('native_raw_api_passes_identity_access_and_id_tokens_refused')
    s.sql("select public.operator_set_identity_federation_client('"+cid+"',false)")
    status,denied,_,_=exchange('openid profile')
    assert status>=400 and 'access_token' not in denied
    checks.append('disabled_client_cannot_issue_new_tokens')
    status,_,data=raw('POST','/auth/v1/oauth/token',
        {'grant_type':'refresh_token','refresh_token':refreshed['refresh_token']},
        authorization=basic,form=True)
    assert status>=400 and 'access_token' not in json.loads(data)
    checks.append('disabled_client_cannot_refresh_existing_session')
    report={'status':'pass','checks':checks,'scope':'disposable_canonical_auth_only','cli':'2.118.0','environment':environment(s),'not_exercised':['target_provider','native_router','hosted_project']}
finally:
    s.close()
    shutil.rmtree(fixture)
print(json.dumps(report),flush=True)
