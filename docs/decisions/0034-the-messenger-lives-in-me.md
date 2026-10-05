# ADR 0034 — The messenger lives in Me

**Status:** accepted · **Date:** 2026-10-05

## Context
Conversations were reachable twice: a Discussions tab in every workspace and the
unified inbox in Me. A person's conversations do not belong to a workspace, and
visibility of a person to others is a property of the account, not of a space.

## Decision
Discussions live only in the Me messenger, labelled by context. The workspace
Messages destination is renamed Alerts, keeps the workspace's alerts and the
requests addressed to the space, and carries one door to the messenger.
Visibility of a person is one field × audience matrix with a separate
reachability rule (docs/design/MESSENGER_VISIBILITY.md).

## Consequences
- One inbox, one read state, one place to manage who can write to me.
- Pin / mute / archive / search of the legacy workspace list must be ported to
  the Me inbox before that list is removed; until then the list stays as code
  without a route.
- Public, request and block tiers are server work tracked separately.
