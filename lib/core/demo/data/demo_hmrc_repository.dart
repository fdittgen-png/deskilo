// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2470 — the Demo's HMRC: the same port the live app uses, answered from the
// London space's own in-memory money store. Nothing leaves the process: no
// request, no token, no secret. The sign-in is synthetic, the receipt says it
// is simulated, and a return is filed only after the same checks the server
// makes (the right, the connection, the prepared return unchanged, the nine
// boxes equal to the ones the prepared lines give, an open obligation) and
// after a receipt; a scripted unconfirmed or refused answer files nothing.
import '../../../features/money/domain/hmrc_submission.dart';
import '../../../features/money/domain/mtd_boxes.dart';
import '../../../features/money/domain/vat_declaration.dart';
import '../../../features/workspace/domain/member.dart';
import 'money_repository.dart';
import 'workspace_repository.dart';

/// A scripted answer for the n-th attempt (tests only; there is no control in
/// the product): null lets the attempt run for real.
typedef DemoHmrcScript = HmrcOutcome? Function(int attempt);

class DemoHmrcRepository implements HmrcRepository {
  DemoHmrcRepository({
    required this._money,
    required this._workspaces,
    required this._today,
    this.script,
  });

  final FakeMoneyRepository _money;
  final FakeWorkspaceRepository _workspaces;
  final DateTime _today;
  final DemoHmrcScript? script;

  HmrcConnection? _connection;
  bool _inFlight = false;
  int _attempts = 0;

  /// Owner or active co-owner: who may connect and file, as on the server.
  bool get _mayFile {
    final me = _workspaces.myMember;
    return me.isOwner || me.coOwner == CoOwnerStatus.active;
  }

  @override
  Future<HmrcState> state(String workspaceId) async {
    final digits = _workspaces.workspaces
        .where((w) => w.id == workspaceId)
        .map((w) => w.vatId.toUpperCase().replaceAll(RegExp(r'^(GB|XI)'), '').replaceAll(RegExp(r'\D'), ''))
        .firstOrNull;
    return HmrcState(
      vrn: digits != null && digits.length == 9 ? digits : null,
      connection: _connection,
      demo: true,
    );
  }

  @override
  Future<Uri> startConnect(String workspaceId, String issuerSiteId) async {
    if (!_mayFile) throw StateError('only the owner connects HMRC');
    _connection = HmrcConnection(
      id: 'demo-hmrc-connection',
      issuerSiteId: issuerSiteId,
      link: HmrcLink.connected,
    );
    // The Demo's sign-in is synthetic: the caller opens nothing.
    return Uri.parse('https://www.tax.service.gov.uk/oauth/authorize?demo=1');
  }

  @override
  Future<HmrcOutcome> submit({
    required String declarationId,
    required String connectionId,
    required Map<String, num> boxes,
    required HmrcClientValues client,
  }) async {
    // One submission of a return at a time: a second tap is in_flight.
    if (_inFlight) return const HmrcRefused(HmrcRefusal.inFlight);
    _inFlight = true;
    try {
      // The claim and the call are not one step: let a second tap in.
      await Future<void>.delayed(Duration.zero);
      return _run(declarationId, connectionId, boxes);
    } finally {
      _inFlight = false;
    }
  }

  HmrcOutcome _run(String declarationId, String connectionId, Map<String, num> sent) {
    final connection = _connection;
    if (!_mayFile) return const HmrcRefused(HmrcRefusal.notAllowed);
    if (connection == null || !connection.isConnected || connection.id != connectionId) {
      return const HmrcRefused(HmrcRefusal.notConnected);
    }
    final declaration = _money.vatDeclarations.where((d) => d.id == declarationId).firstOrNull;
    if (declaration == null || !declaration.isPrepared) {
      return const HmrcRefused(HmrcRefusal.figuresDiffer);
    }
    // The prepared return must still be what the invoices give today.
    final now = _money.taxReporting.preparedLinesNow(declaration.periodStart, declaration.periodEnd);
    if (_totals(now) != _totals(declaration.lines)) {
      return const HmrcRefused(HmrcRefusal.figuresDiffer);
    }
    if (declaration.lines.any((l) => l.isAcquisition)) {
      return const HmrcRefused(HmrcRefusal.acquisitionNotSupported);
    }
    final server = mtdBoxCents(declaration);
    for (final field in mtdBoxFields) {
      final s = sent[field];
      if (s == null || (s * 100).round() != server[field]) {
        return const HmrcRefused(HmrcRefusal.figuresDiffer);
      }
    }
    // An obligation is open once its period has ended.
    if (!declaration.periodEnd.isBefore(_today)) {
      return const HmrcRefused(HmrcRefusal.refused, code: 'TAX_PERIOD_NOT_ENDED');
    }
    _attempts++;
    final scripted = script?.call(_attempts);
    if (scripted != null) return scripted;
    final receipt = HmrcReceipt(
      formBundleNumber: 'DEMO-${declaration.periodEnd.year}${declaration.periodEnd.month.toString().padLeft(2, '0')}-${_attempts.toString().padLeft(3, '0')}',
      processingDate: _today.toUtc().toIso8601String(),
    );
    _money.taxReporting.fileAsHmrcDemo(declaration.id, receipt.formBundleNumber);
    return HmrcFiled(receipt, demo: true);
  }

  static (int, int, int) _totals(List<VatDeclarationLine> lines) => (
    lines.fold<int>(0, (n, l) => n + l.netCents),
    lines.fold<int>(0, (n, l) => n + l.vatCents),
    lines.length,
  );
}
