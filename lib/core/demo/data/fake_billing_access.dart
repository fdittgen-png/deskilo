// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4164 B2 -- the in-memory billing-access grants: the Demo and the widget
// tests read this, with the server's own rules (0910): the right, one answer
// for an unusable code, a request id that replays, an account that is not
// handed a code twice, a revocation that erases nothing.
import 'package:deskilo/features/money/domain/billing_access.dart';
import 'package:deskilo/features/money/domain/billing_customer.dart';

/// How long an invitation's code can be used (the server's default, 0910) and
/// how long ago the seeded grant was invited and accepted.
const _inviteValidity = Duration(days: 14);
const _seedInvitedAgo = Duration(days: 30);
const _seedAcceptedAfter = Duration(days: 1);

class FakeBillingAccessRepository implements BillingAccessRepository {
  FakeBillingAccessRepository({
    required this.customerOf,
    required this.workspaceNameOf,
    required this.clock,
    this.mayManage = _always,
    String account = 'demo-account',
    String Function()? accountOf,
  }) : _accountOf = accountOf ?? (() => account);

  static bool _always() => true;

  /// Whether the signed-in person holds `manageBillingCustomers`.
  bool Function() mayManage;

  /// The instant a stamp takes, so a test and the Demo are never wall-clock.
  final DateTime Function() clock;

  /// The billing customer [subjectId] of [workspaceId], or null.
  final BillingParty? Function(String workspaceId, String subjectId) customerOf;

  /// The business a code names, as the preview answers it.
  final String Function(String workspaceId) workspaceNameOf;

  /// The signed-in account (who accepts). #4168 — the Demo reads it from the
  /// persona, so a grant is held by one login and never by whoever is looking.
  String get account => _accountOf();
  final String Function() _accountOf;

  /// An error the next call raises, once (a refusal or a transport failure).
  Object? failNext;

  /// The calls made, for tests.
  final List<String> calls = [];

  final List<_Row> _rows = [];
  int _next = 1;

  /// Seeds a grant [subjectId] of [workspaceId] already accepted by
  /// [principal] (this account when null): what a customer who accepted
  /// earlier holds.
  void seedAccepted(
    String workspaceId,
    String subjectId,
    String code, {
    String? principal,
  }) {
    final now = clock();
    _rows.add(
      _Row(
          id: 'demo-grant-${_next++}',
          workspaceId: workspaceId,
          subjectId: subjectId,
          requestId: 'seed-$subjectId',
          code: code,
          invitedAt: now.subtract(_seedInvitedAgo),
          expiresAt: now.subtract(_seedInvitedAgo).add(_inviteValidity),
        )
        ..principal = principal ?? account
        ..acceptedAt = now.subtract(_seedInvitedAgo).add(_seedAcceptedAfter),
    );
  }

  /// The subjects this account holds a live grant for.
  Set<String> get heldSubjects => {
    for (final r in _rows)
      if (r.principal == account && r.revokedAt == null) r.subjectId,
  };

  /// #4168 — the same, with the business each grant belongs to.
  Set<({String workspaceId, String subjectId})> get heldGrants => {
    for (final r in _rows)
      if (r.principal == account && r.revokedAt == null)
        (workspaceId: r.workspaceId, subjectId: r.subjectId),
  };

  Never _refuse(BillingAccessRefusalKind kind) =>
      throw BillingAccessRefusal(kind);

  void _check() {
    final failure = failNext;
    if (failure != null) {
      failNext = null;
      Error.throwWithStackTrace(failure, StackTrace.current);
    }
  }

  _Row? _byCode(String code) {
    final wanted = normaliseBillingCode(code);
    for (final r in _rows) {
      if (r.code == wanted) return r;
    }
    return null;
  }

  bool _usable(_Row? r) =>
      r != null &&
      r.revokedAt == null &&
      (r.principal == null
          ? r.expiresAt.isAfter(clock())
          : r.principal == account);

  @override
  Future<List<BillingAccessGrant>> grantsOf(
    String workspaceId,
    String subjectId,
  ) async {
    calls.add('grantsOf');
    _check();
    if (!mayManage()) _refuse(BillingAccessRefusalKind.notAllowed);
    return [
      for (final r in _rows.reversed)
        if (r.workspaceId == workspaceId && r.subjectId == subjectId)
          r.toGrant(),
    ];
  }

