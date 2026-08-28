// SPDX-License-Identifier: 0BSD
import '../../l10n/app_localizations.dart';

/// Every surface that carries a contextual help hint (#606). The enum
/// name is the persisted dismissal id — renaming a value revives its
/// hint on devices that had dismissed it.
enum HelpHintId {
  reserve,
  plan,
  calendar,
  events,
  editor,
  availability,
  features,
  members,
  money,
  validation,
  workspaceSettings,
  badges,
  messages,
}

/// One tip of a surface's carousel (#610): its sentence and, when a more
/// specific guide section exists, its own "Learn more" topic. A null
/// [topic] falls back to the surface's topic.
class HelpTip {
  const HelpTip(this.text, {this.topic});

  final String text;
  final String? topic;
}

/// Tip 1 — the surface's basic how-to sentence (#606).
String helpHintText(AppLocalizations? l10n, HelpHintId id) => switch (id) {
  HelpHintId.reserve =>
    l10n?.helpHintReserve ??
        'Pick a day and time window, then tap a free seat to book it.',
  HelpHintId.plan =>
    l10n?.helpHintPlan ??
        'The live floor plan: tap a free seat to book it, tap your '
            'own booking to check in.',
  HelpHintId.calendar =>
    l10n?.helpHintCalendar ??
        'Browse bookings by month; tap a day to see and manage its '
            'reservations.',
  HelpHintId.events =>
    l10n?.helpHintEvents ??
        'Everything that happened, in one feed. Decisions waiting '
            'for you sit on top; the chips filter the rest.',
  HelpHintId.editor =>
    l10n?.helpHintEditor ??
        'Draw rooms and desks, stamp seats onto them — tap a seat '
            'twice to edit its properties.',
  HelpHintId.availability =>
    l10n?.helpHintAvailability ??
        'Set the open weekdays and working hours, and add closure '
            'days nobody can book.',
  HelpHintId.features =>
    l10n?.helpHintFeatures ??
        'Switch workspace functionality on or off — every member\'s '
            'app follows immediately.',
  HelpHintId.members =>
    l10n?.helpHintMembers ??
        'Invite members, set their plan percentage and role, and '
            'manage their badges.',
  HelpHintId.money =>
    l10n?.helpHintMoney ??
        'Your monthly bill: browse months with the arrows; pay, '
            'export or share from here.',
  HelpHintId.validation =>
    l10n?.helpHintValidation ??
        'Decide which actions need confirmation, who confirms, and '
            'how many approvals it takes.',
  HelpHintId.workspaceSettings =>
    l10n?.helpHintWorkspace ??
        'Country, currency, language and billing details — '
            'documents and taxes follow these settings.',
  HelpHintId.messages =>
    l10n?.helpHintMessages ??
        'Every conversation in one list, newest first. Tap the pencil to '
            'write to someone or start a group.',
  HelpHintId.badges =>
    l10n?.helpHintBadges ??
        'Issue a printable QR badge or register an NFC card; revoke '
            'lost badges any time.',
};

/// A distinctive fragment of the matching guide heading, localized —
/// the help guides are per-language, so the jump text must be too.
/// This is the surface's DEFAULT topic; a tip may carry its own.
String helpHintTopic(AppLocalizations? l10n, HelpHintId id) => switch (id) {
  HelpHintId.reserve => l10n?.helpHintReserveTopic ?? 'Reserve hub',
  HelpHintId.plan => l10n?.helpHintPlanTopic ?? 'floor plan',
  HelpHintId.calendar => l10n?.helpHintCalendarTopic ?? 'Calendar',
  HelpHintId.events => l10n?.helpHintEventsTopic ?? 'confirmations',
  HelpHintId.editor => l10n?.helpHintEditorTopic ?? 'space editor',
  HelpHintId.availability => l10n?.helpHintAvailabilityTopic ?? 'Availability',
  HelpHintId.features => l10n?.helpHintFeaturesTopic ?? 'Features',
  HelpHintId.members => l10n?.helpHintMembersTopic ?? 'Members & plans',
  HelpHintId.money => l10n?.helpHintMoneyTopic ?? 'Money',
  HelpHintId.validation => l10n?.helpHintValidationTopic ?? 'confirmations',
  HelpHintId.workspaceSettings =>
    l10n?.helpHintWorkspaceTopic ?? 'Workspace settings',
  HelpHintId.badges => l10n?.helpHintBadgesTopic ?? 'NFC badges',
  HelpHintId.messages => l10n?.helpHintMessagesTopic ?? 'Messages',
};

