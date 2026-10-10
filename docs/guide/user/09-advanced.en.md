<!-- anchor: user.advanced.overview -->
## Advanced

**Audience:** Owner · Operator

The things around the everyday work: the test side of a space and the real one, assistants, the task recorder and its guided tours, the demo, the apps on each device, and what to do when something does not work.

In this chapter:
- [A space has two sides](help:user.advanced.environments) · [Enter a side](help:user.advanced.enter-environment) · [A test space](help:user.advanced.test-space) · [Who may deploy](help:user.advanced.deploy-permissions) · [Deploy between the sides](help:user.advanced.deploy) · [Workspace status and the year archive](help:user.advanced.status-archive)
- [Your own server](help:user.advanced.own-server)
- [Assistants](help:user.advanced.assistants) · [Connect an assistant](help:user.advanced.assistants-connect) · [Approvals](help:user.advanced.assistants-approve) · [What assistants may do](help:user.advanced.assistants-policy)
- [The task recorder](help:user.advanced.recorder) · [Record a task](help:user.advanced.recorder-record) · [Review a recording](help:user.advanced.recorder-review) · [Make a guide](help:user.advanced.guide-make) · [Follow a guide](help:user.advanced.guide-play) · [The circle menu](help:user.advanced.guide-circle) · [Edit a guide](help:user.advanced.guide-edit) · [Privacy of recordings](help:user.advanced.recorder-privacy)
- [The demo workspace](help:user.advanced.demo) · [Filming mode](help:user.advanced.filming)
- [Platforms](help:user.advanced.platforms) · [Support details](help:user.advanced.support) · [When something does not work](help:user.advanced.troubleshooting)
- [The app's words](help:user.advanced.glossary) · [Accessibility and keyboard](help:user.advanced.accessibility) · [More help](help:user.advanced.help)

<!-- anchor: user.advanced.environments -->
### A space has two sides

**Audience:** Owner

You want a place to try things out without touching the real bookings and invoices. A space can come as a pair: a test side and a real side, with the same name.

<p><img src="images/user-advanced-environments.en.jpg" width="280"></p>

**Steps**

1. When you create a space, keep **Create the development and production pair** ticked. Both sides belong to you from the first second.
2. Already have a space on its own? Open [Settings](app:/settings), go to **Governance** and tap **Create its twin**. The configuration is copied once.
3. From then on the two sides are independent. Only a deployment moves anything from one to the other.

**Good to know**

- The development side is called **Development — for trying things out**. The production side is **Production — the invoices are owed**.
- Every document printed on the development side carries a watermark, so it cannot be mistaken for a real one.
- **Create its twin** only appears when the **Environment pairs** feature is on, and only to the owner. Deploying between the sides belongs to the holders of the deploy permissions.
- Members, bookings, invoices and payments are never copied between the sides.

**See also:** [Enter a side](help:user.advanced.enter-environment) · [A test space](help:user.advanced.test-space)

<!-- anchor: user.advanced.enter-environment -->
### Enter the real side or the test side

**Audience:** Everyone

You want to open a space on the side you need. Your account sees both sides of a pair, each with its own button.

**Steps**

1. Open [Me](app:/me) and find the space under **My spaces**.
2. Tap **Open workspace** for the real side, or **Test space** for the side to practise on.
3. Or open [Profiles](app:/profiles): the pair is one card. Tap it, then **Choose an environment** between **DEV** and **PROD**.

**Good to know**

- A side you may not enter is greyed out and does nothing.
- A person who is a member of the real side is always a member of the test side too.
- The test button carries the hint "Test space: practice bookings and invoices"; the real one "Real bookings and invoices".

**See also:** [Who may deploy](help:user.advanced.deploy-permissions)

<!-- anchor: user.advanced.test-space -->
### What a test space is for

**Audience:** Owner

You are about to change prices, rules or the plan and want to see the effect first. Do it on the test space.

**Steps**

1. Enter the test side with **Test space**.
2. Configure, import a space file, invite a colleague, issue a trial invoice, move seats, print.
3. When it is right, [deploy it to the real side](help:user.advanced.deploy).

**Good to know**

- The **Workspace type** switch in [Settings](app:/settings) (under **Governance**) says which kind a space is. Only owners see it.
- Declaring a space production asks **Declare this workspace production?** — the banner goes away and documents lose their watermark. Invoices already issued keep the watermark they had.
- Declare production only when the invoices leaving the space are really owed.
- When you invite someone, you can choose whether they also reach the production space: **Test workspace** or **Production workspace**. They join the test space either way.

**See also:** [A space has two sides](help:user.advanced.environments)

<!-- anchor: user.advanced.deploy-permissions -->
### Who may deploy and enter production

**Audience:** Owner · Co-owner

You decide who may touch the real side. Three permissions in the role matrix control it.

**Steps**

1. Open [Roles](app:/roles).
2. Find **Enter the production workspace**, **Deploy to development** and **Deploy to production**.
3. Switch each on for the roles that need it.

**Good to know**

- Owners and co-owners hold all three. Administrators hold **Deploy to development** and **Enter the production workspace**. Members hold none until you give it.
- Whoever may deploy to production may always deploy to development.
- A role enters the production side only while it holds **Enter the production workspace**: an invitation or a join into production is refused otherwise, and the app says why.

**See also:** [The role matrix](help:user.roles.matrix) · [Deploy between the sides](help:user.advanced.deploy)

<!-- anchor: user.advanced.deploy -->
### Deploy between the two sides

**Audience:** Owner · Co-owner · Administrator

You settled the configuration on one side and want the other to have it.

**Steps**

1. Stand on the side you want to write, and open [Settings](app:/settings) → **Governance** → [Deployment](app:/deployment).
2. Tick what should travel. Entities are grouped as **Configuration**, **Master data** and **Reports**; what an entity **needs** is ticked with it.
3. Tap **Pull from PROD…** (from the development side) or **Pull from DEV…** (from the production side).
4. Read the preview: **What changes on the production side**, or on the development side. When both sides agree, it says **No change**.
5. Confirm. The question names the side that is written: **Deploy into this DEV?** or **Deploy into this PROD?**

**Good to know**

- A deployment always goes into the side you stand on. Nothing can be pushed onto the other side by mistake.
- Every deployment lands in the **Journal**. **Roll back** on the latest one puts back what the side held before.
- Floor plans are merged: what only this side has is kept, because a seat may hold a booking. Badge tags never travel.
- Members, bookings, invoices, payments, events and credentials never travel.
- The entry only shows when the **Deployments** feature is on, the space has a twin, and you hold a deploy permission.

**See also:** [Who may deploy](help:user.advanced.deploy-permissions)

<!-- anchor: user.advanced.status-archive -->
### Workspace status and the year archive

**Audience:** Owner · Administrator · Billing administrator

You want one look at what the space invoiced and collected, and a complete file of the year for your records.

**Steps**

1. Open [Workspace status](app:/money/status). Pick the months in **From** and **To**.
2. Read **Invoiced**, **Credit notes**, **Payments matched**, **Payments received**, **Expenses reimbursed**, **Expenses shared out** and **Credits granted**; **Net** sums it up. Tap the printer to **Print the status**.
3. For the yearly file, choose **Year archive (zip)** in the invoice exports.

**Good to know**

- **Net** is neither a profit nor a bank balance. Matched and received payments overlap, so do not add them together.
- The status appears when the **Workspace status** feature is on.
- A development space produces files marked DEV: they are not the real books.

**See also:** [Workspace report](help:user.workspace.export.workspace-report)

<!-- anchor: user.advanced.own-server -->
### Run your own server

**Audience:** Operator · Owner

You want your community's data on a server you control, or you belong to an organisation that runs one.

**Steps**

1. Read how a server is set up in [How to run your own](help:user.backend.how).
2. On each device, point the app at it: [Your own server](help:user.backend.server).
3. Check [Me](app:/me) → **Where my spaces live**: it lists the servers this account uses.

**Good to know**

- The app points at one server for sign-in; **This device uses** shows which. The other servers you belong to appear under **Where my spaces live**.
- An invitation is only checked on its own server, so join a space while the app points at the server that issued it.
- An operator can switch assistants on for the whole installation — see [Approvals](help:user.advanced.assistants-approve).

**See also:** [Your own server](help:user.backend.server)

<!-- anchor: user.advanced.assistants -->
### Assistants: what they are

**Audience:** Everyone

An AI assistant such as Claude or ChatGPT can check and book things for you in DesKilo. It acts as you, only in the workspaces and for the actions you approve.

<p><img src="images/user-advanced-assistants-policy.en.jpg" width="280"></p>

**Steps**

1. Open [Assistants](app:/assistants). **Where you stand here** lists what is still missing for you: **Google sign-in**, **Identity for assistants**, **Database approval**, **Workspace offer**, **Your role**, **Your consent**, **Server**.
2. Work down the list; each line says who takes the next step.

**Good to know**

- Several people take part: you, the owner or an administrator of the workspace, a database administrator and the installation's operator. No single person can open everything.
- Switching assistants on grants nobody anything by itself.
- Under **Connected assistants** you see what is connected and can **Disconnect** it. **Your assistant use today** counts **Requests**, **Refused**, **Applied** and **Awaiting validation**.

**See also:** [Connect an assistant](help:user.advanced.assistants-connect)

<!-- anchor: user.advanced.assistants-connect -->
### Connect an assistant

**Audience:** Member · Administrator · Owner

You want your assistant to work with your own bookings and account.

**Steps**

1. Open [Connect an assistant](app:/assistants/connect). Under **Before you connect**, every line should say **Done**.
2. Under **Which assistant do you use?**, pick **Claude**, **Claude Code**, **ChatGPT**, **Cursor**, **VS Code** or **Other**. Copy **Your DesKilo address for assistants** into it as the steps show.
3. Sign in when the assistant asks, then pick this workspace and what the assistant may do there.
4. Tap **Test the connection** and ask your assistant: "Using DesKilo, what are my bookings this week?"

**Good to know**

- The assistant itself asks you to approve the workspace and each kind of operation; nothing is chosen for you.
- Connecting needs the **MCP interface** feature in the workspace. If it is off, the screen sends you to Assistants.
- Not working? **Test the connection** says what it still waits for.
- **Disconnect** removes the assistant from every workspace on this database. What it already read is not taken back.

**See also:** [Approvals](help:user.advanced.assistants-approve)

<!-- anchor: user.advanced.assistants-approve -->
### Approvals and confirmations for assistants

**Audience:** Owner · Operator

Assistants are approved in layers, so a person cannot switch one on alone.

**Steps**

1. The workspace owner (or whoever manages integrations) opens [Assistant setup](app:/settings/assistant-setup) and works down it: **Turn assistants on for this workspace**, **Choose what assistants may do**.
2. Each member asks once: **Ask for approval**. A database administrator decides in [Assistant approvals](app:/database/assistant-approvals) with **Approve** or **Reject**.
3. The installation's operator opens [Installation: assistants](app:/installation/assistants) and taps **Turn on for every workspace**. The page also lists **Database administrators** and **Assistant clients**, each **Approved**, **Blocked** or **Waiting for approval**.
4. When an assistant sends a high-impact request, you are asked: **Confirm an assistant request**. **Confirm** lets it send that exact request once; **Decline** does nothing.

**Good to know**

- Approvals and the installation's changes need your second factor.
- Approval expires; the screen tells you the days left and you ask again.
- A confirmed request still follows the workspace's validation rules.
- With no other database administrator, the operator approves access, with a reason, for up to 30 days.

**See also:** [What assistants may do](help:user.advanced.assistants-policy)

<!-- anchor: user.advanced.assistants-policy -->
### What assistants may do in a workspace

**Audience:** Owner · Administrator

You decide which services a workspace offers to assistants.

**Steps**

1. Open [Assistant access](app:/settings/assistants).
2. Switch **Offer assistant services** on.
3. Under **Records an assistant may act on**, choose **Own records only** or **Workspace-wide**.
4. Tick the operations, in groups: **Own bookings and account**, **Financial requests**, **Membership requests**, **Validations**.
5. Tap **Save**.

**Good to know**

- Operations read like "See free places", "Book a place for you", "Check you in" or "Cancel your bookings that have not started".
- Assistants get minimised answers. **Optional details** lets you allow more; each person still chooses for themselves.
- Assistants already connected only get new services when each person approves again.
- Turn the **MCP interface** feature on in [Features](app:/features) first. It is off by default.
- It is for people who hold the integrations permission; owners always do.

**See also:** [A feature switch](help:user.features.switch)

<!-- anchor: user.advanced.recorder -->
### The task recorder and guided tours

**Audience:** Everyone

You want to show someone how a task is done, or be shown. Record the task once, turn it into a guide, and follow it step by step on the real app.

<p><img src="images/user-advanced-wizard.en.jpg" width="280"></p>

**Steps**

1. Open the [Task wizard](app:/task-wizard): in the menu on a wide screen, or under **Advanced** in [Me](app:/me).
2. **Guides** holds your own guides and the ones that come with the app, such as **Book a place**.
3. **Recordings** lists the tasks you recorded, and **Record a task** starts a new one.
4. **Tools** opens a task file without an account.

**Good to know**

- Everything stays on your device until you export it.
- The task recorder is a feature (**Task recorder**). When it is off, the Task wizard does not appear in the menus.
- You need to be signed in to record or to follow a guide.

**See also:** [Record a task](help:user.advanced.recorder-record) · [Follow a guide](help:user.advanced.guide-play)

<!-- anchor: user.advanced.recorder-record -->
### Record a task

**Audience:** Everyone

You want to capture what you do, so it can become a document or a guide.

<p><img src="images/user-advanced-record.en.jpg" width="280"></p>

**Steps**

1. In the [Task recorder](app:/task-recorder), read **Before you record**.
2. Tap **Start recording**.
3. Do the task as usual, on any screen of the space or of [Me](app:/me).
4. Use the bar that shows **Recording** to **Pause**, **Resume**, **Add a note** or **Stop**.

**Good to know**

- A recording lasts up to 500 steps or 30 minutes, and is deleted from the device after 30 days. A file you exported stays where you saved it.
- Each step names the screen, the action and what the app answered, such as **Booked** or **Refused**.
- Sign-in, payment, messages and other protected screens leave only a marker.
- If you move to another account or workspace, the recording ends.

**See also:** [Privacy of recordings](help:user.advanced.recorder-privacy)

<!-- anchor: user.advanced.recorder-review -->
### Review, edit and export a recording

**Audience:** Everyone

You want to check what was captured before you share it.

**Steps**

1. In the [Task wizard](app:/task-wizard), tap a recording under **Recordings**.
2. Read the steps. Tap **Leave out of the export** on any step you do not want; **Put back** brings it back.
3. Look at **What the file will contain**.
4. Choose **Export a file**, **Export a task package** or **Export as Word document**.

**Good to know**

- Leaving a step out changes only the export. The recording on the device is unchanged.
- To read a file from someone else, use **Open a task file** in the [Task workbench](app:/task-workbench). Nothing is uploaded, and no account is needed.
- A damaged file or a file made by a newer version is refused with a plain message.
- **Delete from this device** removes the recording; exported files are not touched.

**See also:** [Make a guide](help:user.advanced.guide-make)

<!-- anchor: user.advanced.guide-make -->
### Make a guide from a recording

**Audience:** Everyone

You want others to follow a task you recorded.

**Steps**

1. In the [Task wizard](app:/task-wizard), tap **Make a guide** beside a recording. Or choose **Add a guide** → **From one of my recordings** or **From a task file or package**.
2. Check the draft. Each step is written as the reader will see it.
3. Give it a name under **Name of the guide**.
4. Tap **Add to my guides**.

**Good to know**

- The guide is kept on your device under **Guides**. A guide can be edited or deleted: **Delete this guide** does not touch its recording.
- A step that books waits for the real answer. Nothing is done for the reader.
- **Save the guide** writes it to a file you can hand over.

**See also:** [Edit a guide](help:user.advanced.guide-edit)

<!-- anchor: user.advanced.guide-play -->
### Follow a guide

**Audience:** Everyone

You want to be walked through a task on the real screens.

**Steps**

1. In the [Task wizard](app:/task-wizard), tap **Start the guide** beside one of the guides.
2. A panel shows Step 1 of … and what to do, for instance "Tap “Reserve”." or "Fill in “…”, then leave the field."
3. Tap **Open & highlight** to go to the right screen and see the control marked.
4. Do the step yourself. The guide notices and moves on. For a reading step, tap **Done**.

**Good to know**

- Use **Back** and **Skip**, and open **All steps** to see each one as **To do**, **Waiting**, **Done**, **Acknowledged** or **Skipped**.
- A step that books waits for the answer: **Waiting for the result…**. If it is refused, the guide says what to try; if no answer came, it asks you to check before trying again.
- **Stop the guide** ends it. Nothing is undone.
- The guide pauses when the account or workspace changes, or when the task recorder is turned off.

**See also:** [The circle menu](help:user.advanced.guide-circle)

<!-- anchor: user.advanced.guide-circle -->
### The circle menu

**Audience:** Everyone

You need the whole screen to work, but want the guide close by. Minimise it.

**Steps**

1. In the guide panel, tap **Minimise the guide**. It shrinks to a small circle.
2. Tap the circle for a menu: Show the guide (step … of …), **Open & highlight**, a button to the step's page, **Done**, **Skip**, **Back**, **Resume** and **Stop the guide**.
3. Pick **Show the guide** to open the panel again.

**Good to know**

- The menu only offers what makes sense now: **Resume** only while paused, **Done** only for a reading step.
- The panel's **Close** hides it; the guide itself stays where it was.
- Open & highlight takes you to the page of the step and points at the control; the page button takes you to the page only.

**See also:** [Follow a guide](help:user.advanced.guide-play)

<!-- anchor: user.advanced.guide-edit -->
### Edit or repair a guide

**Audience:** Everyone

A guide reads badly, or a step points to the wrong page. Fix it in the draft.

**Steps**

1. In the [Task wizard](app:/task-wizard), tap **Edit** beside your guide.
2. On a step, tap **Write the words** and type your own text.
3. Under **Step destination**, choose the page the step refers to. Tap **Open & highlight** to check.
4. Switch **The reader may skip it** on for a step that is optional.
5. Tap **Save the changes**.

**Good to know**

- A step marked **An instruction still to be written** needs your words. **A step the recorder cannot describe** and **Do this step yourself** are done by the reader.
- Steps on protected screens, such as payment, ask the reader to do them alone.
- You cannot make a guide expect an outcome its action does not have; that part is fixed.
- A guide that names steps this version does not know can be read, not followed.

**See also:** [Make a guide](help:user.advanced.guide-make)

<!-- anchor: user.advanced.recorder-privacy -->
### What a recording keeps

**Audience:** Everyone

You want to know exactly what leaves nothing behind.

**Steps**

1. Open the [Task recorder](app:/task-recorder).
2. Read **Before you record**.
3. Leave **Capture values (for issue reports)** off unless a developer asked for it.

**Good to know**

- Normally a recording never keeps what you type, names, amounts, messages, codes or passwords.
- With **Capture values** on, it also keeps what you type and choose, so a developer can reproduce a problem. Passwords, payment details, e-mail addresses and phone numbers are still never kept. Exporting it asks **This recording contains values**.
- Nothing is uploaded: you decide what to export.
- Share a file only with people who should see what you entered.

**See also:** [Record a task](help:user.advanced.recorder-record)

<!-- anchor: user.advanced.demo -->
### The demo workspace

**Audience:** Everyone

You want to look around before you commit. The demo is an invented space, open to anybody, without an account.

**Steps**

1. On the sign-in screen, tap **Explore the demo workspace**.
2. Read the short note, then tap **Start exploring**.
3. Use **View as** to see the same space as **The owner**, **An administrator** or **A member**.
4. Tap **Reset the demo** to bring it back as it started, or **Leave the demo**.

**Good to know**

- Everything is invented: people, bookings and bills. Nothing reaches a real workspace and nothing leaves your device.
- A banner reads **Demo** on every screen.
- Closing the app forgets the session.
- The offer only shows when the **The demo workspace** feature is on.

**See also:** [Filming mode](help:user.advanced.filming)

<!-- anchor: user.advanced.filming -->
### Filming mode

**Audience:** Owner

You must show your real space — in a video, a picture or a talk — without showing its members.

**Steps**

1. Open [Features](app:/features) and search **Filming mode**.
2. Switch it on. A banner reads **Filming mode — invented people** on every screen.
3. Film. When you are done, switch it off again.

**Good to know**

- Every name, e-mail, telephone number, address and photograph becomes an invented person, the same one everywhere. The plan, the bookings and the figures stay real.
- While it is on, identity forms refuse to save, so invented details cannot overwrite real ones.
- It cannot hide what someone typed, such as a message or a seat label. Read the screen before you film.
- For a picture that does not need to be of this space, use [the demo](help:user.advanced.demo).

**See also:** [A feature switch](help:user.features.switch)

<!-- anchor: user.advanced.platforms -->
### DesKilo on your devices

**Audience:** Everyone

You want to use DesKilo where you work. The same account and the same data follow you.

**Steps**

1. **Android:** join the closed test on Google Play.
2. iPhone and iPad: join the beta through TestFlight.
3. **Computer:** a macOS disk image or a **Windows** installer from the releases page; or just open the web app.
4. **Browser:** open the address your workspace publishes. Nothing to install.

**Good to know**

- A desk booked on a phone shows in a browser tab a moment later.
- The macOS disk image from the releases page is signed and notarised by Apple; open it as usual.
- The Windows installer is not signed: Windows SmartScreen warns about an unknown publisher; choose More info, then Run anyway.
- Reading a chair tag works in Chromium browsers on Android (HTTPS and a tap needed); the Android and iPhone apps read tags directly.
- A Google-free build, without cloud push, is built and has been submitted to F-Droid; it is not in the F-Droid store yet. On it, notifications are local and the inbox is the source of truth.
- Updates arrive through the channel you installed from: Google Play, TestFlight, the releases page, or reloading the web app.

**See also:** [Your badge](help:user.profile.settings.badge)

<!-- anchor: user.advanced.support -->
### Support details

**Audience:** Everyone

You contact support and want to send what helps them, without exposing anything private.

<p><img src="images/user-advanced-support.en.jpg" width="280"></p>

**Steps**

1. Open [Help](app:/help) and tap the support icon (**Support details**).
2. Choose **Last hour** or **Last 24 hours**.
3. Tap **Prepare preview** and read what it holds: Preview: … bytes.
4. Tap **Save**, then send the file.

**Good to know**

- Only bounded event counts and known checks are included. Identities, server addresses, credentials, business records and raw logs are excluded.
- A shared file cannot be revoked.
- If the context changed, the screen asks you to prepare a new preview.
- An operator can run `doctor --support-json` for the server side.

**See also:** [When something does not work](help:user.advanced.troubleshooting)

<!-- anchor: user.advanced.troubleshooting -->
### When something does not work

**Audience:** Everyone

Something looks wrong. Try these, in order.

**Steps**

1. Look for a message on the screen; most say what to do. "Something went wrong. Please try again." is worth one retry.
2. Check you are on the side you think: **Test space** or **Open workspace** in [Me](app:/me).
3. Check [Features](app:/features): a function missing from the menu is usually a feature that is off. Only an owner can change it.
4. Check the server under [Your own server](help:user.backend.server): **This device uses** names it.
5. Prepare [Support details](help:user.advanced.support) and send them.

**Good to know**

- What you see depends on your role: a missing screen may be a permission. Ask your owner.
- Administrators can switch on **Developer mode** under **Advanced** in [Settings](app:/settings). It adds a [Developer](app:/developer) screen where **Export trace** and **Clear trace** help support. It applies to every member of the workspace.
- You can also report a bug from the app's About section: **Report a bug / suggest a feature**.
- A guide stuck on **Waiting for the result…** means no answer arrived: check the result before retrying.

**See also:** [Support details](help:user.advanced.support)

<!-- anchor: user.advanced.glossary -->
### The app's words

**Audience:** Everyone

The words you meet most, and what they mean here.

| Word | What it means |
|---|---|
| **Workspace** (also called a space) | A place run by a community: its plan, members, rules and money. You can belong to several. |
| **Me** | Your own account: profile, messages, spaces and settings, across all your spaces. |
| **Plan** | Either the floor plan you book from, or a membership plan — see **Members & plans**. |
| **Level** | A floor or zone of the plan. A level can be reserved as a whole when the feature is on. |
| **Desk** | A bookable place. Offices and rooms group desks. |
| **Half-day** | The unit bookings and subscriptions are counted in. |
| **Validation** | A rule saying an action needs one or more confirmations before it counts. |
| **Events** | The feed of what happened, with decisions waiting for you on top. |
| **Kiosk** | A shared tablet at the door where people check in with a badge. |
| **Feature** | A function the owner switches on or off for the whole space. |
| **Role** | What a person may do in a space. Permissions are set per role. |
| **Environment** | The development side (test) or the production side (real) of a space. |
| **Twin** | The other side of a pair. |
| **Deployment** | Moving configuration from one side of a pair to the other. |
| **Assistant** | An AI tool connected to your account, acting only as you allow. |
| **Operator** | The person who runs the installation the app talks to. |

**Good to know**

- Owners can change the words a space uses under **Wording**; the app then shows the space's own.

**See also:** [Wording](help:user.workspace.settings.wording)

<!-- anchor: user.advanced.accessibility -->
### Accessibility and keyboard

**Audience:** Everyone

You want the app to suit how you work.

**Steps**

1. Pick a look under [Settings](app:/settings): **Theme**, **Language**, **Numbers & dates**.
2. For calmer screens, turn on your device's reduced-motion setting.
3. On a computer, press Escape in a wizard to step back.

**Good to know**

- The device's reduced-motion setting always wins over the **Interface animations** feature; an owner can also switch that feature off.
- Leaving a wizard with unsaved changes asks first: **Keep editing** or **Discard**.
- Controls carry text labels, so a screen reader announces them.
- On the web and on a computer, a wide window shows the menu beside the content.

**See also:** [Theme](help:user.profile.settings.theme) · [App language](help:user.profile.settings.language)

<!-- anchor: user.advanced.help -->
### Where to get more help

**Audience:** Everyone

You are stuck on one field or one screen.

**Steps**

1. Tap the **?** next to a field: the guide opens at that field.
2. Open [Help](app:/help) for the whole guide; **Contents** jumps to a chapter.
3. Tips on a screen can be dismissed with **Dismiss hint**; **Next tip** and **Previous tip** page through them, **Learn more** opens the guide.
4. To see dismissed hints again, use **Show help hints again** in your settings.

**Good to know**

- The guide works offline, in your language.
- Your administrator can answer questions about your space; Support details help when it is the app.

**See also:** [Restore the hints](help:user.profile.settings.restore-hints) · [Support details](help:user.advanced.support)