  @override
  Future<BillingAccessInvitation> invite(
    String workspaceId,
    String subjectId,
    String requestId,
  ) async {
    calls.add('invite');
    _check();
    if (!mayManage()) _refuse(BillingAccessRefusalKind.notAllowed);
    for (final r in _rows) {
      if (r.workspaceId == workspaceId && r.requestId == requestId) {
        if (r.subjectId != subjectId) {
          _refuse(BillingAccessRefusalKind.requestReused);
        }
        return BillingAccessInvitation(
          grantId: r.id,
          code: r.code,
          expiresAt: r.expiresAt,
          replayed: true,
        );
      }
    }
    if (customerOf(workspaceId, subjectId) == null) {
      _refuse(BillingAccessRefusalKind.notACustomer);
    }
    final now = clock();
    final row = _Row(
      id: 'demo-grant-${_next++}',
      workspaceId: workspaceId,
      subjectId: subjectId,
      requestId: requestId,
      code: 'DEMO${(_next + 1000).toString().padLeft(4, '0')}',
      invitedAt: now,
      expiresAt: now.add(_inviteValidity),
    );
    _rows.add(row);
    return BillingAccessInvitation(
      grantId: row.id,
      code: row.code,
      expiresAt: row.expiresAt,
    );
  }

  @override
  Future<BillingAccessPreview> preview(String code) async {
    calls.add('preview');
    _check();
    final r = _byCode(code);
    if (!_usable(r)) _refuse(BillingAccessRefusalKind.codeUnusable);
    return BillingAccessPreview(
      workspaceName: workspaceNameOf(r!.workspaceId),
      billedAs: customerOf(r.workspaceId, r.subjectId)?.displayName ?? '',
      accepted: r.principal != null,
      expiresAt: r.expiresAt,
    );
  }

  @override
  Future<BillingAccessAccepted> accept(String code) async {
    calls.add('accept');
    _check();
    final r = _byCode(code);
    if (r != null && r.revokedAt == null && r.principal == account) {
      return r.accepted(replayed: true);
    }
    if (!_usable(r) || r!.principal != null) {
      _refuse(BillingAccessRefusalKind.codeUnusable);
    }
    // One live grant per account and subject: a second code answers the first.
    for (final o in _rows) {
      if (o.workspaceId == r.workspaceId &&
          o.subjectId == r.subjectId &&
          o.principal == account &&
          o.revokedAt == null) {
        r.revokedAt = clock();
        return o.accepted(replayed: true);
      }
    }
    r
      ..principal = account
      ..acceptedAt = clock();
    return r.accepted(replayed: false);
  }

  @override
  Future<void> revoke(String grantId, {String reason = ''}) async {
    calls.add('revoke');
    _check();
    final r = _rows.where((r) => r.id == grantId).firstOrNull;
    if (r == null) _refuse(BillingAccessRefusalKind.unknownGrant);
    if (r.principal != account && !mayManage()) {
      _refuse(BillingAccessRefusalKind.notAllowed);
    }
    if (r.revokedAt != null) return;
    if (reason.trim().length > billingRevokeReasonMax) {
      _refuse(BillingAccessRefusalKind.reasonTooLong);
    }
    r
      ..revokedAt = clock()
      ..revokeReason = reason.trim();
  }
}

class _Row {
  _Row({
    required this.id,
    required this.workspaceId,
    required this.subjectId,
    required this.requestId,
    required this.code,
    required this.invitedAt,
    required this.expiresAt,
  });

  final String id, workspaceId, subjectId, requestId, code;
  final DateTime invitedAt, expiresAt;
  String? principal;
  DateTime? acceptedAt, revokedAt;
  String revokeReason = '';

  BillingAccessGrant toGrant() => BillingAccessGrant(
    id: id,
    subjectId: subjectId,
    invitedAt: invitedAt,
    expiresAt: expiresAt,
    acceptedAt: acceptedAt,
    revokedAt: revokedAt,
    revokeReason: revokeReason,
  );

  BillingAccessAccepted accepted({required bool replayed}) =>
      BillingAccessAccepted(
        grantId: id,
        workspaceId: workspaceId,
        subjectId: subjectId,
        replayed: replayed,
      );
}
