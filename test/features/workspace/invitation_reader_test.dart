// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1652 — one reader for a code, a link or a whole pasted message: v2
// links keep the server they were issued on; v1 links and raw codes keep
// working; nothing it reads grants a role or names another server by
// accident.
import 'package:deskilo/core/backend/backend_settings.dart';
import 'package:deskilo/features/workspace/domain/invitation_answer.dart';
import 'package:deskilo/features/workspace/domain/invite_uri.dart';
import 'package:deskilo/features/workspace/domain/member.dart';
import 'package:flutter_test/flutter_test.dart';

const _here = BackendEndpoint(
  'https://here.example.org',
  'sb_publishable_here_key_0001',
);
const _there = BackendEndpoint(
  'https://there.example.org',
  'sb_publishable_there_key_0002',
);

void main() {
  group('v2 links name their server', () {
    test('encode → read round-trips code, server and label', () {
      final link = InviteUriCodec.encode(
        code: 'GOODCODE22',
        role: InviteRole.user,
        target: _there,
        targetLabel: 'Le Bocal',
      );
      final read = InvitationReader.read(link);
      expect(read.usable, isTrue);
      expect(read.version, 2);
      expect(read.code, 'GOODCODE22');
      expect(read.target!.endpoint.url, _there.url);
      expect(read.target!.label, 'Le Bocal');
      expect(read.belongsTo(_there), isTrue);
      expect(read.belongsTo(_here), isFalse);
      expect(
        read.belongsTo(null),
        isFalse,
        reason: 'an unknown server is not assumed',
      );
    });

    test('a v2 link inside a whole pasted message, and wrapped by a messenger', () {
      final link = InviteUriCodec.encode(
        code: 'GOODCODE22',
        role: InviteRole.user,
        target: _there,
      );
      final whole =
          'Hi! Join us on DesKilo.\nThe ID is:\nGOODCODE22\n(or scan — $link)\nSee you!';
      expect(InvitationReader.read(whole).target!.endpoint.url, _there.url);
      final wrapped = whole.replaceFirst(
        'code=GOODCODE22',
        'code=GOOD\nCODE22',
      );
      final read = InvitationReader.read(wrapped);
      expect(read.code, 'GOODCODE22');
      expect(read.target!.endpoint.url, _there.url);
    });

    test('the form the platform hands over (a slash before the query) keeps its server', () {
      final link = InviteUriCodec.encode(
        code: 'GOODCODE22',
        role: InviteRole.user,
        target: _there,
      ).replaceFirst('join?', 'join/?');
      expect(InvitationReader.read(link).target!.endpoint.url, _there.url);
    });

    test('a newer version is refused, not guessed at', () {
      expect(
        InvitationReader.read('deskilo://join?v=3&code=GOODCODE22').problem,
        InvitationProblem.unsupportedVersion,
      );
    });

    test('a server that is not a public server code is refused', () {
      for (final bad in [
        'deskilo://join?v=2&code=GOODCODE22&url=http%3A%2F%2Fthere.example.org&key=sb_publishable_there_key_0002',
        'deskilo://join?v=2&code=GOODCODE22&url=https%3A%2F%2Fthere.example.org&key=sb_secret_abcdefghijklmnopqrstuv',
        'deskilo://join?v=2&code=GOODCODE22',
      ]) {
        expect(
          InvitationReader.read(bad).problem,
          InvitationProblem.badTarget,
          reason: bad,
        );
      }
    });
  });

  group('legacy invitations keep working on the chosen server', () {
    test('v1 links, raw codes and monospace lines', () {
      for (final text in [
        'deskilo://join?role=user&code=GOODCODE22',
        'goodcode22',
        'Your code:\n```GOODCODE22```\nBye',
      ]) {
        final read = InvitationReader.read(text);
        expect(read.code, 'GOODCODE22', reason: text);
        expect(read.target, isNull);
        expect(read.belongsTo(_here), isTrue);
      }
    });

    test(
      'the role in a link is ignored: it is a hint the server never reads',
      () {
        final read = InvitationReader.read(
          'deskilo://join?role=owner&code=GOODCODE22',
        );
        expect(read.code, 'GOODCODE22');
      },
    );

    test(
      'nothing code-like, an unrelated URL and an oversized paste are noCode',
      () {
        for (final text in [
          '',
          '   ',
          'https://example.com/join?code=GOODCODE22',
          'Hello there, see you soon',
          'A1${'x' * InviteUriCodec.maxInputLength}',
        ]) {
          expect(
            InvitationReader.read(text).problem,
            InvitationProblem.noCode,
            reason: text.length.toString(),
          );
        }
      },
    );
  });

  group('the server answer is parsed defensively', () {
    test('known states and fields', () {
      final answer = InvitationAnswer.fromJson({
        'state': 'already_member',
        'workspace_id': 'ws-1',
        'workspace_name': 'Le Bocal',
        'offered_role': 'admin',
        'member_status': 'pending',
      });
      expect(answer.state, InvitationState.alreadyMember);
      expect(answer.offeredRole, InviteRole.admin);
      expect(answer.memberStatus, MemberStatus.pending);
      expect(answer.opensWorkspace, isTrue);
    });

    test('an unknown state is unknown, never a success; a paused member opens nothing', () {
      expect(
        InvitationAnswer.fromJson({'state': 'joined_forever'}).state,
        InvitationState.unknown,
      );
      expect(InvitationAnswer.fromJson(null).state, InvitationState.unknown);
      expect(
        InvitationAnswer.fromJson({
          'state': 'paused',
          'workspace_id': 'ws-1',
          'member_status': 'paused',
        }).opensWorkspace,
        isFalse,
      );
      expect(InvitationAnswer.fromJson({'state': 'valid'}).offeredRole, isNull);
    });
  });
}
