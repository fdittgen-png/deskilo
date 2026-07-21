// SPDX-License-Identifier: 0BSD
//
// The workspace side of #231: the whatsappGroup field and its #232
// contract (whatsappGroupUri null when no group is configured), the
// prefix rule mirroring the 0029 column check, and the fake's write
// path.
import 'package:deskilo/features/workspace/domain/workspace.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/mock_providers.dart';

void main() {
  group('Workspace.whatsappGroup (#231)', () {
    const bare = Workspace(
      id: 'ws-1',
      name: 'Test Space',
      countryCode: 'DE',
      currencyCode: 'EUR',
      timezone: 'Europe/Berlin',
      inviteCode: 'GOODCODE22',
    );

    test('defaults to empty (no group configured, pre-0029 rows too)', () {
      expect(bare.whatsappGroup, '');
    });

    test('whatsappGroupUri is null when empty — the #232 contract', () {
      expect(bare.whatsappGroupUri, isNull);
    });

    test('whatsappGroupUri is the launchable invite link when set', () {
      final workspace = bare.copyWith(
        whatsappGroup: 'https://chat.whatsapp.com/AbCdEf123456',
      );
      expect(
        workspace.whatsappGroupUri,
        Uri.parse('https://chat.whatsapp.com/AbCdEf123456'),
      );
    });
  });

  group('WhatsappGroupRules (#231)', () {
    test('pins the invite-link prefix the validator and 0029 check share',
        () {
      expect(WhatsappGroupRules.linkPrefix, 'https://chat.whatsapp.com/');
    });

    test('accepts empty (clears) and real chat.whatsapp.com links', () {
      expect(WhatsappGroupRules.isValid(''), isTrue);
      expect(
        WhatsappGroupRules.isValid('https://chat.whatsapp.com/AbCdEf'),
        isTrue,
      );
    });

    test('rejects anything that is not a group invite link', () {
      expect(WhatsappGroupRules.isValid('https://example.com/x'), isFalse);
      expect(WhatsappGroupRules.isValid('chat.whatsapp.com/AbCdEf'), isFalse);
      expect(
        WhatsappGroupRules.isValid('http://chat.whatsapp.com/AbCdEf'),
        isFalse,
      );
      expect(WhatsappGroupRules.isValid('https://wa.me/33612345678'), isFalse);
    });
  });

  group('FakeWorkspaceRepository.setWhatsappGroup (#231)', () {
    test('writes onto the workspace row and records the last value',
        () async {
      final repo = FakeWorkspaceRepository.withWorkspace();

      await repo.setWhatsappGroup(
        'ws-1',
        'https://chat.whatsapp.com/AbCdEf123456',
      );

      expect(
        repo.lastWhatsappGroup,
        'https://chat.whatsapp.com/AbCdEf123456',
      );
      final workspaces = await repo.fetchMyWorkspaces();
      expect(
        workspaces.single.whatsappGroup,
        'https://chat.whatsapp.com/AbCdEf123456',
      );

      // '' clears the link again.
      await repo.setWhatsappGroup('ws-1', '');
      expect((await repo.fetchMyWorkspaces()).single.whatsappGroup, '');
    });
  });
}