/// The surface's carousel (#610): tip 1 is the #606 how-to, the rest
/// climb from there into the screen's deeper tricks. Every text and
/// topic is mined from the bundled help guides — a lint-style test
/// checks that every topic matches a real heading in all five.
List<HelpTip> helpHintTips(AppLocalizations? l10n, HelpHintId id) =>
    switch (id) {
      HelpHintId.reserve => [
        HelpTip(helpHintText(l10n, id)),
        HelpTip(
          l10n?.helpHintReserveTip2 ??
              'The Week and Month views find a free half-day at a '
                  'glance — tap a free cell or day to book right there.',
        ),
        HelpTip(
          l10n?.helpHintReserveTip3 ??
              'Tap the scan button and point the camera at a '
                  'space\'s QR card — the sheet shows exactly what '
                  'you may do there.',
          topic: l10n?.helpHintReserveTip3Topic ?? 'Scan a space code',
        ),
        HelpTip(
          l10n?.helpHintReserveTip4 ??
              'The morning, afternoon and full-day chips pick your '
                  'window before you choose a seat — a booked '
                  'morning counts as half a day.',
          topic: l10n?.helpHintReserveTip4Topic ?? 'How booking behaves',
        ),
        HelpTip(
          l10n?.helpHintReserveTip5 ??
              'Set your default booking period in Settings — the '
                  'hub preselects it on every visit.',
          topic: l10n?.helpHintReserveTip5Topic ?? 'Settings & profile',
        ),
      ],
      HelpHintId.plan => [
        HelpTip(helpHintText(l10n, id)),
        HelpTip(
          l10n?.helpHintPlanTip2 ??
              'Standing at a free seat? Tap it — the sheet suggests '
                  'now until closing, and confirming checks you in on '
                  'the spot.',
        ),
        HelpTip(
          l10n?.helpHintPlanTip3 ??
              'Browse another moment with the date chip and the time '
                  'scroller — the plan shows who sits where at any '
                  'future time.',
        ),
        HelpTip(
          l10n?.helpHintPlanTip4 ??
              'Double-tap a desk, a room or the floor itself — or tap '
                  'the layers icon on the level rail — to reserve the '
                  'whole space at once.',
        ),
        HelpTip(
          l10n?.helpHintPlanTip5 ??
              'Tap your own seat for its sheet: check in from 15 '
                  'minutes before your start, check out when you '
                  'leave.',
          topic: l10n?.helpHintPlanTip5Topic ?? 'How booking behaves',
        ),
      ],
      HelpHintId.calendar => [
        HelpTip(helpHintText(l10n, id)),
        HelpTip(
          l10n?.helpHintCalendarTip2 ??
              'The Mine / Everyone toggle shows just your bookings or '
                  'the whole community\'s — red dots are yours, blue '
                  'ones are other members\'.',
        ),
        HelpTip(
          l10n?.helpHintCalendarTip3 ??
              'The shape toggle switches the lower half between the '
                  'week grid and the agenda list; the floor chips '
                  'filter both.',
        ),
        HelpTip(
          l10n?.helpHintCalendarTip4 ??
              'Cancelling one occurrence of a series offers "this '
                  'and following" — checked-in and completed '
                  'occurrences keep their history.',
          topic: l10n?.helpHintCalendarTip4Topic ?? 'How booking behaves',
        ),
      ],
      HelpHintId.events => [
        HelpTip(helpHintText(l10n, id)),
        HelpTip(
          l10n?.helpHintEventsTip2 ??
              'The filter chips remember your choice across visits — '
                  'and the Unread chip narrows the list to unread '
                  'messages.',
        ),
        HelpTip(
          l10n?.helpHintEventsTip3 ??
              'Group the feed by type, day or member from the Group '
                  'by menu; tap the group symbol to return to the '
                  'flat list.',
        ),
        HelpTip(
          l10n?.helpHintEventsTip4 ??
              'Pending decisions sit pinned on top with Accept and '
                  'reject — and nobody ever validates their own '
                  'event.',
        ),
      ],
      HelpHintId.editor => [
        HelpTip(helpHintText(l10n, id)),
        HelpTip(
          l10n?.helpHintEditorTip2 ??
              'Pick Office or Table in the toolbar and drag on the '
                  'grid to draw it; Select moves and resizes what is '
                  'already there.',
        ),
        HelpTip(
          l10n?.helpHintEditorTip3 ??
              'The Seat tool stamps seats onto desks; a seat\'s sheet '
                  'sets its direction, chair type, accessories and a '
                  'maintenance block.',
        ),
        HelpTip(
          l10n?.helpHintEditorTip4 ??
              'Give a seat its NFC/RFID tag from the seat sheet — tap '
                  'the chip on the phone and the field fills itself.',
        ),
        HelpTip(
          l10n?.helpHintEditorTip5 ??
              'Print a QR card for every seat, desk, office and '
                  'level — pick the card size and what each card '
                  'shows before exporting.',
          topic: l10n?.helpHintEditorTip5Topic ?? 'Space QR codes',
        ),
      ],
      HelpHintId.availability => [
        HelpTip(helpHintText(l10n, id)),
        HelpTip(
          l10n?.helpHintAvailabilityTip2 ??
              'The booking granularity decides what a window may look '
                  'like: half-days, full days, minute grids or free '
                  'times.',
        ),
        HelpTip(
          l10n?.helpHintAvailabilityTip3 ??
              'Day start, half-day boundary and day end drive every '
                  'half-day and full-day slot — booking, check-in and '
                  'billing follow them.',
        ),
        HelpTip(
          l10n?.helpHintAvailabilityTip4 ??
              'Three booking policies tighten or relax the rules: '
                  'past bookings, minute bookings kept within working '
                  'hours, and admin check-out.',
        ),
      ],
      HelpHintId.features => [
        HelpTip(helpHintText(l10n, id)),
        HelpTip(
          l10n?.helpHintFeaturesTip2 ??
              'The list is hierarchical — a feature that needs '
                  'another sits indented under it and greys out while '
                  'its parent is off.',
        ),
        HelpTip(
          l10n?.helpHintFeaturesTip3 ??
              'Switching a parent off takes its whole subtree out of '
                  'the app; the children\'s stored choices return '
                  'untouched with the parent.',
        ),
        HelpTip(
          l10n?.helpHintFeaturesTip4 ??
              'A feature\'s settings entry only appears while the '
                  'feature is on — the Features screen itself always '
                  'stays reachable.',
        ),
      ],
      HelpHintId.members => [
        HelpTip(helpHintText(l10n, id)),
        HelpTip(
          l10n?.helpHintMembersTip2 ??
              'Tap a member for their management sheet — '
                  'subscription, reservation limit, badges, services '
                  'and more in one place.',
        ),
        HelpTip(
          l10n?.helpHintMembersTip3 ??
              'Badges live per member: mint a printable QR badge, '
                  'or register their NFC card by holding it to the '
                  'device.',
          topic: l10n?.helpHintMembersTip3Topic ?? 'NFC badges',
        ),
        HelpTip(
          l10n?.helpHintMembersTip4 ??
              'Name admin grants admin rights after validation; the '
                  'role matrix under Role management decides what '
                  'every role may do.',
          topic: l10n?.helpHintMembersTip4Topic ?? 'Role management',
        ),
      ],
      HelpHintId.money => [
        HelpTip(helpHintText(l10n, id)),
        HelpTip(
          l10n?.helpHintMoneyTip2 ??
              'Every document offers the same three actions: quick '
                  'view on screen, download as PDF, and share to '
                  'any app.',
          topic: l10n?.helpHintMoneyTip2Topic ?? 'Quick view, save, share',
        ),
        HelpTip(
          l10n?.helpHintMoneyTip3 ??
              'Record a payment with the date the money moved and the '
                  'month it settles — the other side confirms it.',
        ),
        HelpTip(
          l10n?.helpHintMoneyTip4 ??
              'Once the month is invoiced, the invoice decides: the '
                  'month reads settled as soon as its invoice is '
                  'paid.',
          topic: l10n?.helpHintMoneyTip4Topic ?? 'the invoice decides',
        ),
      ],
      HelpHintId.validation => [
        HelpTip(helpHintText(l10n, id)),
        HelpTip(
          l10n?.helpHintValidationTip2 ??
              'One card per event type, each inheriting from the '
                  'default rule until you edit it — payments, '
                  'expenses, role changes and more.',
        ),
        HelpTip(
          l10n?.helpHintValidationTip3 ??
              'Nobody ever validates their own event, and unanswered '
                  'requests expire after 7 days — nothing is granted '
                  'silently.',
        ),
      ],
      HelpHintId.workspaceSettings => [
        HelpTip(helpHintText(l10n, id)),
        HelpTip(
          l10n?.helpHintWorkspaceTip2 ??
              'Print the space QR cards from Exports — choose the '
                  'card size and the info each card carries, ten '
                  'per A4 page.',
          topic: l10n?.helpHintWorkspaceTip2Topic ?? 'Space QR codes',
        ),
        HelpTip(
          l10n?.helpHintWorkspaceTip3 ??
              'Export the space as XML to back it up or template a '
                  'new one; the setup questionnaire prefills a fresh '
                  'workspace end to end.',
        ),
        HelpTip(
          l10n?.helpHintWorkspaceTip4 ??
              'Reset the workspace wipes reservations, accounting and '
                  'the floor plan — settings and members survive, and '
                  'a typed confirmation guards it.',
        ),
      ],
      HelpHintId.messages => [
        HelpTip(helpHintText(l10n, id)),
        HelpTip(
          l10n?.helpHintMessagesTip2 ??
              'Pick one person for a private chat, or several to make a '
                  'group — the name field appears once there are two, '
                  'and a group name is unique here, so nobody has to '
                  'guess which "Team" they mean.',
        ),
        HelpTip(
          l10n?.helpHintMessagesTip3 ??
              'Tap a name at the top of a chat to see their profile: '
                  'today\'s booking, whether they are checked in, and '
                  'how to reach them.',
        ),
        HelpTip(
          l10n?.helpHintMessagesTip4 ??
              'Search finds people, groups and the words inside '
                  'messages — a result takes you straight there.',
        ),
        HelpTip(
          l10n?.helpHintMessagesTip5 ??
              'Link a reservation or a space in a message instead of '
                  'describing it; the reader taps it and lands on the '
                  'right one.',
        ),
      ],
      HelpHintId.badges => [
        HelpTip(helpHintText(l10n, id)),
        HelpTip(
          l10n?.helpHintBadgesTip2 ??
              'Register a card by holding it to the device — any '
                  'readable chip works, and the dialog names the '
                  'workspace it joins.',
        ),
        HelpTip(
          l10n?.helpHintBadgesTip3 ??
              'Save a QR badge as PDF to print ten credit-card copies '
                  'on one A4 page — spares included.',
        ),
        HelpTip(
          l10n?.helpHintBadgesTip4 ??
              'Revoke a lost badge any time; swipe a revoked badge to '
                  'the right to delete it for good.',
        ),
      ],
    };

/// Where a fresh visit opens: the tip AFTER the last shown one,
/// rotating past the end back to 0. [lastShown] may be null (never
/// visited), stale-high (the tip list shrank) or garbage-negative —
/// the double modulo tolerates all of it.
int helpHintInitialTipIndex(int? lastShown, int tipCount) {
  if (tipCount <= 0) return 0;
  return (((lastShown ?? -1) + 1) % tipCount + tipCount) % tipCount;
}
