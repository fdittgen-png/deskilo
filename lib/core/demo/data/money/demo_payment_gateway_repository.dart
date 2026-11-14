// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:deskilo/features/money/domain/invoice_commands.dart';
import 'package:deskilo/features/money/domain/ledger_entry.dart';
import 'package:deskilo/features/money/domain/payment_gateway_repository.dart';
import 'package:deskilo/features/money/domain/payment_intent.dart';
import 'package:deskilo/features/money/domain/payment_provider.dart';
import 'package:deskilo/features/money/domain/payment_test_check.dart';
import 'package:deskilo/features/money/domain/settlement_fetch.dart';

import '../money_repository.dart';

/// #3961 — what the Demo's stand-in for the provider's page answers.
enum DemoPaymentOutcome { paid, cancelled, noAnswer }

/// #3961 — the address the Demo's order "opens": it names the order, and the
/// app's approval seam answers it with the stand-in page, never a browser.
Uri _approvalUri(String orderId) => Uri(
  scheme: 'demo-provider',
  host: 'approve',
  queryParameters: {'order': orderId},
);

/// The order a stand-in address names, or null for any other address.
String? demoProviderOrderOf(Uri uri) =>
    uri.scheme == 'demo-provider' ? uri.queryParameters['order'] : null;

/// #2591 — the demo's online payments and their provider credentials, answered
/// from one space's in-memory money store ([FakeMoneyRepository]); every other
/// port of that space reads and writes the same store.
class DemoPaymentGateway implements PaymentGatewayRepository {
  DemoPaymentGateway(this._m);

  final FakeMoneyRepository _m;

  /// #3961 — true where the Demo stands in for a provider: an order opens
  /// the stand-in page and its answer settles the intent. False keeps the
  /// rehearsal of the other Demo spaces and of the tests' own fakes.
  bool standIn = false;

  final Map<String, String> _orderOfRequest = {};

  @override
  Future<List<PaymentIntent>> fetchPaymentIntents(String workspaceId) async =>
      List.of(_m.paymentIntents);

  @override
  Future<void> reviewPaymentReversal(String intentId) async {
    final i = _m.paymentIntents.indexWhere((p) => p.id == intentId);
    if (i < 0 || _m.paymentIntents[i].status != 'reversed') {
      throw StateError('only a reversed payment is reviewed');
    }
    final intent = _m.paymentIntents[i];
    if (intent.reversalReviewedAt == null) {
      _m.paymentIntents[i] = intent.reviewedAt(_m.clock());
    }
  }

  @override
  Future<PaymentGatewayConfig> fetchPaymentConfig(String workspaceId) async =>
      PaymentGatewayConfig(
        providers: List.of(_m.paymentProviders),
        missing: _m.paymentMissing,
      );

  @override
  Future<Map<PaymentProvider, PaymentProviderStatus>> fetchPaymentGatewayStatus(
    String workspaceId,
  ) async => Map.of(_m.paymentStatus);

  /// #3504 -- the Demo has no provider to read: it says one settlement was
  /// recorded, so the action can be rehearsed.
  @override
  Future<SettlementFetch> fetchProviderSettlements(
    String workspaceId,
    PaymentProvider provider,
  ) async => const SettlementFetch(imported: 1);

  /// The demo is a rehearsal: it opens no payment, and its keys are the
  /// installation's, which the test cannot read.
  @override
  Future<PaymentTestCheck> testPaymentKeys(String workspaceId) async =>
      PaymentTestCheck(
        verdict: _m.paymentStatus.isEmpty
            ? PaymentTestVerdict.noProvider
            : PaymentTestVerdict.unverified,
        takesPayments: false,
        modes: {
          for (final provider in _m.paymentStatus.keys)
            provider: PaymentKeyMode.installation,
        },
      );

  @override
  Future<void> setPaymentCredentials(
    String workspaceId,
    PaymentProvider provider,
    Map<String, String> config,
  ) async {
    _m.savedPaymentConfigs.add((provider, config));
  }

  @override
  Future<void> clearPaymentProvider(
    String workspaceId,
    PaymentProvider provider,
  ) async {
    _m.clearedProviders.add(provider);
  }

  @override
  Future<PaymentOrderStart> createPaymentOrder({
    required PaymentProvider provider,
    required String workspaceId,
    required String memberId,
    required int amountCents,
    required String currencyCode,
    required String period,
    String? requestId,
  }) async {
    _m.paymentOrders.add((provider, amountCents));
    final url = _m.paymentApprovalUrl;
    return url != null ? PaymentOrderStart(approveUrl: url, orderId: 'order-1') : _withoutApprovalUrl(provider, memberId, amountCents, currencyCode, period, requestId);
  }

  /// No approval address was given: the Demo's stand-in opens an order of its
  /// own where it stands in for the provider, and anywhere else the provider
  /// is simply not set up.
  PaymentOrderStart _withoutApprovalUrl(
    PaymentProvider provider,
    String memberId,
    int amountCents,
    String currencyCode,
    String period,
    String? requestId,
  ) => standIn
      ? _openStandInOrder(
          provider,
          memberId,
          amountCents,
          currencyCode,
          period,
          requestId,
        )
      : const PaymentOrderStart(missing: ['PAYPAL_CLIENT_ID']);

