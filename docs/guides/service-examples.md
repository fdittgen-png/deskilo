<!-- SPDX-License-Identifier: AGPL-3.0-or-later -->
# Two illustrative cost comparisons (#4207)

The evaluation page (`web/product.html`) has a section, "Who provides what",
that separates three ways to run DesKilo: by yourself, on your own server with
a service engagement, and hosted by the author. It marks what is **to be
agreed** instead of inventing a price, hours or a service level. This page
shows the page's own planner (`web/cost_planner.js`) used twice.

**Every figure below is an assumption someone typed in.** None is a DesKilo
price, a competitor price or a saving. The planner looks nothing up. Taxes are
not included. Replace each value with your own.

## Solo operator

One person, one place, a monthly server plan of 25 and a backup service of 10.

| Field | Value |
|---|---|
| Setup hours, value of an hour | 8 h at 40 |
| Server plan, storage used / included | 25, 4 GB / 8 GB |
| Backup and monitoring | 10 |
| Online payments | 20 a month, 50 on average, 1.5 % + 0.25 each |
| Admin hours | 2 a month, at the same hourly value |
| Assistant | members bring their own |

Planner result: one-time setup 320.00; each month 135.00
(25 + 10 + 20 payment fees + 80 for the admin hours). The storage used is
within the storage included, so it adds nothing.

Leave the admin hours blank and the planner says "Each month: 55.00 (at least
— some values are still unknown)" and lists admin hours as not counted. Unpaid
owner administration is never treated as zero.

## Small multi-activity business

Several activities on one server, more members, more payments.

| Field | Value |
|---|---|
| Setup hours, value of an hour | 20 h at 40 |
| Server plan, storage used / included, price per extra GB | 25, 15 GB / 8 GB, 0.125 |
| Backup and monitoring | 10 |
| Online payments | 150 a month, 45 on average, 1.5 % + 0.25 each |
| Admin hours | 6 a month, at the same hourly value |
| Assistant | members bring their own |

Planner result: one-time setup 800.00; each month 414.63
(25 + 0.875 for 7 GB over + 10 + 138.75 payment fees + 240 for the admin
hours, rounded to the cent).

## What these examples do not contain

- A service engagement or hosting fee from the author. Those terms are "to be
  agreed" on the page, and the planner has no row for them: add the amount you
  are quoted as the server plan or the backup and monitoring value, labelled as
  yours.
- The hosting floors planned from 1 January 2028 (README, "Privacy, push
  notifications and costs"). They are a hosting tariff, not a support quote.
- Any claim that either business saves money against something else.

`tool/web/product_page_test.mjs` recomputes both examples, so the figures
above cannot drift from the calculator.
