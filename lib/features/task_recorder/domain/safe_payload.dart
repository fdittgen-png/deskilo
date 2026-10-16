// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1865 - the host's payload vocabulary. The mechanism (minimization
// before persistence, strict parsing) lives in the deskilo_task_recording
// package; the fields and values below are Deskilo's own.

import 'package:deskilo_task_recording/safe_payload.dart';

import 'ui_vocabulary.g.dart';

export 'package:deskilo_task_recording/safe_payload.dart';

/// The whole field list. Adding a field is a reviewed change to this
/// file; there is no other way for a value to reach a recording.
const Map<String, SafeField> safeFields = {
  'date_relation': SafeField('date_relation', {
    'today',
    'tomorrow',
    'later_this_week',
    'later',
    'past',
  }),
  'period': SafeField('period', {
    'full_day',
    'morning',
    'afternoon',
    'hours',
    'custom',
  }),
  'view_mode': SafeField('view_mode', {
    'plan',
    'list',
    'day',
    'week',
    'month',
    'agenda',
    'timeline',
    'range',
  }),
  'resource_kind': SafeField('resource_kind', {'desk', 'room', 'other'}),
  'for_whom': SafeField('for_whom', {'self', 'other_member'}),
  'repeat': SafeField('repeat', {'once', 'series'}),
  'check_in': SafeField('check_in', {'yes', 'no'}),
  'switch_to': SafeField('switch_to', {'on', 'off'}),
  'series_result': SafeField('series_result', {
    'all_booked',
    'partially_booked',
  }),
  // #2142 — a control's or a screen's label: one of the app's own
  // messages (by key), never text somebody typed.
  'label': SafeField('label', uiLabelKeys, soft: true),
  'me_tab': SafeField('me_tab', {'home', 'discover', 'messages', 'me'}),
  // #1881 B — the calendar: which way the dates moved, whose calendar,
  // which kind of entry was opened; and a decision's answer.
  'direction': SafeField('direction', {'previous', 'next', 'today'}),
  'calendar_of': SafeField('calendar_of', {'mine', 'someone_else', 'everyone'}),
  'item_kind': SafeField('item_kind', {
    'conversation',
    'alert',
    'decision',
    'payment',
    'invoice',
  }),
  'decision': SafeField('decision', {'accept', 'decline'}),
  // #1884 B — the built-in role a permission was switched for, and what
  // happened to a role the space defines.
  'role_kind': SafeField('role_kind', {'owner', 'co_owner', 'admin', 'member'}),
  'role_change': SafeField('role_change', {'created', 'edited', 'renamed'}),
  'refusal': SafeField('refusal', {
    'conflict',
    'policy',
    'quota',
    'permission',
    'closed',
    'offline',
    'other',
  }),
};

/// Minimizes [raw] against this build's vocabulary before it is stored.
SafePayload minimizeForRecorder(
  Set<String> declared,
  Map<String, Object?> raw,
) => SafePayload.minimize(declared, raw, fields: safeFields);
