<!-- anchor: user.people.overview -->
## Members, plans and billing

This chapter is for owners and billing administrators. It follows the money from the person to the price list: who is in your space and on which plan, how each plan is priced, what else you sell, how members pay you, and the costs you pay yourself.

In this chapter:
- [Members & plans](help:user.members.list): the list, the member page and everything you can set for one person
- [Billing](help:user.money.billing.fee-bands): fee bands, subscription levels, day packages and the invoice schedule
- [Services and accessories](help:user.money.services.overview): the extras you sell
- [Payment instructions and online payments](help:user.money.payments.methods): how members pay you
- [Scheduled expenses](help:user.money.expenses.schedule): costs that come back on their own

<!-- anchor: user.members.list -->
### Members & plans

**Audience:** Administrator · Owner

You want to see who is in your space, on which plan, and open anyone to change their settings.

<p><img src="images/user-members-list.en.jpg" width="280"></p>

**Steps**

1. Open [Members & plans](app:/members) from the menu.
2. Read each row: the e-mail, the plan share (or **No subscription**), the role, and a status when it is not the usual one: **Pending**, **Paused** or **Exited**.
3. Tap a row to open that person's [member page](help:user.members.page).

**Good to know**

- A row also shows **max** and **at once** chips when you set a [reservation limit](help:user.members.reservation-limit) or more than one [simultaneous reservation](help:user.members.simultaneous).
- Depending on the features switched on, the top bar (icon buttons with tooltips) offers **Notify all admins**, **Add a managed profile** and, for owners, **Invite a member** and **Billing**.
- Administrators reach this screen too; the controls that change money or roles stay with the owner.

**See also:** [Invite a member](help:user.members.invite) · [Billing](help:user.money.billing.fee-bands)

<!-- anchor: user.members.invite -->
### Invite a member

**Audience:** Owner

You want someone to join your space.

**Steps**

1. In [Members & plans](app:/members), tap **Invite a member**.
2. Share the workspace ID or its QR code, as described in [The workspace ID](help:user.workspace.code).
3. When the person asks to join, their row appears as **Pending**. Open it and choose **Approve membership** or **Reject membership**.

**Good to know**

- Rejecting lets you add a short comment.
- Until you decide, the person has no access to the space.

**See also:** [Pending and paused members](help:user.members.pending) · [Add a managed profile](help:user.members.managed)

<!-- anchor: user.members.managed -->
### Add a managed profile

**Audience:** Administrator · Owner

Someone has no account yet, but you want to book, invoice and manage for them. You create a profile, run it yourself, and hand it over when the person joins.

<p><img src="images/user-members-managed.en.jpg" width="280"></p>

**Steps**

1. In [Members & plans](app:/members), tap **Add a managed profile**.
2. Fill in the person's identity and save. The member page then carries a **Managed** chip.
3. To correct the details later, open the member page and choose **Edit identity**.
4. When the person is ready, choose **Hand over to the person**. It creates a personal code bound to this profile.
5. Changed your mind before the code was used? Choose **Revoke handover**.

**Good to know**

- Whoever uses the code takes the profile over, with its reservations, invoices and subscription, once you approve the membership.
- Nobody can send a message to a managed member, because no one would read it.
- The feature must be switched on in [Features](help:user.features.switch).

**See also:** [The member page](help:user.members.page)

<!-- anchor: user.members.page -->
### The member page

**Audience:** Administrator · Owner

You want everything about one person on a single page: who they are, what they booked, how to reach them, what they owe, and every setting you can change.

<p><img src="images/user-members-page--top.en.jpg" width="280"></p>

**Steps**

1. Tap a member in [Members & plans](app:/members).
2. Read the top of the page: **Right now** shows the next bookings, then come the contact details and the money position.
3. Use the buttons under the name for a quick action. Depending on features and your rights you will see some of **Messages**, **E-mail**, **Add a service** or **Send the financial agreement**.
4. Jump to **Manage** to change the person's settings, grouped as **Membership**, **Booking rules**, **Billing** and **Badges & access**.

**Good to know**

- Every setting row shows its current value, so you rarely need to open it to know the answer.
- Your own page is shorter: nobody can grant themselves rights.
- If the page is not switched on for your space, the same actions appear in a list when you tap the row.

