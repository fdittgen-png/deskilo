# ADR 0009 — Relicense to 0BSD

**Status:** accepted · **Date:** 2026-07-20 · **Supersedes:** [ADR 0004](0004-mit-license.md)

## Context

The project shipped under MIT (ADR 0004). MIT is permissive but still
imposes one obligation on downstream users: reproduce the copyright and
license notice in all copies. The maintainer (sole copyright holder)
wants the *minimum possible* obligations — on themselves and on anyone
reusing the code, tools, APIs or frameworks it builds on — while keeping
the project acceptable for F-Droid.

## Decision

Relicense to **0BSD** (BSD Zero Clause License, SPDX `0BSD`), © 2026
Florian DITTGEN. Every source file's SPDX header becomes
`// SPDX-License-Identifier: 0BSD`.

0BSD is MIT minus the attribution clause: "Permission to use, copy,
modify, and/or distribute this software for any purpose with or without
fee is hereby granted." No notice must be retained, in source or binary.

Why 0BSD over the alternatives:
- **vs MIT/Apache-2.0** — both add obligations (notice retention;
  Apache also a NOTICE file and change statements). 0BSD adds none.
- **vs The Unlicense / CC0** — those are public-domain dedications;
  0BSD is a plain OSI-approved *and* FSF-libre license with cleaner
  standing across jurisdictions and no public-domain edge cases. (If a
  true public-domain dedication is ever preferred, Unlicense is the
  drop-in.)
- **F-Droid** — 0BSD is on F-Droid's allowed-licenses list, so inclusion
  is unaffected. The "no GPL/copyleft dependencies" rule from ADR 0004
  still holds — it keeps the whole app permissively licensable.

The app's license never constrained which tools/APIs/frameworks may be
used; that is governed by each dependency's own license. The F-Droid
build stays free because every dependency is free (audited by script).

## Consequences

- Downstream users have zero obligations — no attribution needed to fork,
  embed, or ship commercially.
- The `LICENSE` file, all 350+ SPDX headers, `CONTRIBUTING.md`, the store
  metadata (`metadata/*.yml` `License:` field, store descriptions) and the
  wiki now state 0BSD.
- Contributors' additions are 0BSD; the CONTRIBUTING note reflects this.
