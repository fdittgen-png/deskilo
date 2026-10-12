# DesKilo business plan

Status: proposal for the owner's decision. Prices exclude VAT. Every figure below is a
planning assumption, not an observed sale. The welcome page, the store listings and the
README state the same tariff and mark it as planned until the owner confirms it.

## 1. Decision in one paragraph

Sell **managed operations and expertise**, never software access. The software stays free
(AGPL-3.0) with every capability, on the reference server or on a customer's own Supabase
project. Revenue comes from (a) managed hosting from **1 January 2028** and (b) a small
fixed-price services catalogue that pays the bills before the hosting base exists.

**The app is completely free for everyone until 31 December 2027.** No hosting charge is
raised before 1 January 2028, so 2027 is a services-only year: the plan below starts its
hosting clock at 2028-01.

## 2. Is the supplied plan sustainable?

Arithmetic: sound. Average revenue €122, direct cost €55.17, contribution €66.83 per
workspace and break-even at 120 (hosting only) or 84 (with €4 000/month of services) all
reproduce. The unit economics are credible because human support time is in the cost.

Assumptions that carry the result and are the weak points:

| Assumption | Plan | Why it is fragile | What I use |
|---|---|---|---|
| Monthly churn | 1 % | Small associations and independent spaces close, merge or switch; 2–3 % is the norm for small-business SaaS | 2 % base, 3 % stress |
| Gross adds per month in year 3 | ≈ 8 | Needs ≈ 20 demos a month from a product that calls itself a beta, in two countries, with one person selling and supporting | Half the plan in the base case |
| Free threshold of 5 | — | A jump from €0 to €79 at the sixth member is a cliff that pushes spaces to self-host or stay at five | A bounded shared paid tier (below) |
| Founder budget | €36 k → €60 k from month 1 | Fixed cost before evidence of willingness to pay | Part-time until gates 3 and 4 are met |
| Hosting revenue from month 1 | yes | Nothing is billed before 2028-01 | Revenue starts 2028-01 |

Recomputing the plan's own churn and adds with my assumptions (instant-start, 122 € average
revenue, ending workspace counts):

| Case | Adds / year (1-2-3) | Churn | Paying workspaces end of year 3 |
|---|---|---|---|
| Supplied base | 22 · 60 · 96 | 1 % | ≈ 158 |
| Same adds | 22 · 60 · 96 | 2 % | ≈ 140 |
| Same adds | 22 · 60 · 96 | 3 % | ≈ 126 |
| Half the adds | 11 · 30 · 48 | 2 % | ≈ 70 |
| Half the adds | 11 · 30 · 48 | 3 % | ≈ 63 |

Break-even needs 120 (hosting only) or 84 (with services). With half the adds the base
never reaches either, so **the business is sustainable only if acquisition reaches the
supplied pace or the cost base stays small.** The cash number (€64 k peak need) is also
understated for the 2027 timing: a full founder budget through a year with no hosting
revenue adds roughly the first year's budget on top.

Conclusion: viable as a **services-funded, part-time-first** business that grows hosting
revenue; not viable as a full-time salary from day one on a beta product.

## 3. What I would change

1. **Start date and funding.** Hosting revenue starts 2028-01. 2027 is funded by services
   (assisted launch, migrations, report templates) and by 8–10 paying pilots on services
   orders. No full-time founder budget until gate 4 (section 8) is met.
2. **Remove the cliff.** Keep the three isolated tiers, and add a lower, bounded one on the
   shared pool:

   | Tier | Active subscribers | Price / workspace / month | Hosting |
   |---|---|---|---|
   | Community | up to 5 (nonprofit: 8) | €0 | Shared community instance |
   | Shared | 6–15 | €29 | Shared instance, published limits |
   | Essential | 16–25 | €79 | Own Supabase project |
   | Growth | 26–75 | €149 | Own Supabase project |
   | Scale | 76–200 | €299 | Own project, larger compute |
   | Larger | above 200 | Quotation | After a workload assessment |

   The Shared tier costs little (the pool exists), makes the first payment small, and
   gives a path to Essential instead of a choice between €79 and leaving. Its cap and
   resource envelope are published and measured; resizing the pool is funded from it.
3. **Counting rule** (unchanged in spirit, simplified): a subscriber is a distinct person
   with an active recurring membership, whoever pays. Free eligibility is judged per legal
   operator across its workspaces; paid tiers per separately hosted workspace. Zero-price
   recurring memberships count. Pending invitations, former members, visitors and
   admin-only accounts do not.
4. **Billing discipline.** Monthly billing first. Annual prepayment (two months free) only
   after two quarters of measured support and infrastructure cost. No lifetime offers.
5. **Support scope.** Business-day email support. No 24/7 promise and no point-in-time
   recovery inside €79. Recovery targets stay internal until restored in a drill.
6. **Self-hosting stays unrestricted.** The five/eight threshold applies to managed hosting,
   never to the right to run the software. BYOD Care (from €69/month) is added only with a
   bounded written scope.
7. **Services.** Fixed-price outcomes, deposits and staged acceptance, as supplied. The
   report designer and every module stay free; customers pay for design, verification and
   handover. Commissioned features that are generally useful go into the main product
   (AGPL); no proprietary-exclusive derivative is promised.
8. **Grandfathering is an owner decision.** The previous wording said spaces *registered by
   31 December 2027* host free, which can be read as free for ever. The tariff in this plan
   applies to everyone from 2028-01-01, with price confirmation and the move-or-export
   choice shown at least 90 days before. If early registrants are to be exempt, that
   exemption must be funded in the model. Until the owner decides, the public text says
   "free for everyone until 31 December 2027" and nothing about earlier registrants after.

