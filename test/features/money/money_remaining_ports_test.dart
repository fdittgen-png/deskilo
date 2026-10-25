// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2591 — the last groups of the money boundary are ports of their own:
// dunning, billing rules, document numbering, member-account commands,
// online payments and e-invoice transmission. A consumer is built with a
// fake of its one port; the composed repository hands every call to the
// port it was given; and the demo answers every port with its own adapter
// over one space's store.
import 'package:deskilo/core/demo/data/money/demo_billing_rules_repository.dart';
import 'package:deskilo/core/demo/data/money/demo_document_numbering.dart';
import 'package:deskilo/core/demo/data/money/demo_dunning_repository.dart';
import 'package:deskilo/core/demo/data/money/demo_einvoice_transmissions.dart';
import 'package:deskilo/core/demo/data/money/demo_invoice_queries.dart';
import 'package:deskilo/core/demo/data/money/demo_member_account_commands.dart';
import 'package:deskilo/core/demo/data/money/demo_payment_gateway_repository.dart';
import 'package:deskilo/core/demo/data/money_repository.dart';
import 'package:deskilo/core/demo/demo_fixture.dart';
import 'package:deskilo/core/demo/demo_scope.dart';
import 'package:deskilo/core/demo/seed/demo_second_space_seed.dart';
import 'package:deskilo/features/money/application/record_payment.dart';
import 'package:deskilo/features/money/application/save_dunning_rules.dart';
import 'package:deskilo/features/money/data/supabase_money_repository.dart';
import 'package:deskilo/features/money/domain/billing_rules.dart';
import 'package:deskilo/features/money/domain/billing_rules_repository.dart';
import 'package:deskilo/features/money/domain/document_numbering.dart';
import 'package:deskilo/features/money/domain/dunning.dart';
import 'package:deskilo/features/money/domain/dunning_repository.dart';
import 'package:deskilo/features/money/domain/einvoice_gateway.dart';
import 'package:deskilo/features/money/domain/einvoice_transmissions.dart';
import 'package:deskilo/features/money/domain/member_account_commands.dart';
import 'package:deskilo/features/money/domain/number_sequence.dart';
import 'package:deskilo/features/money/domain/payment_gateway_repository.dart';
import 'package:deskilo/features/money/domain/payment_intent.dart';
import 'package:deskilo/features/money/domain/payment_method.dart';
import 'package:deskilo/features/money/domain/payment_provider.dart';
import 'package:deskilo/features/money/domain/payment_test_check.dart';
import 'package:deskilo/features/money/domain/workspace_status.dart';
import 'package:deskilo/features/money/providers/money_providers.dart';
import 'package:deskilo/features/workspace/providers/workspace_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Answers only what the tests below ask; every other member throws, so a
/// consumer that reaches past its port fails loudly.
class _Dunning implements DunningRepository {
  final calls = <String>[];

  @override
  Future<DunningRules> fetchDunningRules(String workspaceId) async {
    calls.add('rules:$workspaceId');
    return DunningRules.defaults;
  }

  @override
  Future<void> setDunningRules(String workspaceId, DunningRules rules) async =>
      calls.add('set:$workspaceId');

  @override
  Future<Map<String, String>> fetchDunningHolds(String workspaceId) =>
      throw UnimplementedError();

  @override
  Future<int> sweepPaymentReminders(String workspaceId) =>
      throw UnimplementedError();

  @override
  Future<void> placeDunningHold(
    String invoiceId, {
    required String reason,
    String note = '',
  }) => throw UnimplementedError();

  @override
  Future<void> releaseDunningHold(String invoiceId) =>
      throw UnimplementedError();
}

class _Billing implements BillingRulesRepository {
  final calls = <String>[];

  @override
  Future<BillingRules> fetchBillingRules(String workspaceId) async {
    calls.add('billing:$workspaceId');
    return BillingRules.defaults;
  }

  @override
  Future<WorkspaceStatus> fetchWorkspaceStatus(
    String workspaceId,
    String from,
    String to,
  ) => throw UnimplementedError();

  @override
  Future<RepartitionRule> fetchRepartitionRule(String workspaceId) =>
      throw UnimplementedError();

  @override
  Future<void> setRepartitionRule(String workspaceId, RepartitionRule rule) =>
      throw UnimplementedError();

  @override
  Future<void> setBillingRules(String workspaceId, BillingRules rules) =>
      throw UnimplementedError();

  @override
  Future<int> sweepBillingInvoices(String workspaceId) =>
      throw UnimplementedError();
}

class _Numbering implements DocumentNumbering {
  final calls = <String>[];

