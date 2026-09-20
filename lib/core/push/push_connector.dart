// SPDX-License-Identifier: AGPL-3.0-or-later
//
// The transport seam lives in the `deskilo_push` package since #716, so
// the F-Droid build can swap the whole transport by swapping one path
// in pubspec.yaml. Re-exported here so nothing above this file moved.
export 'package:deskilo_push/deskilo_push.dart'
    show PushConnector, PushWarn, kPushTransportAvailable;
