# ADR 0005 — Square-grid floor-plan model with the seat as bookable unit

**Status:** accepted · **Date:** 2026-07-07

## Context

The brief mixes "check in to the desk", "to a chair", and "to an office". Competing tools either upload bitmap floor plans (Seatsurfing) or use abstract lists. DesKilo's owner draws the space in-app.

## Decision

The workspace is modeled as Workspace → Levels → Offices → Desks → **Seats**, drawn on an abstract grid of small squares by the owner. The **seat** is the bookable unit: a fixed **6-squares-wide × 4-squares-deep** footprint on a desk edge with an orientation. The chair is an attribute set of the seat (type + amenities). An office may be flagged *bookable as a whole*. Floor-plan edits are versioned so historical reservations render against the plan that existed at their time.

## Consequences

Vector/grid data (not bitmaps) makes seat states, tap targets, the time scroller, and the editor tractable. The fixed 6×4 footprint is normative per the product brief; the grid square carries no real-world scale.