  @override
  Future<String> previewDocumentNumber(
    String workspaceId,
    String journal,
  ) async {
    calls.add('preview:$workspaceId:$journal');
    return 'INV-0001';
  }

  @override
  Future<List<NumberSequence>> fetchNumberSequences(String workspaceId) =>
      throw UnimplementedError();

  @override
  Future<String> verifyInvoiceSignature(String invoiceId) =>
      throw UnimplementedError();

  @override
  Future<void> setNumberSequence(
    String workspaceId,
    NumberSequence sequence, {
    int? raiseNextValueTo,
  }) => throw UnimplementedError();
}

class _AccountCommands implements MemberAccountCommands {
  final calls = <String>[];

  @override
  Future<String> recordPayment({
    required String workspaceId,
    required String memberId,
    required int amountCents,
    String note = '',
    PaymentMethod? method,
    DateTime? paidOn,
    String? period,
  }) async {
    calls.add('pay:$workspaceId:$memberId:$amountCents');
    return 'event-1';
  }

  @override
  Future<void> recordServiceCharge({
    required String workspaceId,
    required String subjectMemberId,
    required String serviceId,
    required int quantity,
    String? period,
  }) => throw UnimplementedError();

  @override
  Future<String> buyPackage(String workspaceId, String packageId) =>
      throw UnimplementedError();

  @override
  Future<String> requestUsageCorrection(
    String recordId, {
    String reason = '',
  }) => throw UnimplementedError();

  @override
  Future<String> requestUsageRecordDelete(
    String recordId, {
    String reason = '',
  }) => throw UnimplementedError();
}

class _Payments implements PaymentGatewayRepository {
  final calls = <String>[];

  @override
  Future<List<PaymentIntent>> fetchPaymentIntents(String workspaceId) async {
    calls.add('intents:$workspaceId');
    return const [];
  }

  @override
  Future<PaymentGatewayConfig> fetchPaymentConfig(String workspaceId) =>
      throw UnimplementedError();

  @override
  Future<Map<PaymentProvider, PaymentProviderStatus>> fetchPaymentGatewayStatus(
    String workspaceId,
  ) => throw UnimplementedError();

  @override
  Future<PaymentTestCheck> testPaymentKeys(String workspaceId) =>
      throw UnimplementedError();

  @override
  Future<void> setPaymentCredentials(
    String workspaceId,
    PaymentProvider provider,
    Map<String, String> config,
  ) => throw UnimplementedError();

  @override
  Future<void> clearPaymentProvider(
    String workspaceId,
    PaymentProvider provider,
  ) => throw UnimplementedError();

  @override
  Future<PaymentOrderStart> createPaymentOrder({
    required PaymentProvider provider,
    required String workspaceId,
    required String memberId,
    required int amountCents,
    required String currencyCode,
    required String period,
    String? requestId,
  }) => throw UnimplementedError();
}

class _EInvoices implements EInvoiceTransmissions {
  final calls = <String>[];

  @override
  Future<Map<String, InvoiceTransmission>> fetchInvoiceTransmissions(
    String workspaceId,
  ) async {
    calls.add('transmissions:$workspaceId');
    return const {};
  }

  @override
  Future<EInvoiceGatewayConfig> fetchEInvoiceGateway(String workspaceId) =>
      throw UnimplementedError();

  @override
  Future<EInvoiceProviderStatus> fetchEInvoiceStatus(String workspaceId) =>
      throw UnimplementedError();

  @override
  Future<EInvoiceSubmission> sendEInvoice({
    required String workspaceId,
    required String invoiceId,
    required String fileName,
    required String mimeType,
    required List<int> bytes,
    String environment = 'prod',
    String destination = 'government',
    String format = '',
    String receiverScheme = '',
    String receiverId = '',
  }) => throw UnimplementedError();

  @override
  Future<EInvoiceSubmission> requestEInvoiceReceipt({
    required String workspaceId,
    required String transmissionId,
  }) => throw UnimplementedError();

  @override
  Future<void> setEInvoiceCredentials(
    String workspaceId,
    Map<String, String> config,
  ) => throw UnimplementedError();

  @override
  Future<void> clearEInvoiceCredentials(String workspaceId) =>
      throw UnimplementedError();
}

