# ADR 0052 — An organisation is the businesses of one customer; a business stays one issuer

**Status:** accepted · **Date:** 2026-11-15 · **Refs:** #3965, #3958, ADR 0014, ADR 0019, ADR 0026, ADR 0035, ADR 0043, ADR 0050

## Context
A customer has its main business in one country and sites in others. Those
may be outside the EU and use other currencies. The answer has to hold
legally, financially and organisationally, and be the smallest that does.

Measured on master (the map is on #3965): a business (`workspaces`) has one
country, one currency and one clock, and 121 server definitions read one of
the three. A ledger entry carries no currency; a member's balance is one sum;
a plan's included half-days and the month they are counted in belong to the
business; the country's rules (tax filing, invoice mentions, payment slip,
e-invoice profile, paper, document language) are chosen by the business's
country (ADR 0043, ADR 0050). A site (`sites`) has an address, a country and
registrations, but no currency, clock or language.

Nothing groups the businesses of one customer. `network_id` is a business's
own birth record, never shared. `pair_id` joins a business to its development
twin, is set by the server only, and mirrors members and roles between the
two. Configuration already travels between unrelated businesses through the
template engine in merge mode (ADR 0026). A person's identity lives on the
profile and is shared by all their memberships (ADR 0014). Every permission
is per business.

Two ways were weighed. Giving a site its own currency, clock and rules inside
one business reopens invoicing, statements and quotas and needs rules nobody
has asked for (what a subscription bought at one site is worth at another).
Grouping businesses leaves every money rule where it is.

## Decision
1. **A business stays one issuer.** One country's rules, one currency, one
   clock; its own numbering, tax returns, books, bank and payment accounts.
   No currency, clock or country rule is ever added below the business.
2. **An organisation is the businesses of one customer, with one head.** A
   row of its own (`organisations`: a name and the head business) and
   `workspaces.organisation_id`, written by the server only, like `pair_id`.
   A development twin belongs to the organisation of its business. One
   installation; a head on another installation is not part of this record.
3. **Site or house.** The same country and currency as the business: a
   **site** of that business, as before. Another country or another
   currency: a **house**, a business of its own in the organisation. A
   business abroad then gets its country's rules whole, which is how an
   establishment or a company abroad exists in law.
4. **Authority never flows by itself.** Rights stay per business. Nothing is
   mirrored between houses: no trigger gives a role in one house because of a
   role in another (the twin's mirror, ADR 0019, is not extended). Whoever
   creates the organisation owns its head; a business joins it by an act of
   someone who owns both; the head's other owners become owners of a house
   only when the acting owner names them.
5. **A house abroad is added in one task from the head.** The server creates
   the business with the country's defaults and carries the head's
   configuration through the template engine in merge mode. What has an
   amount (fee bands, plans, services, packages, credit products, pass
   offers) is carried with its amounts only when the currency is the same;
   otherwise its structure is carried and it is left to be priced in the
   house's currency. Tax rates are never carried to another country.
   Identity, bank and payment details and counters never travel.
6. **Figures side by side, never added.** The organisation's overview gives,
   per house, the figures a person may read in that house, each in its
   currency, and totals per currency. A house the person may not read
   finance in is named without figures. No amount is converted.
7. **A member is known across houses.** A person active in one house asks to
   join another without an invitation code; the house decides as it decides
   any join, or accepts at once when the organisation says its members are
   welcome in every house. Each house bills its own use in its own currency;
   the person's own space already shows each business apart (ADR 0035).
8. **The Demo's reference is an organisation.** Atelier du Marché heads it;
   London, New York, Zurich, Milan and Leipzig are its houses. A feature tied
   to a country is performed in the house of that country.

## Consequences
- The money core is untouched; every existing business is an organisation of
  one without knowing it.
- The owner of several houses has more than one set of prices, numbering and
  books to keep: one per country, which the law of each country asks anyway.
- There is no grand total across currencies. One would need a stated rate
  and a date, and is its own decision.
- A site in another country with the business's own currency keeps working
  as a site (the seller's country and the place of supply follow it), under
  the business's country rules; a customer who needs that country's rules
  makes it a house.
- New definers read across businesses (the overview, the list of houses).
  Each checks the caller's right house by house; none trusts the
  organisation as a right.
