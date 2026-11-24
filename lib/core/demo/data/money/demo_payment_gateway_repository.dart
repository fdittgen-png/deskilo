// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:deskilo/core/settings/setting_defaults.g.dart';
import 'package:deskilo/features/money/domain/invoice_commands.dart';
import 'package:deskilo/features/money/domain/payment_claims.dart';
import 'package:deskilo/features/money/domain/payment_gateway_repository.dart';
import 'package:deskilo/features/money/domain/payment_intent.dart';
import 'package:deskilo/features/money/domain/payment_provider.dart';
import 'package:deskilo/features/money/domain/payment_test_check.dart';
import 'package:deskilo/features/money/domain/settlement_fetch.dart';
import 'package:deskilo_invoice_model/deskilo_invoice_model.dart';
import 'package:deskilo_money_kernel/deskilo_money_kernel.dart' show yearMonth;

import '../money_repository.dart';
import 'demo_member_account_commands.dart' show checkDemoClaim;

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

  /// #3556 — the provider does not answer (a test's network, say).
  bool unreachable = false;

  /// #3556 — the next claimed order is made but its answer is lost on the
  /// way back (the app retries it under the same request id).
  bool loseNextAnswer = false;

  /// #3556 — the request ids of the claimed orders, in order.
  final requestIds = <String?>[];

  /// #3556 — false: a payment function older than the claim (it says
  /// nothing of claims).
  bool takesClaims = true;

  /// #3556 — the function drops the claim and says it named none.
  bool dropsClaim = false;

  bool takesContinuations = true;

  /// #4165 — false: a payment function older than the invoices without a
  /// month (its probe does not say `standalone`).
  bool takesStandalone = true;

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
        claims: takesClaims,
        continuations: takesContinuations,
        standalone: takesStandalone,
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
    return url != null ? PaymentOrderStart(approveUrl: url, orderId: 'order-${_m.paymentOrders.length}') : _atWorkspace(_withoutApprovalUrl(provider, memberId, amountCents, currencyCode, period, requestId), workspaceId);
  }

  PaymentOrderStart _atWorkspace(PaymentOrderStart start, String workspaceId) {
    final approval = start.approveUrl;
    if (approval == null) return start;
    return PaymentOrderStart(
      approveUrl: approval.replace(queryParameters: {...approval.queryParameters, 'workspace': workspaceId}),
      orderId: start.orderId, alreadyPaid: start.alreadyPaid, missing: start.missing, claimed: start.claimed,
    );
  }

  @override
  Future<PaymentOrderStart> createClaimOrder({
    required PaymentProvider provider,
    required String workspaceId,
    required String memberId,
    required String currencyCode,
    required InvoiceClaim claim,
    String? requestId,
  }) async {
    // #3556 — a provider that cannot be reached: nothing is ordered.
    if (unreachable) {
      throw const PaymentGatewayException(503, 'provider not reachable');
    }
    // #4165 — a standalone payment names its request id, and has no month:
    // the intent's period is bookkeeping, the month it was opened.
    if (claim.standalone && requestId == null) {
      throw const PaymentGatewayException(400, 'invalid_request');
    }
    final period = claim.standalone ? yearMonth(_m.clock().year, _m.clock().month) : claim.period;
    // a retried request is the payment it already opened: answered as it was,
    // never refused for holding its own invoices (the replay of 0797)
    final replay = requestId == null ? null : _m.paymentIntents
        .where((p) => p.requestId == requestId && p.status == 'created').firstOrNull;
    if (replay == null) {
      // the claim is refused as the server refuses it (0797, 0901)
      checkDemoClaim(_m, memberId: memberId, claim: claim, currency: currencyCode);
    }
    requestIds.add(requestId);
    // an answer lost before the order was made leaves nothing behind; one
    // lost after it (the stand-in's) leaves the order, found again by its id
    if (loseNextAnswer && !standIn) {
      loseNextAnswer = false;
      throw const PaymentGatewayException(503, 'the answer was lost');
    }
    final start = await createPaymentOrder(
      provider: provider,
      workspaceId: workspaceId,
      memberId: memberId,
      amountCents: claim.amountCents,
      currencyCode: currencyCode,
      period: period,
      requestId: requestId,
    );
    // #3556 — the invoices this payment names are in it until it is paid,
    // failed or withdrawn.
    if (start.orderId case final order?) {
      _m.claims[order] = [...claim.invoiceIds];
      final at = _m.paymentIntents.indexWhere((p) => p.orderId == order);
      if (at >= 0) {
        _m.paymentIntents[at] = _with(_m.paymentIntents[at],
            status: _m.paymentIntents[at].status, claimedInvoiceIds: [...claim.invoiceIds],
            allocationMode: claim.standalone ? PaymentAllocationMode.explicit : null);
      }
    }
    if (loseNextAnswer) {
      loseNextAnswer = false;
      throw const PaymentGatewayException(503, 'the answer was lost');
    }
    return PaymentOrderStart(
      approveUrl: start.approveUrl,
      orderId: start.orderId,
      missing: start.missing,
      alreadyPaid: start.alreadyPaid,
      claimed: dropsClaim ? 0 : claim.invoiceIds.length,
    );
  }

  /// The provider's own window (#4217), the platform setting's default.
  Duration _resendWindowOf(String provider) => Duration(
        minutes: switch (provider) {
          'mollie' || 'wero' => SettingDefaults.paymentsResendWindowMollieMinutes,
          'paypal' => SettingDefaults.paymentsResendWindowPaypalMinutes,
          _ => SettingDefaults.paymentsResendWindowStripeMinutes,
        },
      );

  /// The same persisted facts the host uses for its continuation action.
  String? continuationState(String? paymentId) {
    final payment = _m.paymentIntents.where((p) => p.orderId == paymentId).firstOrNull;
    if (payment == null) return null;
    if (_m.withdrawnClaims.contains(paymentId)) return 'withdrawn';
    if (payment.status != 'created') return payment.status;
    if (_m.clock().difference(payment.createdAt) > _resendWindowOf(payment.provider)) return 'awaiting_provider';
    if (payment.requestId == null || payment.claimedInvoiceIds.isEmpty) return 'unavailable';
    return 'ready';
  }

  @override
  Future<PaymentOrderStart> resumeClaimOrder({
    required String workspaceId,
    required String memberId,
    required String paymentId,
  }) async {
    if (unreachable) throw const PaymentGatewayException(503, 'provider not reachable');
    final payment = _m.paymentIntents.where((p) => p.orderId == paymentId).firstOrNull;
    if (payment == null || payment.memberId != memberId || continuationState(paymentId) != 'ready' ||
        payment.claimedInvoiceIds.any((id) => !_m.invoices.any((i) =>
            i.id == id && i.workspaceId == workspaceId && i.memberId == memberId))) {
      throw const ClaimRefused(ClaimRefusal.notProcessing);
    }
    requestIds.add(payment.requestId);
    return _atWorkspace(PaymentOrderStart(approveUrl: _approvalUri(payment.orderId),
      orderId: payment.orderId, claimed: payment.claimedInvoiceIds.length), workspaceId);
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
    final earlier = requestId == null ? null : _m.paymentIntents
        .where((p) => p.requestId == requestId).firstOrNull;
    if (earlier != null) {
      final known = earlier.orderId;
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
        requestId: requestId, currency: currencyCode,
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
        // #3556 — a failed payment frees the invoices it named.
        _m.claims.remove(orderId);
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
      reversal: (at: _m.clock(), reason: reason),
    );
  }

  PaymentIntent _with(
    PaymentIntent p, {
    required String status,
    String? captureId,
    ({DateTime at, String reason})? reversal,
    List<String>? claimedInvoiceIds,
    PaymentAllocationMode? allocationMode,
  }) => PaymentIntent(
    id: p.id,
    requestId: p.requestId, currency: p.currency,
    claimedInvoiceIds: claimedInvoiceIds ?? p.claimedInvoiceIds,
    memberId: p.memberId,
    provider: p.provider,
    orderId: p.orderId,
    period: p.period,
    amountCents: p.amountCents,
    status: status,
    createdAt: p.createdAt,
    captureId: captureId ?? p.captureId,
    reference: p.reference,
    reversedAt: reversal?.at ?? p.reversedAt,
    reversalReason: reversal?.reason ?? p.reversalReason,
    reversalReviewedAt: p.reversalReviewedAt,
    allocationMode: allocationMode ?? p.allocationMode,
    system: p.system,
  );

  /// The credit the capture books and its parts on the member's open bills
  /// of the period, oldest first: what `apply_payment_to_invoices` does.
  Future<void> _settle(PaymentIntent intent) async {
    final now = _m.clock();
    // #4165 — an explicit payment is posted in the month it arrived and is
    // spent only by the allocations that name it (0901)
    final explicit = intent.allocationMode == PaymentAllocationMode.explicit;
    final ledgerId = 'demo-online-${intent.id}';
    _m.ledger.add(
      LedgerEntry(
        id: ledgerId,
        memberId: intent.memberId,
        kind: LedgerKind.credit,
        category: LedgerCategory.payment,
        amountCents: intent.amountCents,
        description: 'Online payment ${intent.reference}',
        period: explicit ? yearMonth(now.year, now.month) : intent.period,
        createdAt: now,
        occurredOn: now,
        allocationMode: intent.allocationMode.wire,
      ),
    );
    // #3556 — a payment that named its invoices is applied to them alone
    // (0797); its claim ends with the capture. One whose claim was
    // withdrawn applies to nothing: the money is the member's credit.
    final withdrawn = _m.withdrawnClaims.contains(intent.orderId);
    final claim = withdrawn ? const <String>[] : _m.claims.remove(intent.orderId);
    final open = [
      for (final inv in _m.invoices)
        if (inv.memberId == intent.memberId &&
            (claim == null || claim.contains(inv.id)) &&
            (explicit ? inv.period == null : inv.period == intent.period) &&
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
