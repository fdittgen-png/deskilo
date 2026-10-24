// SPDX-License-Identifier: AGPL-3.0-or-later
//
// The legacy personal addresses keep their exact meaning and parameters at
// their personal-shell addresses: `/me?tab=` names a destination, the
// account messenger's recipient becomes the conversation's path, finances
// keep their space, the memberships are My spaces, the servers sit under the
// account — and nothing else is relocated.
import 'package:deskilo/app/routes/me_adapters.dart';
import 'package:flutter_test/flutter_test.dart';

String? _of(String location) => personalShellAddressOf(Uri.parse(location));

void main() {
  test('a legacy tab names its destination; home and an unknown tab are '
      'Overview; no tab is left alone', () {
    expect(_of('/me?tab=discover'), '/me/discover');
    expect(_of('/me?tab=messages'), '/me/messages');
    expect(_of('/me?tab=me'), '/me/account');
    expect(_of('/me?tab=home'), '/me');
    expect(_of('/me?tab=spaces'), '/me', reason: 'never a legacy tab');
    expect(_of('/me?tab=nowhere'), '/me');
    expect(_of('/me'), isNull);
  });

  test('the account messenger keeps source and name; a recipient is the '
      'conversation', () {
    expect(_of('/account-messages'), '/me/messages/new');
    expect(_of('/account-messages?source=https%3A%2F%2Fa.example&name=Jane+Doe'),
        '/me/messages/new?source=https%3A%2F%2Fa.example&name=Jane+Doe');
    expect(
      _of('/account-messages?source=s&recipient=u-2&name=J'),
      '/me/messages/u-2?source=s&name=J',
    );
    expect(_of('/account-messages?recipient=a%2Fb'), '/me/messages/a%2Fb',
        reason: 'a recipient is one segment, whatever it holds');
    expect(_of('/account-messages?recipient=&source=s'), '/me/messages/new?source=s',
        reason: 'an empty recipient is no recipient');
    expect(_of('/account-messages?token=secret'), '/me/messages/new',
        reason: 'only source and name travel');
  });

  test('finances keep their space, memberships are My spaces, servers sit '
      'under the account', () {
    expect(_of('/account-activity'), '/me/data?view=finances');
    expect(_of('/account-activity?workspace=ws-1'),
        '/me/data?view=finances&workspace=ws-1');
    expect(_of('/account-activity?workspace='), '/me/data?view=finances');
    expect(_of('/profiles'), '/me/spaces');
    expect(_of('/connections'), '/me/account/connections');
  });

  test('nothing else is relocated', () {
    for (final other in ['/reserve', '/privacy', '/discover', '/p/x', '/auth']) {
      expect(_of(other), isNull, reason: other);
    }
  });

  test('the helpers carry only what they are told', () {
    expect(withQuery('/x', const {}), '/x');
    expect(withQuery('/x', const {'a': '1'}), '/x?a=1');
    expect(pickQuery(Uri.parse('/x?a=1&b=&c=3'), const ['a', 'b', 'd']),
        const {'a': '1'});
  });
}
