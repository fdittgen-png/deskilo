// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2388 — the recorder's pages that another screen opens, as routes with
// paths (they were `Navigator.push`es the router did not know). A link
// without the guide or the recording lands on the recorder.
import '../../../core/navigation/page_spec.dart';
import 'route_classification.dart' show taskRecorderRoute;
import 'screens/guide_draft_screen.dart';
import 'screens/recording_review_screen.dart';
import 'screens/task_workbench_screen.dart' show workbenchPages;

T _same<T>(T page) => page;

/// A guide being drafted.
const guideDraftPage = PageSpec<GuideDraftScreen>(
  '$taskRecorderRoute/guide',
  _same,
  fallback: taskRecorderRoute,
);

/// A stored recording, to review.
const recordingReviewPage = PageSpec<RecordingReviewScreen>(
  '$taskRecorderRoute/recording',
  _same,
  fallback: taskRecorderRoute,
);

/// Every page above, for the router.
final recorderPages = <PageSpec<Object?>>[
  guideDraftPage,
  recordingReviewPage,
  ...workbenchPages,
];
