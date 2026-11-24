// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4444 -- the four answers of an HMRC submission, as tests read them now
// that a submission answers CommandOutcome<HmrcFiling>.
import 'package:deskilo/core/failure/app_failure.dart';
import 'package:deskilo/features/money/domain/hmrc_submission.dart';
import 'package:flutter_test/flutter_test.dart';

/// Filed and recorded here.
final Matcher isHmrcFiled = isA<CommandDone<HmrcFiling>>().having(
  (o) => o.value.recorded,
  'recorded',
  isTrue,
);

/// HMRC took it; it could not be recorded here.
final Matcher isHmrcAcceptedNotRecorded = isA<CommandDone<HmrcFiling>>().having(
  (o) => o.value.recorded,
  'recorded',
  isFalse,
);

/// It may have reached HMRC: nothing is filed.
final Matcher isHmrcUnconfirmed = isA<CommandUnreached<HmrcFiling>>();

/// Refused; nothing was filed.
final Matcher isHmrcRefused = isA<CommandRefused<HmrcFiling>>();

/// The filing of a done submission.
HmrcFiling filedOf(Object? outcome) =>
    (outcome! as CommandDone<HmrcFiling>).value;

/// The refusal of a refused submission.
HmrcRefusalCause refusedOf(Object? outcome) =>
    hmrcRefusalOf(outcome! as CommandOutcome<HmrcFiling>)!;

/// The code of an unconfirmed submission.
String unconfirmedCode(Object? outcome) =>
    ((outcome! as CommandUnreached<HmrcFiling>).failure.cause!
            as HmrcUnconfirmed)
        .code;
