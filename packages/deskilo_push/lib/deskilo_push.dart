// SPDX-License-Identifier: 0BSD
//
// deskilo_push — the STORE flavour (#716): Firebase Cloud Messaging.
//
// Two packages share this name and this API. The root pubspec points at
// this one; F-Droid's build recipe points at `deskilo_push_foss`, which
// carries no Firebase and reports push unavailable. The app itself
// never imports Firebase — this file is the only door, and it has two
// interchangeable keys.
export 'src/firebase_push_connector.dart' show FirebasePushConnector;
export 'src/push_connector.dart';

import 'src/firebase_push_connector.dart';
import 'src/push_connector.dart';

/// Whether this build carries a push transport at all. True here; the
/// FOSS package answers false, and Settings says so.
const bool kPushTransportAvailable = true;

/// The transport this build ships with.
PushConnector createPushConnector({PushWarn? onWarn}) =>
    FirebasePushConnector(onWarn: onWarn);