**See also:** [The member's actions](help:user.members.actions) · [Roles and co-owners](help:user.roles.matrix)

<!-- anchor: user.members.actions -->
### The member's actions

**Audience:** Administrator · Owner

You want to know which setting lives where, and who may change it.

<p><img src="images/user-members-actions--membership.en.jpg" width="280"></p>

**Steps**

1. Open a [member page](help:user.members.page) and go to **Manage**.
2. In **Membership**, choose **Pause membership** or **Reactivate membership**, set [Co-ownership](help:user.members.co-ownership), or **Make kiosk device**.
3. In **Booking rules**, set the [Reservation limit](help:user.members.reservation-limit), the [Simultaneous reservations](help:user.members.simultaneous) and the [VAT treatment](help:user.members.vat-treatment); the **Whole-space bookings** switch appears when the feature is on.
4. In **Billing**, set the [Subscription](help:user.members.subscription), [When days run out](help:user.members.overage-policy) and [Price negotiation](help:user.members.negotiation).
5. In **Badges & access**, open **Badges** to issue or revoke the person's badges.

**Good to know**

- Billing and membership changes belong to the owner. Administrators set the booking limits.
- You can never change your own limits or co-ownership.
- Only active members offer most of these rows.

**See also:** [Booking rules](help:user.members.reservation-limit) · [Billing group](help:user.members.subscription)

<!-- anchor: user.members.pending -->
### Pending and paused members

**Audience:** Administrator · Owner

A newcomer waits for your decision, or a member takes a break, and you want the space to treat them accordingly.

<p><img src="images/user-members-pending--membership.en.jpg" width="280"></p>

**Steps**

1. Open the member whose row says **Pending**.
2. Under **Membership**, choose **Approve membership** to let the person in, or **Reject membership** to refuse.
3. To put an active member on hold, open their page and choose **Pause membership**.
4. To bring them back, choose **Reactivate membership**.

**Good to know**

- The decision on a new member can also be taken through the validation rules, as described in [Validation rules](help:user.validation.overview).
- Pausing is for owners and keeps all history.
- A member who left shows **Exited**, and cannot be paused.

**See also:** [Invite a member](help:user.members.invite)

<!-- anchor: user.members.subscription -->
### A member's subscription

**Audience:** Owner

You want to set which share of the month's days a member is entitled to. The share picks the fee band, and the band sets the monthly price.

<p><img src="images/user-members-subscription.en.jpg" width="280"></p>

**Steps**

1. Open the member page, go to **Billing** and tap **Subscription**.
2. Pick **No subscription**, one of the levels you offer, or type a number in **Custom (1–100)**.
3. Tap a level to apply it, or **Save** for a custom value.

**Good to know**

- The levels offered are the ones you chose in [Subscription levels](help:user.money.billing.levels).
- As owner you can always type a custom value.
- **No subscription** is for visitors who buy carnets. It cannot be combined with pay-as-you-go: choose a block or a package first.

**See also:** [Fee bands](help:user.money.billing.fee-bands) · [When days run out](help:user.members.overage-policy)

<!-- anchor: user.members.overage-policy -->
### When days run out

**Audience:** Owner

You want to decide what happens when a member has used their whole monthly allowance.

<p><img src="images/user-members-overage-policy.en.jpg" width="280"></p>

**Steps**

1. Open the member page, go to **Billing** and tap **When days run out**.
2. Choose **Block further booking**, **Charge overage (pay-as-you-go)** or **Require buying a package**.

**Good to know**

- Pay-as-you-go is greyed out for a member without a subscription, because it would let them book for free.
- The overage price comes from the [fee band](help:user.money.billing.band-overage); the packages come from [Day packages](help:user.money.billing.packages).

**See also:** [A member's subscription](help:user.members.subscription)

<!-- anchor: user.members.reservation-limit -->
### Reservation limit

**Audience:** Administrator · Owner

You want to cap how many open reservations one member can hold in total.

<p><img src="images/user-members-reservation-limit.en.jpg" width="280"></p>

**Steps**

1. Open the member page, go to **Booking rules** and tap **Reservation limit**.
2. Tap **No limit**, a preset (1, 2, 3, 5 or 10), or type a number in **Custom (1–100)**.
3. Tap **Save** for a custom number.

**Good to know**

- It counts all open reservations, whenever they fall. It is a different thing from [simultaneous reservations](help:user.members.simultaneous), which counts overlaps.
- The list shows **max** and the number beside the member.
- You cannot set your own limit.

**See also:** [Booking limits](help:user.workspace.availability.limits)

<!-- anchor: user.members.simultaneous -->
### Simultaneous reservations

**Audience:** Administrator · Owner

You want to allow one member to hold bookings that overlap in time, for example two places at once.

<p><img src="images/user-members-simultaneous.en.jpg" width="280"></p>

**Steps**

1. Open the member page, go to **Booking rules** and tap **Simultaneous reservations**.
2. Pick **Workspace default**, or a number: 1, 2, 3 or 5.

**Good to know**

- **Workspace default** follows the number set in [Availability](help:user.workspace.availability.policies); one means one place at a time.
- It is not the same as the [reservation limit](help:user.members.reservation-limit), which counts all open bookings.
- You cannot set your own.

**See also:** [Booking policies](help:user.workspace.availability.policies)

<!-- anchor: user.members.vat-treatment -->
### VAT treatment

**Audience:** Administrator · Owner

You want to tell the app who this member is for VAT, so their invoices carry the right tax.

<p><img src="images/user-members-vat-treatment.en.jpg" width="280"></p>

**Steps**

1. Open the member page, go to **Booking rules** and tap **VAT treatment**.
2. Pick **Automatic**, **Domestic VAT**, **Reverse charge**, **Outside the EU** or **Exempt buyer**.
3. For **Exempt buyer**, type the **Exemption reason (printed on the invoice)**.
4. Tap **Save**.

**Good to know**

- **Automatic** applies the place of supply: a desk, an office or a room carries your VAT for every customer; only a general service (see [Place of supply of a service](#place-of-supply-of-a-service)) is reverse-charged for a business in another EU country, or outside the scope for a business outside the EU. A consumer pays your VAT wherever they live. The dialog shows what the chosen treatment does to each kind of line.
- **Reverse charge** is meant only for a member who buys services not connected with the premises: it applies to every line.
- The same group offers **Customer capacity** (**Business**, **Consumer** or **Not stated**), which decides which payment clauses an invoice prints. It needs the permission to issue invoices.
- **Reverse charge**, **Outside the EU** and **Exempt buyer** are recorded, but the invoices of such members cannot be issued in the app yet: they are issued outside the app with your accountant.
- The **VAT by counterparty** feature must be on for the VAT treatment row, which administrators and owners see; the rates are set in [VAT rates](help:user.money.vat.rates).

**See also:** [VAT regime](help:user.money.vat.regime)

<!-- anchor: user.members.negotiation -->
### Price negotiation

**Audience:** Billing administrator · Owner

You agreed a price with a member that differs from your tariff, and you want it recorded as a deal rather than typed over the tariff.

<p><img src="images/user-members-negotiation.en.jpg" width="280"></p>

**Steps**

1. Open the member page, go to **Billing** and tap **Price negotiation**.
2. Fill only what differs: **Occupation**, **Monthly fee**, **Overage per half-day**, **Discount on supplements**, or a unit price under **Services and packages**.
3. Add a **Note** if useful.
4. Tap **Propose for validation**.

**Good to know**

- A field left empty keeps the tariff.
- The deal waits for validation before it applies, as described in [Validation rules](help:user.validation.overview).
- Once active, the member sees it on their money page, with **Who can see this**. People who may only view negotiations see it as **Read only**.

**See also:** [Fee bands](help:user.money.billing.fee-bands)

<!-- anchor: user.members.co-ownership -->
### Co-ownership

**Audience:** Owner

You want someone to share ownership with you, or to take over if you leave.

<p><img src="images/user-members-co-ownership.en.jpg" width="280"></p>

**Steps**

1. Open the member page, go to **Membership** and tap **Co-ownership**.
2. Choose **No co-ownership**, **Active co-owner**, or **Successor**.
3. To make a co-owner a full owner right away, choose **Promote to owner now**.

**Good to know**

- An active co-owner has owner permissions now, and takes over automatically if you leave.
- A successor becomes owner when promoted or when the owner leaves.
- The row shows **Co-owner** or **Successor** in the members list.
- It needs the **Co-owners** feature to be on, and you cannot change your own co-ownership.

**See also:** [The role matrix](help:user.roles.matrix)

<!-- anchor: user.money.billing.fee-bands -->
### Fee bands

**Audience:** Owner · Billing administrator

You want to price your plans: what a month costs for each share of the days, and what an extra half-day costs.

<p><img src="images/user-money-billing-fee-bands--bands.en.jpg" width="280"></p>

**Steps**

1. Open [Billing](app:/billing) from the menu.
2. Under **Fee bands**, set **To %**, **Monthly fee** and **Overage** on each row.
3. Tap **Add band** to split the last band, or the minus icon to remove one.
4. Choose the **VAT rate** the tariff is taxed at. It is saved as soon as you pick it.
5. Tap **Save** to store the bands.

**Good to know**

- Each row starts where the previous one ends, and the last one always ends at 100%. If the bands do not add up, the screen says "Bands must increase and end at 100%."
- Prices are gross: VAT is included, when your space charges it.
- Removing a band merges its range into the one before.

**See also:** [A member's subscription](help:user.members.subscription) · [Subscription levels](help:user.money.billing.levels)

<!-- anchor: user.money.billing.band-to -->
#### Up to %

The top of the band, from 1 to 100. The next band starts where this one ends, so a percentage always falls into exactly one band. The last band is fixed at 100.

<!-- anchor: user.money.billing.band-fee -->
#### Monthly fee

What a month in this band costs. When you charge VAT the row shows the VAT share included.

<!-- anchor: user.money.billing.band-overage -->
#### Overage

The price of one half-day beyond the allowance, for members whose policy is pay-as-you-go.

<!-- anchor: user.money.billing.levels -->
### Subscription levels

**Audience:** Owner · Billing administrator

You want to choose which percentages you offer when you give someone a plan.

<p><img src="images/user-money-billing-fee-bands--levels.en.jpg" width="280"></p>

**Steps**

1. In [Billing](app:/billing), find **Subscription levels**.
2. Tap a preset (25%, 50%, 75%, 100%) to switch it on or off.
3. To add your own, type a number in **Level (1–100)** and tap **Add level**.
4. Tap **Save**.

**Good to know**

- The levels you pick are the ones offered in a member's [Subscription](help:user.members.subscription).
- Remove a level you added with the cross on its chip.

**See also:** [Fee bands](help:user.money.billing.fee-bands)

<!-- anchor: user.money.billing.level-value -->
#### Level value

One percentage from 1 to 100: the share of the month's days that the plan includes.

<!-- anchor: user.money.billing.custom-level -->
#### Allow a negotiated value

The switch **Allow negotiated custom value** is saved with the levels. As owner you can always type a custom percentage in a member's **Subscription**, whatever this switch says.

<!-- anchor: user.money.billing.packages -->
### Day packages

**Audience:** Owner · Billing administrator

You want to sell blocks of days to members who run out of their allowance.

<p><img src="images/user-money-billing-fee-bands--packages.en.jpg" width="280"></p>

**Steps**

1. In [Billing](app:/billing), find **Day packages**. Each row shows the days, the price and a switch.
2. Switch a package off to stop selling it, or on to sell it again.
3. To create a package, follow [New package](help:user.money.billing.package-new).

**Good to know**

- Members whose policy is **Require buying a package** buy these when their days run out.
- A package that has been sold keeps its price, days and rate. To change them, switch it off and add a new one.

**See also:** [When days run out](help:user.members.overage-policy)

<!-- anchor: user.money.billing.package-new -->
### New package

**Audience:** Owner · Billing administrator

You want to add a block of days to your price list.

<p><img src="images/user-money-billing-fee-bands--new.en.jpg" width="280"></p>

**Steps**

1. In [Billing](app:/billing), under **New package**, type the name, the days and the price.
2. Choose its **VAT rate**.
3. Tap **Add package**.

**Good to know**

- The package is for sale as soon as it appears, switched on.
- Where the carnets feature is on, a **Carnets** editor sits below.

**See also:** [Day packages](help:user.money.billing.packages)

<!-- anchor: user.money.billing.package-name -->
#### Package name

What members see when they buy, and what the invoice line says.

<!-- anchor: user.money.billing.package-days -->
#### Package days

How many days the package grants, one or more.

<!-- anchor: user.money.billing.package-price -->
#### Package price

The price of the whole package, gross. The row shows the days, the price and, when VAT applies, the VAT included.

<!-- anchor: user.money.billing.schedule -->
### Invoice schedule

**Audience:** Owner · Billing administrator

You want to choose when the two automatic invoices go out: the subscription before the month, and the month's consumption after it.


**Steps**

1. Open [Workspace](app:/workspace-settings) and the **Payments & billing** group.
2. Tap **Invoice schedule**.
3. Under **Subscription, in advance**, switch **Issue automatically** on or off and pick **Days before the month starts**. The line below tells you the resulting date.
4. Under **The month just finished**, switch **Issue automatically** on or off. Switch on **Also when there is nothing to pay** to send a document reading zero.
5. Tap **Save**.

**Good to know**

- Each half needs its feature switched on in [Features](help:user.features.switch): "Subscription invoices" and "End-of-month invoices".
- The subscription invoice can therefore name a month that has not started yet.

**See also:** [Reminder rules](help:user.money.reminders.rules) · [Fee bands](help:user.money.billing.fee-bands)

<!-- anchor: user.money.services.overview -->
### A service

**Audience:** Owner · Billing administrator

You sell something that is not a seat: a locker, printing, coffee. You list it once and add it to a member's month in a tap.

<p><img src="images/user-money-services-overview.en.jpg" width="280"></p>

**Steps**

1. Open [Services](app:/services) from the menu.
2. Tap a service to edit it, or the plus button to create **New service**.
3. Fill in the [Name](help:user.money.services.name), the [Price](help:user.money.services.price) and, when you charge VAT, the **VAT rate**.
4. Tap **Save**.

**Good to know**

- A service is never deleted, only deactivated, because invoices refer to it.
- A service that comes from a stock shows how many are left, or **Out of stock**.
- To record one for a member, use **Add a service** on their page.

**See also:** [Accessories](help:user.money.accessories) · [The member page](help:user.members.page)

<!-- anchor: user.money.services.name -->
#### Service name

What the invoice line says. Rename it and only new documents change.

<!-- anchor: user.money.services.price -->
#### Service price

The price of one unit, gross: the member pays exactly this, and VAT is part of it. The **VAT rate** only decides how much of it is tax.

<!-- anchor: user.money.services.supply -->
#### Place of supply of a service

Where the VAT on this service is due. **Connected with the premises**, the default, keeps your VAT for every customer: a desk, an office, a room and whatever is used on the premises are taxed where the building stands. Choose **General service (not connected with the premises)** only for what is not tied to the building, such as mail handling or a virtual office: for a business in another EU country that line is then reverse-charged, and for a business outside the EU it is outside the scope; a consumer still pays your VAT. Each charge keeps the choice it was recorded with. The field shows when you charge VAT and the **Place of supply per service** feature is on.

<!-- anchor: user.money.services.active -->
#### Active

When editing a service, the **Active** switch decides whether it can still be sold. Switch it off for something discontinued; the list greys it and writes **Inactive**.

<!-- anchor: user.money.accessories -->
### Accessories

**Audience:** Administrator · Owner

You rent equipment with a place, such as a monitor or a chair, and charge a supplement for each half-day.

<p><img src="images/user-money-accessories-edit.en.jpg" width="280"></p>

**Steps**

1. Open [Accessories](app:/accessories) from the menu.
2. Tap an accessory, or the plus button for **New accessory**.
3. Fill in **Name** and **Supplement per half-day**; choose the **VAT rate** if your space charges VAT.
4. Switch **Active** off to stop offering it, then tap **Save**.

**Good to know**

- The list shows each supplement as an amount "per half-day", or **No supplement**.
- Like services, accessories are deactivated, never deleted.
- The feature must be on in [Features](help:user.features.switch).

**See also:** [A service](help:user.money.services.overview)

<!-- anchor: user.money.payments.methods -->
### Payment methods and instructions

**Audience:** Owner · Billing administrator

You want members to know how to pay you by transfer or wallet, without you sending the details each time.

<p><img src="images/user-money-payments-methods.en.jpg" width="280"></p>

**Steps**

1. Open [Payment instructions](app:/payment-methods) from the menu.
2. Fill what applies: **IBAN**, **Bank name**, **Account number**, the bank code, **BIC / SWIFT**.
3. Add the wallets you accept: **PayPal.me link or handle**, **Wero phone number**, **Lydia phone number or username**, **Wisetag or Wise payment link**.
4. Add a **Payment reference hint** if members should quote something.
5. Tap **Save**.

**Good to know**

- Members see these details on an unpaid statement. Leave everything empty to show nothing.
- The bank code field is named after your country: sort code, routing number, or bank code.
- This is manual payment. To let members pay by card inside the app, see [The payment provider](help:user.money.payments.provider).

**See also:** [Provider credentials](help:user.money.payments.credentials)

<!-- anchor: user.money.payments.provider -->
### The payment provider

**Audience:** Owner

You want members to pay an outstanding bill online, into your own provider account.

<p><img src="images/user-money-payments-provider.en.jpg" width="280"></p>

**Steps**

1. Switch on the online payments feature in [Features](help:user.features.switch).
2. Open [Online payments](app:/payment-config) from the menu.
3. Find the provider you use: **PayPal**, **Credit card (Stripe)**, **Mollie — iDEAL, Bancontact…** or **Wero (via Mollie)**.
4. Fill its keys, as described in [Provider credentials](help:user.money.payments.credentials), and tap **Save**.
5. Check that the card says **Configured**.

**Good to know**

- Each provider is a separate card with a status chip, **Configured** or **Not configured**.
- Wero is paid through Mollie: enter the same Mollie API key and return URL on the Wero card as on the Mollie card.
- Providers charge their own fees. The manual transfer route stays free.
- **Remove** clears a provider.

**See also:** [Payment methods](help:user.money.payments.methods)

<!-- anchor: user.money.payments.credentials -->
#### Provider credentials

The keys come from the provider's own dashboard: **Client ID**, **Secret**, **Environment**, **Webhook ID** and **Return URL** for PayPal; **Secret key**, **Webhook signing secret** and **Return URL** for Stripe; **API key** and **Return URL** for Mollie and Wero. Keep test and live keys apart: all keys you enter must belong to the same mode.

Secrets are stored on the server and never shown again. A saved one reads **Set — leave blank to keep**; type a new value to replace it.

<!-- anchor: user.money.expenses.schedule -->
### Scheduled expenses

**Audience:** Member · Administrator · Owner

You pay for something that comes back, such as internet or electricity. You describe it once and the app presents each due date to you.

<p><img src="images/user-money-expenses-schedule.en.jpg" width="280"></p>

**Steps**

1. Open [Money](app:/money) and the **Payments** face.
2. Tap **Scheduled expenses**. Existing schedules show their amount, rule, state and next date.
3. Tap **Schedule a recurring expense** and fill in the form, as described in [What](help:user.money.expenses.what) and the fields after it.
4. Tap **Schedule it**.

**Good to know**

- A new schedule is **Awaiting validation** until the validators confirm it, then **Active**. It can also end **Rejected** or **Ended**.
- Each due date is then presented to you before it counts: confirm it at the validated amount, or at another amount with an explanation, which is validated again.
- Tap **End this schedule** to stop one. Finished ones are listed under **Ended and rejected**.
- The feature must be on in [Features](help:user.features.switch).

**See also:** [Validation rules](help:user.validation.overview)

<!-- anchor: user.money.expenses.what -->
#### What

<p><img src="images/user-money-expenses-what.en.jpg" width="280"></p>

The name each occurrence carries, for example Internet. Write it as you want to read it later. **Amount** is what one occurrence costs, and **Description** is optional text for whoever validates.

<!-- anchor: user.money.expenses.amount -->
#### Amount

What one occurrence costs, in your workspace currency. A different amount at confirmation needs an explanation and is validated again.

<!-- anchor: user.money.expenses.description -->
#### Description

Optional text for the validators, such as a contract number or a supplier reference.

<!-- anchor: user.money.expenses.starts-on -->
#### First occurrence

The date the first one falls due. Every later date counts from here.

<!-- anchor: user.money.expenses.every -->
#### Every

The interval, a number and a unit: days, weeks, months or years. Every 1 month reads "monthly".

<!-- anchor: user.money.expenses.times -->
#### Number of times

The field **Repetitions (empty = until the end date)**: how many occurrences to raise.

<!-- anchor: user.money.expenses.ends-on -->
#### Until

**Until (optional)** is the date after which nothing more is raised. With both a number and a date, the series stops at whichever comes first. With neither, it runs until you end it.
