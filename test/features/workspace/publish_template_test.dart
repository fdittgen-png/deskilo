// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1656 group 4 — the server's refusal of an invitation text that still
// names the space is recognised, and nothing else is.
import 'package:deskilo/features/workspace/application/publish_template.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('the refusal is recognised by its sentence', () {
    expect(
        isInvitationTextRefusal(Exception(
            'the fr invitation text still names this space or its people; use placeholders')),
        isTrue);
    expect(isInvitationTextRefusal(Exception('only an owner publishes a template')), isFalse);
    expect(invitationTextsChoice, 'invitation_texts');
  });
}