  /// An order of the Demo's stand-in: a retried request is the order it
  /// already opened, a paid one answers [PaymentOrderStart.alreadyPaid], and
  /// a failed one is not retried but replaced.
  PaymentOrderStart _openStandInOrder(
    PaymentProvider provider,
    String memberId,
    int amountCents,
    String currencyCode,
    String period,
    String? requestId,
  ) {
    if (amountCents <= 0 || currencyCode != _m.invoiceCommands.currency) {
      throw const PaymentGatewayException(400, 'amount or currency refused');
    }
    final known = _orderOfRequest[requestId];
    if (known != null) {
      final earlier = _m.paymentIntents.firstWhere((p) => p.orderId == known);
      if (earlier.status == 'captured') {
        return const PaymentOrderStart(alreadyPaid: true);
      }
      if (earlier.status == 'created') {
        return PaymentOrderStart(
          approveUrl: _approvalUri(known),
          orderId: known,
        );
      }
    }
    final n = _m.paymentIntents.length + 1;
    final now = _m.clock();
    final orderId = 'demo-order-$n';
    _m.paymentIntents.add(
      PaymentIntent(
        id: 'demo-intent-$n',
        memberId: memberId,
        provider: provider.wireName,
        orderId: orderId,
        period: period,
        amountCents: amountCents,
        status: 'created',
        createdAt: now,
        reference: 'PAY-${now.year}-${n.toString().padLeft(4, '0')}',
      ),
    );
    if (requestId != null) _orderOfRequest[requestId] = orderId;
    return PaymentOrderStart(
      approveUrl: _approvalUri(orderId),
      orderId: orderId,
    );
  }

  /// What the stand-in page answers for [orderId]: paid captures the intent
  /// and credits the member once, as the settlement does; cancelled fails it;
  /// no answer leaves it as it was, to be answered later. An answer for an
  /// order that is no longer open changes nothing: never a second credit.
  Future<void> resolveOrder(String orderId, DemoPaymentOutcome outcome) async {
    final i = _m.paymentIntents.indexWhere((p) => p.orderId == orderId);
    if (i < 0) throw StateError('unknown order');
    final intent = _m.paymentIntents[i];
    if (intent.status != 'created') return;
    switch (outcome) {
      case DemoPaymentOutcome.noAnswer:
        return;
      case DemoPaymentOutcome.cancelled:
        _m.paymentIntents[i] = _with(intent, status: 'failed');
      case DemoPaymentOutcome.paid:
        _m.paymentIntents[i] = _with(
          intent,
          status: 'captured',
          captureId: 'demo-capture-${i + 1}',
        );
        await _settle(intent);
    }
  }

  /// The provider reports a captured payment reversed (a dispute, a refund
  /// made at the provider): it is marked, and nothing is posted on its own.
  Future<void> reverseOrder(String orderId, String reason) async {
    final i = _m.paymentIntents.indexWhere((p) => p.orderId == orderId);
    if (i < 0 || _m.paymentIntents[i].status != 'captured') return;
    _m.paymentIntents[i] = _with(
      _m.paymentIntents[i],
      status: 'reversed',
      reversedAt: _m.clock(),
      reversalReason: reason,
    );
  }

  PaymentIntent _with(
    PaymentIntent p, {
    required String status,
    String? captureId,
    DateTime? reversedAt,
    String? reversalReason,
  }) => PaymentIntent(
    id: p.id,
    memberId: p.memberId,
    provider: p.provider,
    orderId: p.orderId,
    period: p.period,
    amountCents: p.amountCents,
    status: status,
    createdAt: p.createdAt,
    captureId: captureId ?? p.captureId,
    reference: p.reference,
    reversedAt: reversedAt ?? p.reversedAt,
    reversalReason: reversalReason ?? p.reversalReason,
    reversalReviewedAt: p.reversalReviewedAt,
    system: p.system,
  );

  /// The credit the capture books and its parts on the member's open bills
  /// of the period, oldest first: what `apply_payment_to_invoices` does.
  Future<void> _settle(PaymentIntent intent) async {
    final now = _m.clock();
    final ledgerId = 'demo-online-${intent.id}';
    _m.ledger.add(
      LedgerEntry(
        id: ledgerId,
        memberId: intent.memberId,
        kind: LedgerKind.credit,
        category: LedgerCategory.payment,
        amountCents: intent.amountCents,
        description: 'Online payment ${intent.reference}',
        period: intent.period,
        createdAt: now,
        occurredOn: now,
      ),
    );
    final open = [
      for (final inv in _m.invoices)
        if (inv.memberId == intent.memberId &&
            inv.period == intent.period &&
            inv.totalCents > 0 &&
            !inv.isVoided &&
            inv.currency == _m.invoiceCommands.currency)
          inv,
    ]..sort((a, b) => a.issuedAt.compareTo(b.issuedAt));
    var left = intent.amountCents;
    final parts = <PaymentAllocation>[];
    for (final inv in open) {
      final due = inv.totalCents - (_m.invoiceMatchesStore[inv.id]?.paidCents ?? 0);
      if (due <= 0 || left <= 0) continue;
      final take = due < left ? due : left;
      parts.add((invoiceId: inv.id, amountCents: take));
      left -= take;
    }
    if (parts.isEmpty) return;
    await _m.invoiceCommands.applyPaymentToInvoices(
      workspaceId: 'ws-1',
      paymentLedgerId: ledgerId,
      allocations: parts,
      note: intent.reference,
    );
  }
}