## 4. Unit economics (per paying workspace per month)

| | Shared | Essential | Growth | Scale |
|---|---|---|---|---|
| Price | €29.00 | €79.00 | €149.00 | €299.00 |
| Compute / pool share | €3.00 | €15.00 | €15.00 | €60.00 |
| Independent object backups | €1.00 | €3.00 | €5.00 | €10.00 |
| Monitoring and usage allowance | €1.00 | €5.00 | €10.00 | €20.00 |
| Direct support labour | €5.00 | €9.00 | €15.75 | €29.25 |
| Collection and loss provision | €1.00 | €2.67 | €4.77 | €9.27 |
| Technical contingency | €1.50 | €4.60 | €6.00 | €18.00 |
| **Total direct cost** | **€12.50** | **€39.27** | **€56.52** | **€146.52** |
| **Contribution** | **€16.50** | **€39.73** | **€92.48** | **€152.48** |
| Margin | 57 % | 50 % | 62 % | 51 % |

Essential, Growth and Scale are the supplied figures (USD/EUR parity assumed; the Growth
tier on Small compute is to be load-tested). The Shared column is my estimate and must be
measured on the pool before the price is final. Supabase database backups do not include
Storage files; the object backup line pays for that.

## 5. Planning model

| | Year 0 (2027) | Year 1 (2028) | Year 2 (2029) | Year 3 (2030) |
|---|---|---|---|---|
| Hosting | free for everyone | ramp from zero | — | — |
| Services hours billed | 160 | 160 | 288 | 384 |
| Services revenue at €125/h | €20 000 | €20 000 | €36 000 | €48 000 |
| Fixed costs (free pool, platform, tooling, insurance, legal, marketing) | €12 000 | €18 000 | €24 000 | €36 000 |
| Founder cost (total to the business) | part-time, ≤ €24 000 | €36 000 | €48 000 | €60 000 |

Hosting revenue per year follows from workspaces × €122 average (mix 60/30/10 over
Essential/Growth/Scale; the Shared tier lowers the average until measured). Break-even with
fixed + founder = €8 000/month at year-3 scale: 120 workspaces hosting-only, 84 with
€4 000/month of services at 60 % contribution. Sensitivities from the supplied model hold:
+30 minutes of support per workspace per month moves hosting-only break-even to ≈ 181;
a blanket 20 % discount to ≈ 186. **The main risk is underpriced human work**, then
discounting, then customer-specific maintenance.

Funding: peak need ≈ €64 k in the supplied model for 2028–2030, plus the 2027 services-only
year at a part-time founder cost. Plan €75 k–€85 k of runway or a services business that
covers the founder cost; do not commit a full-time cost base before gate 4.

## 6. Architecture the model requires

A personal identity/control plane (Me) separate from workspaces; one shared project for the
free and Shared tiers; one Supabase project per Essential-and-above workspace; customer-owned
projects outside the managed fleet. Workspace migration, cancellation or payment failure
never migrates or deletes the personal account. Failed payment: reminder, restricted
operation, export window, then — never immediate deletion. The work that protects the
model: provisioning automation, tenant isolation, billing transitions, tested workspace
migration (records, files, configuration, access, with reconciliation and rollback), fleet
upgrades and complete recovery. The subscriber count and the tier a workspace belongs to
must be computed by the app, shown to the owner before the sixth active subscriber is
activated, and show the alternative (move to your own instance).

## 7. Acquisition

Sell to operators who already have 10–100 members, in France and Germany first; the free
tier is the adoption channel, not the pipeline. Build a list of ≈ 100 prospects, run 20
structured interviews, recruit 8–10 pilots (commercial and nonprofit). A pilot that is
enthusiastic but does not sign a services order is not a customer. Maximum acquisition cost
€600 including founder time (≈ 9 months of contribution payback). Referrals, regional
networks and partners before paid advertising. Donations, advertising, marketplace
commissions and enterprise deals are excluded from the model.

## 8. Gates

| When | Required before spending more |
|---|---|
| Now – 2027-03 | Counting rule, tiers and grandfathering decided; 20 interviews; the pool measured; Shared-tier limits published |
| 2027-04 – 2027-09 | Two isolated paid projects and the Shared pool demonstrated; billing transitions, migration, object backup and a restore drill tested; ≥ 3 signed services orders |
| 2027-10 – 2027-12 | Billing code and the app's tariff screens live behind a feature flag, off; price confirmation sent ≥ 90 days before 2028-01-01 |
| 2028-01 – 2028-06 | ≥ 5 paying workspaces through two billing cycles; real support minutes per workspace measured |
| 2028-07 – 2028-12 | Work toward ≈ 20 retained paying workspaces; raise acquisition spend only when churn ≤ 2 % and margin ≥ 50 % |

## 9. What the publication changes

- **Welcome page** (`web/welcome/`): a Pricing section with the planned tariff, "free for
  everyone until 31 December 2027", and the corrected hosting text and FAQ (replaces the
  2027-registration wording).
- **README**: the cost paragraph says the same.
- **Android (Play and F-Droid) and iOS listings** (`fastlane/metadata/`): one sentence on
  cost — software free, hosting free for everyone until 31 December 2027, planned tariff
  from 1 January 2028, own instance never charged. No purchase link or price inside the
  apps (Apple 3.1.1 and Play payments policy: managed hosting is billed outside the app, as a
  business service). F-Droid reads the same Android metadata; the recipe's anti-features
  stay empty because the server is configurable and self-hostable.
- Not done here: the billing implementation, the tier screens in the app and the
  store-console price/“contains purchases” declarations. They are needed only when billing
  is built (gate 3) and stay unchanged until then.
