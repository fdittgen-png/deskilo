// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4105 -- what an e-invoice will need is told before the invoice is issued,
// from the parties the issue would store, with the very judgement Send uses
// on the parties the issued invoice stored: the two moments name the same
// gaps. Without a configured channel nothing is warned about; while an
// essential is missing, only the essentials are named.
import 'package:deskilo/features/money/domain/einvoice_channel_check.dart';
import 'package:deskilo/features/money/domain/einvoice_gateway.dart';
import 'package:deskilo/features/money/domain/invoice_issue_draft.dart';
import 'package:deskilo/features/money/presentation/issue_judgement.dart';
import 'package:deskilo/features/money/providers/money_providers.dart';
import 'package:deskilo/features/workspace/domain/workspace.dart';
import 'package:deskilo_invoice_model/deskilo_invoice_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _Drafts implements InvoiceIssueDrafts {
  _Drafts(this.answer);
  final Map<String, Object?> answer;

  @override
  Future<IssueDraft> issueDraft({
    required String workspaceId,
    required String memberId,
    required String period,
    InvoiceKind kind = InvoiceKind.full,
    String? replacesId,
    String correctionReason = '',
  }) async => IssueDraft.fromAnswer(answer);
}

const _seller = {
  'name': 'Space',
  'street': '1 rue de la Paix',
  'city': 'Paris',
  'country': 'FR',
  'endpoint_id': '123456789',
  'endpoint_scheme': '0225',
};
const _buyer = {
  'name': 'Client',
  'street': '2 rue du Bac',
  'city': 'Paris',
  'country': 'FR',
};

Future<IssueJudgement> _judge(
  WidgetTester tester, {
  required Map<String, Object?> answer,
  required EInvoiceGatewayConfig gateway,
}) async {
  late WidgetRef captured;
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        invoiceIssueDraftsProvider.overrideWithValue(_Drafts(answer)),
        eInvoiceGatewayProvider.overrideWith((ref) async => gateway),
      ],
      child: Consumer(
        builder: (context, ref, _) {
          captured = ref;
          return const SizedBox();
        },
      ),
    ),
  );
  return judgeIssue(
    captured,
    const Workspace(
      id: 'ws',
      name: 'Space',
      countryCode: 'FR',
      inviteCode: '',
      currencyCode: 'EUR',
      timezone: 'Europe/Paris',
    ),
    (
      memberId: 'm',
      period: '2026-09',
      kind: InvoiceKind.full,
      replacesId: null,
      correctionReason: '',
    ),
  );
}

const _configured = EInvoiceGatewayConfig(configured: true, provider: 'peppol');

void main() {
  testWidgets('the gaps told before issuing are the gaps that remove Send', (
    tester,
  ) async {
    final judged = await _judge(
      tester,
      answer: {
        'missing': <String>[],
        'parties': {'seller': _seller, 'buyer': _buyer},
      },
      gateway: _configured,
    );
    expect(judged.missing, isEmpty);
    expect(judged.gaps, isNotEmpty);
    // The issued invoice stores these parties; Send judges them the same way.
    final atSend = channelGapsFor(
      _configured,
      seller: InvoiceParty.fromSnapshot(_seller),
      buyer: InvoiceParty.fromSnapshot(_buyer),
    );
    expect(judged.gaps, atSend);
    expect(judged.gaps, contains(ChannelGap.buyerEndpoint));
  });

  testWidgets('without a configured channel nothing is warned about', (
    tester,
  ) async {
    final judged = await _judge(
      tester,
      answer: {
        'missing': <String>[],
        'parties': {'seller': _seller, 'buyer': _buyer},
      },
      gateway: EInvoiceGatewayConfig.notConfigured,
    );
    expect(judged.gaps, isEmpty);
  });

  testWidgets('while an essential is missing, only the essentials are named', (
    tester,
  ) async {
    final judged = await _judge(
      tester,
      answer: {
        'missing': ['buyer_region'],
        'parties': null,
      },
      gateway: _configured,
    );
    expect(judged.missing, ['buyer_region']);
    expect(judged.gaps, isEmpty);
  });
}
