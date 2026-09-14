# ADR 0004 — MIT license

**Status:** superseded by [ADR 0009](0009-relicense-0bsd.md) · **Date:** 2026-07-07

> **Superseded by [ADR 0009](0009-relicense-0bsd.md)** — the project
> relicensed to 0BSD on 2026-08-04. This record is kept because the
> reasoning behind choosing a permissive licence at all still stands;
> only the licence changed.

## Context

The sibling project Sparkilo is MIT-licensed; the maintainer wants maximum reuse with minimal friction, and F-Droid requires a free license.

## Decision

MIT, © 2026 Florian DITTGEN. SPDX headers (`// SPDX-License-Identifier: MIT`) in every source file. No GPL dependencies (MIT-compatibility rule), matching Sparkilo.

## Consequences

Anyone may fork, including commercially. Copyleft-only libraries are excluded from the dependency set.
