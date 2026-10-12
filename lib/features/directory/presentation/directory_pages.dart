// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2388 — the directory's and the messenger's pages that another screen
// opens, as routes with paths (they were `Navigator.push`es the router
// did not know). The argument is the configured page itself: each is
// opened with what its opener holds, and a link without it lands on the
// list it is opened from.
import '../../../core/navigation/page_spec.dart';
import 'account_thread.dart';
import 'messenger/context_thread_screen.dart';
import 'messenger/create_group_screen.dart';
import 'messenger/space_inquiries_screen.dart';
import 'messenger/starred_messages_screen.dart';
import 'public_workspace_view.dart';

T _same<T>(T page) => page;

/// A workspace's public page, from the discovery list or the editor's
/// preview.
const publicWorkspacePage = PageSpec<PublicWorkspaceView>(
  '/discover/workspace',
  _same,
  fallback: '/discover',
);

/// A conversation with one person, from the account messenger.
const accountThreadPage = PageSpec<AccountThread>(
  '/account-messages/thread',
  _same,
  fallback: '/account-messages',
);

/// A conversation about something (a booking, an inquiry, a group).
const contextThreadPage = PageSpec<ContextThreadScreen>(
  '/me/messages/thread',
  _same,
  fallback: '/me',
);

/// A space's inquiries, for the people who answer them.
const spaceInquiriesPage = PageSpec<SpaceInquiriesScreen>(
  '/me/messages/inquiries',
  _same,
  fallback: '/me',
);

/// My starred messages.
final starredMessagesPage = PageSpec<Null>(
  '/me/messages/starred',
  (_) => const StarredMessagesScreen(),
  fallback: '/me',
);

/// A new group conversation.
final createGroupPage = PageSpec<Null>(
  '/me/messages/new-group',
  (_) => const CreateGroupScreen(),
  fallback: '/me',
);

/// Every page above, for the router.
final directoryPages = <PageSpec<Object?>>[
  publicWorkspacePage,
  accountThreadPage,
  contextThreadPage,
  spaceInquiriesPage,
  starredMessagesPage,
  createGroupPage,
];
