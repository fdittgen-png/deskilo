// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2470 — submitting a prepared UK VAT return to HMRC (Making Tax Digital).
//
// The nine boxes come from `mtd_boxes.dart` (the same the bridging CSV
// writes); the server recomputes them from the prepared return and refuses
// any difference. Only a receipt from HMRC files the return, on the server;
// a timeout or an empty answer is UNCONFIRMED: nothing is filed, no receipt is
// invented, and nothing is retried automatically.

/// The state of the workspace's HMRC sign-in.
enum HmrcLink { pending, connected, expired, error }

/// The workspace's live HMRC connection.
class HmrcConnection {
  const HmrcConnection({
    required this.id,
    required this.issuerSiteId,
    required this.link,
    this.statusDetail = '',
  });

  final String id;
  final String issuerSiteId;
  final HmrcLink link;
  final String statusDetail;

  bool get isConnected => link == HmrcLink.connected;

  factory HmrcConnection.fromJson(Map<String, Object?> json) => HmrcConnection(
    id: '${json['id']}',
    issuerSiteId: '${json['issuer_site_id']}',
    link: switch (json['status']) {
      'connected' => HmrcLink.connected,
      'expired' => HmrcLink.expired,
      'error' => HmrcLink.error,
      _ => HmrcLink.pending,
    },
    statusDetail: '${json['status_detail'] ?? ''}',
  );
}

/// What the VAT returns screen needs before it offers the submission.
class HmrcState {
  const HmrcState({this.vrn, this.connection});

  /// The nine digits of the space's UK VAT number; null when it has none.
  final String? vrn;
  final HmrcConnection? connection;

  factory HmrcState.fromJson(Object? json) {
    if (json is! Map) return const HmrcState();
    final connection = json['connection'];
    return HmrcState(
      vrn: json['vrn'] is String ? json['vrn'] as String : null,
      connection: connection is Map
          ? HmrcConnection.fromJson(Map<String, Object?>.from(connection))
          : null,
    );
  }
}

/// HMRC's receipt for an accepted return.
class HmrcReceipt {
  const HmrcReceipt({
    required this.formBundleNumber,
    this.processingDate = '',
    this.chargeRefNumber,
  });

  final String formBundleNumber;
  final String processingDate;
  final String? chargeRefNumber;

  factory HmrcReceipt.fromJson(Object? json) {
    final Map<Object?, Object?> m = json is Map ? json : const {};
    return HmrcReceipt(
      formBundleNumber: '${m['formBundleNumber'] ?? ''}',
      processingDate: '${m['processingDate'] ?? ''}',
      chargeRefNumber: m['chargeRefNumber'] is String
          ? m['chargeRefNumber'] as String
          : null,
    );
  }
}

/// Why a submission did not go through; the person is told which.
enum HmrcRefusal {
  notAllowed,
  notConfigured,
  notConnected,
  wrongRegistration,
  signInAgain,
  figuresDiffer,
  acquisitionNotSupported,
  noOpenObligation,
  alreadySubmitted,
  notAuthorised,
  refused,
  busy,
  inFlight,
  acceptedForOtherFigures,
  fraudHeadersMissing,
  unreachable,
  other,
}

/// The outcome of one submission.
sealed class HmrcOutcome {
  const HmrcOutcome();
}

/// HMRC accepted the return and it is filed, with HMRC's receipt. A [demo]
/// receipt is simulated: no HMRC call was made.
class HmrcFiled extends HmrcOutcome {
  const HmrcFiled(this.receipt, {this.demo = false});

  final HmrcReceipt receipt;
  final bool demo;
}

/// HMRC took the return but it could not be recorded here: the receipt is
/// kept on the server and a new attempt files it without posting again.
class HmrcAcceptedNotRecorded extends HmrcOutcome {
  const HmrcAcceptedNotRecorded(this.receipt);

  final HmrcReceipt receipt;
}

/// Refused; nothing was filed.
class HmrcRefused extends HmrcOutcome {
  const HmrcRefused(this.refusal, {this.code = '', this.missing = const []});

  final HmrcRefusal refusal;

  /// HMRC's or the server's own code, never a token.
  final String code;

  /// The fraud-prevention values the browser did not supply.
  final List<String> missing;
}

/// The return may have reached HMRC (timeout, empty answer): nothing is
/// filed here, and the person checks at HMRC before trying again.
class HmrcUnconfirmed extends HmrcOutcome {
  const HmrcUnconfirmed({this.code = ''});

  final String code;
}

/// What only the person's browser knows (HMRC's fraud-prevention headers of
/// connection method WEB_APP_VIA_SERVER). The server adds its own side and
/// never guesses a value.
class HmrcClientValues {
  const HmrcClientValues({
    required this.browserJsUserAgent,
    required this.deviceId,
    required this.timezone,
    required this.screens,
    required this.windowSize,
    required this.doNotTrack,
  });

  final String browserJsUserAgent;
  final String deviceId;

  /// `UTC+01:00`.
  final String timezone;

  /// `width=1920&height=1080&scaling-factor=1&colour-depth=24`.
  final String screens;

  /// `width=1256&height=803`.
  final String windowSize;
  final bool doNotTrack;

  Map<String, Object?> toJson() => {
    'browser_js_user_agent': browserJsUserAgent,
    'device_id': deviceId,
    'timezone': timezone,
    'screens': screens,
    'window_size': windowSize,
    'do_not_track': doNotTrack,
  };
}

/// The HMRC submission port.
abstract interface class HmrcRepository {
  /// The space's UK VAT number and its live HMRC connection.
  Future<HmrcState> state(String workspaceId);

  /// The HMRC sign-in page for [issuerSiteId]; the person comes back to the
  /// app when HMRC redirects.
  Future<Uri> startConnect(String workspaceId, String issuerSiteId);

  /// Submits the prepared return [declarationId]. [boxes] are the nine boxes
  /// the screen shows (pounds); the server compares them with its own.
  Future<HmrcOutcome> submit({
    required String declarationId,
    required String connectionId,
    required Map<String, num> boxes,
    required HmrcClientValues client,
  });
}
