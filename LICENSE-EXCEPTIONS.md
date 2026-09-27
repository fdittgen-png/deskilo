# Additional terms, permissions and the commercial licence

DesKilo is distributed under the **GNU Affero General Public License,
version 3 or later** (see [`LICENSE`](LICENSE)), © 2026 Florian DITTGEN.
This file is part of the licence. It adds one **permission** (section 1,
removable by any recipient who prefers the bare AGPL), one
**requirement** that you credit the author (section 5, an additional
term under AGPL §7(b) that travels with every copy), and points at the
licence you can buy.

## 1. The app-store exception

> As an additional permission under section 7 of the GNU Affero General
> Public License version 3, the copyright holder grants you permission
> to convey the Program through Apple's App Store, TestFlight, Google
> Play, Microsoft Store and comparable application distribution
> channels, and to accept the terms those channels impose on their
> users, notwithstanding any term of those channels that would
> otherwise conflict with sections 6, 10 or 12 of this Licence —
> including restrictions on the number of devices on which a user may
> install the Program.

**Why this exists.** The GPL family forbids imposing further
restrictions on the recipient; Apple's terms limit how many devices a
buyer may install on. That conflict is what removed VLC from the App
Store in 2011. DesKilo ships TestFlight builds, so without this
permission the iOS leg could not exist. The exception is narrow on
purpose: it permits distribution through such a channel and nothing
else. It does not weaken §13, and it does not let anyone withhold source.

## 2. What the AGPL already gives you, free

If you are an **association, a collective, a public body, a school or an
individual**, and equally if you are a company willing to honour the
AGPL, you need nothing from this file and nothing from us. Run it,
modify it, host it, charge your members for the space you run with it.
Two obligations come with it. §13: **if you modify DesKilo and let
people use it over a network, those people must be able to get your
modified source.** Publishing a link in the app is enough. And
section 5 below: **keep the credit to the author.**

Running the app unmodified triggers no obligation at all.

## 3. The commercial licence

If you are a **for-profit company** and you do not want to publish your
modifications, buy an exception:
[`COMMERCIAL-LICENCE.md`](COMMERCIAL-LICENCE.md).

## 4. The name is not in the licence

"DesKilo" and the DesKilo logo are trademarks of Florian DITTGEN. The
AGPL gives you the code, never the name — see
[`TRADEMARK.md`](TRADEMARK.md). A fork is welcome; it needs its own name.

## 5. Credit the author (additional term, AGPL §7(b))

> As an additional term under section 7(b) of the GNU Affero General
> Public License version 3, anyone who conveys the Program, a modified
> version of it, or a work based on it, in source or object form, must
> preserve the author attribution
> **"Based on DesKilo by Florian DITTGEN — https://github.com/fdittgen-png/deskilo"**:
>
> - in the source, by keeping every copyright notice and this file; and
> - in the Appropriate Legal Notices of any interactive user interface
>   (for DesKilo, the About section of Settings), where it must remain
>   visible to users in a form no less prominent than the program's own
>   legal notices.
>
> Removing or obscuring this attribution is not permitted. This term
> does not require use of the DesKilo name or logo, which remain governed
> by [`TRADEMARK.md`](TRADEMARK.md).

**Why this exists.** The AGPL already obliges every recipient to keep
the copyright notices (§4, §5). This term makes the credit explicit and
visible in the running software, which §7(b) allows a licensor to
require. Earlier releases distributed under 0BSD (before ADR 0031) are
not affected by this file; everything released under the AGPL is.