void main() {
  test('the composed repository hands each call to its own port', () async {
    final dunning = _Dunning();
    final billing = _Billing();
    final numbering = _Numbering();
    final accountCommands = _AccountCommands();
    final payments = _Payments();
    final eInvoices = _EInvoices();
    final repo = SupabaseMoneyRepository(
      SupabaseClient('http://localhost', 'anon'),
      dunning: dunning,
      billing: billing,
      numbering: numbering,
      accountCommands: accountCommands,
      payments: payments,
      eInvoices: eInvoices,
    );
    await repo.fetchDunningRules('w1');
    await repo.fetchBillingRules('w1');
    await repo.previewDocumentNumber('w1', 'invoice');
    await repo.recordPayment(workspaceId: 'w1', memberId: 'm1', amountCents: 9);
    await repo.fetchPaymentIntents('w1');
    await repo.fetchInvoiceTransmissions('w1');
    expect(dunning.calls, ['rules:w1']);
    expect(billing.calls, ['billing:w1']);
    expect(numbering.calls, ['preview:w1:invoice']);
    expect(accountCommands.calls, ['pay:w1:m1:9']);
    expect(payments.calls, ['intents:w1']);
    expect(eInvoices.calls, ['transmissions:w1']);
  });

  test('saving the dunning policy needs the dunning port alone', () async {
    final dunning = _Dunning();
    await SaveDunningRules(dunning).save('w1', DunningRules.defaults);
    expect(dunning.calls, ['set:w1']);
  });

  test('recording a payment needs the account commands alone', () async {
    final commands = _AccountCommands();
    final outcome = await Payments(commands).record(
      workspaceId: 'w1',
      memberId: 'm1',
      amountCents: 1200,
      paidOn: DateTime(2026, 8, 3),
    );
    expect(outcome, isA<PaymentRecorded>());
    expect(commands.calls, ['pay:w1:m1:1200']);
  });

  group('the demo adapters', () {
    test('read and write the one store the facade reads', () async {
      final money = FakeMoneyRepository();
      const rules = DunningRules(levels: 2, betweenDays: 10);
      await money.dunning.setDunningRules('ws-1', rules);
      expect(await money.fetchDunningRules('ws-1'), same(rules));

      await money.dunning.placeDunningHold('inv-1', reason: 'dispute');
      expect(await money.fetchDunningHolds('ws-1'), {'inv-1': 'dispute'});

      expect(
        await money.billing.fetchBillingRules('ws-1'),
        same(money.billingRules),
      );
      expect(
        await money.numbering.previewDocumentNumber('ws-1', 'invoice'),
        await money.previewDocumentNumber('ws-1', 'invoice'),
      );

      await money.accountCommands.recordPayment(
        workspaceId: 'ws-1',
        memberId: 'member-1',
        amountCents: 700,
      );
      expect(money.recordedPayments.single.amountCents, 700);
      expect(money.ledger, isEmpty, reason: 'a payment is only recorded');

      money.paymentIntents.add(
        PaymentIntent(
          id: 'pi-1',
          memberId: 'member-1',
          provider: 'paypal',
          orderId: 'order-1',
          period: '2026-08',
          amountCents: 700,
          status: 'created',
          createdAt: DateTime.utc(2026, 8),
        ),
      );
      expect(
        await money.paymentGateway.fetchPaymentIntents('ws-1'),
        money.paymentIntents,
      );
      expect(
        await money.eInvoices.fetchEInvoiceGateway('ws-1'),
        same(money.einvoiceGateway),
      );
    });

    test('each space answers every money port with its own adapter', () async {
      final fixture = DemoFixture.build();
      final container = ProviderContainer(overrides: demoOverrides(fixture));
      addTearDown(container.dispose);
      container.listen(currentWorkspaceProvider, (_, _) {});
      await container.read(currentWorkspaceProvider.future);

      void expectSpace(FakeMoneyRepository money) {
        expect(
          container.read(invoiceQueriesProvider),
          isA<DemoInvoiceQueries>(),
        );
        expect(container.read(dunningRepositoryProvider), same(money.dunning));
        expect(container.read(dunningRepositoryProvider), isA<DemoDunning>());
        expect(
          container.read(billingRulesRepositoryProvider),
          isA<DemoBillingRules>(),
        );
        expect(
          container.read(documentNumberingProvider),
          isA<DemoDocumentNumbering>(),
        );
        expect(
          container.read(memberAccountCommandsProvider),
          isA<DemoMemberAccountCommands>(),
        );
        expect(
          container.read(paymentGatewayRepositoryProvider),
          same(money.paymentGateway),
        );
        expect(
          container.read(paymentGatewayRepositoryProvider),
          isA<DemoPaymentGateway>(),
        );
        expect(
          container.read(eInvoiceTransmissionsProvider),
          isA<DemoEInvoiceTransmissions>(),
        );
        expect(
          container.read(invoiceQueriesProvider),
          same(money.invoiceQueries),
        );
      }

      expectSpace(fixture.money);
      container
          .read(activeWorkspaceIdProvider.notifier)
          .activate(demoSecondSpaceId);
      await container.read(currentWorkspaceProvider.future);
      expectSpace(fixture.secondSpace.money);
    });
  });
}
