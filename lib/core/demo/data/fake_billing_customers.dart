// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4164 A2 -- the in-memory billing customers: the Demo's reference
// organisations and the widget tests read this, with the server's own rules
// (the revision check, the right, a customer only).
import 'package:deskilo/features/money/domain/billing_customer.dart';

class FakeBillingCustomerRepository implements BillingCustomerRepository {
  FakeBillingCustomerRepository({this.mayManage = _always});

  static bool _always() => true;

  /// Whether the signed-in person holds `manageBillingCustomers`.
  bool Function() mayManage;

  final Map<String, List<BillingParty>> _byWorkspace = {};
  int _next = 1;

  /// An error the next call raises, once (a refusal or a transport failure).
  Object? failNext;

  /// The calls the screen made, for tests.
  final List<String> calls = [];

  List<BillingParty> of(String workspaceId) =>
      _byWorkspace.putIfAbsent(workspaceId, () => []);

  void seed(String workspaceId, BillingParty party) =>
      of(workspaceId).add(party);

  Never _refuse(BillingCustomerRefusalKind kind) =>
      throw BillingCustomerRefusal(kind);

  void _check() {
    final failure = failNext;
    if (failure != null) {
      failNext = null;
      Error.throwWithStackTrace(failure, StackTrace.current);
    }
  }

  @override
  Future<List<BillingParty>> fetch(String workspaceId) async {
    calls.add('fetch');
    _check();
    return List.of(of(workspaceId));
  }

  @override
  Future<String> create(
    String workspaceId,
    BillingPartyDraft draft, {
    String? capacity,
  }) async {
    calls.add('create');
    _check();
    if (!mayManage()) _refuse(BillingCustomerRefusalKind.notAllowed);
    if (validateBillingParty(draft).containsKey('company')) {
      _refuse(BillingCustomerRefusalKind.nameNeeded);
    }
    final id = 'billing-customer-${_next++}';
    of(workspaceId).add(
      BillingParty(
        subjectId: id,
        revision: 1,
        draft: _normalised(draft),
        capacity: capacity,
      ),
    );
    return id;
  }

  @override
  Future<BillingParty> save(
    String workspaceId,
    String subjectId,
    BillingPartyDraft draft, {
    required int expectedRevision,
    String? capacity,
  }) async {
    calls.add('save');
    _check();
    if (!mayManage()) _refuse(BillingCustomerRefusalKind.notAllowed);
    final rows = of(workspaceId);
    final at = rows.indexWhere((p) => p.subjectId == subjectId);
    if (at < 0) _refuse(BillingCustomerRefusalKind.unknownCustomer);
    final current = rows[at];
    if (current.revision != expectedRevision) {
      _refuse(BillingCustomerRefusalKind.stale);
    }
    final saved = BillingParty(
      subjectId: subjectId,
      revision: current.revision + 1,
      draft: _normalised(draft),
      capacity: capacity ?? current.capacity,
    );
    rows[at] = saved;
    return saved;
  }

  static BillingPartyDraft _normalised(BillingPartyDraft d) {
    final wire = d.toWire();
    return BillingPartyDraft(
      courtesy: wire['courtesy']!,
      firstName: wire['first_name']!,
      lastName: wire['last_name']!,
      company: wire['company']!,
      street: wire['street']!,
      postalCode: wire['postal_code']!,
      city: wire['city']!,
      subdivision: wire['subdivision']!,
      countryCode: wire['country_code']!,
      vatId: wire['vat_id']!,
      legalId: wire['legal_id']!,
      email: wire['email']!,
      phone: wire['phone']!,
    );
  }
}
