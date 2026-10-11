# The welcome page

`web/welcome/` is DesKilo's home page: what the app is, why a community
would choose it, and how to start — on the reference server or on a server
of one's own (#2390). It is published with the web app at
<https://fdittgen-png.github.io/deskilo/welcome/> and linked from the README.

## What is in the folder

| File | What it holds |
|---|---|
| `index.html` | The page, with its English text. Every translatable element carries `data-i18n` (text), `data-i18n-html`, `data-i18n-alt` or `data-i18n-aria`. |
| `i18n.js` | French, German, Spanish and Italian, plus the few strings the script writes itself (`en`). |
| `welcome.css` | Layout, light and dark themes, animations. Everything moves less under `prefers-reduced-motion`. |
| `welcome.js` | Language choice (`?lang=`, then the visitor's last choice, then the browser), theme toggle, reveal-on-scroll, the hero and tour screens, the floor plan you can book on, and the guide links: `.guide-link` opens the user guide and `.setup-guide-link` the setup guide in the page's language. |
| `img/` | Screenshots per language (`<shot>.<lang>.webp`), the floor-plan photo, the icons and the share image `og.jpg`. |

The page loads nothing from another site: no fonts, no analytics, no
CDN. Its Content-Security-Policy allows only its own files, so an inline
`<script>`, `style="…"` or `onclick="…"` would be blocked in production.
`test/lint/welcome_page_test.dart` refuses all three, and checks that every
key is translated into every language and every screenshot exists in all
five.

## Changing the text

1. Edit the English in `index.html`. A new element gets a new key.
2. Add the key to the `fr`, `de`, `es` and `it` blocks of `i18n.js`.
3. Run `flutter test test/lint/welcome_page_test.dart`.

Every claim must be true of master. Before writing that the app does
something, find the screen or the ARB string that does it.

## Keeping the promises honest

The page says only what the guide documents (#2400):

- **Invoicing** names its scope (France and Germany; reverse charge, export and exempt cases with the accountant)
  and links `guide/<lang>.html#user.invoicing.scope`. When that scope changes, change both together.
- **Messages**: only the people in a conversation can open it in the app; they are not end-to-end encrypted.
- **Accounts**: one account per server; spaces on other servers ask for a sign-in there.
- **Comparison**: ways of working (provider-run service, spreadsheet + chat), never named or unnamed products' features.
- **Hosting**: the same dates as `q1.a` and `h1.p` everywhere.

A link with `class="guide-link"` or `"setup-guide-link"` and a `data-anchor` follows the reader's language and
keeps the anchor. The demo buttons open `#/auth?demo=1`. The pause buttons (`.motion-btn`) stop everything that
moves on its own and remember it (`deskilo.welcome.still`).

## Changing the screenshots

The screenshots are the user and setup guides' captures of the demo
workspace *Atelier du Marché*, in which every person and figure is
invented. After the guide screenshots are regenerated, run:

```
tool/welcome_media.sh
```

It converts the newest capture of each shot, in each language, to WebP
(`cwebp` is required). To show another screen, add its guide name to the
list in the script and a `data-shot` image to the page; the lint test
keeps the two lists equal. A user-guide shot drops its `user-` prefix on
the page (`user-reserve-hub` becomes `reserve-hub`); a setup-guide shot
keeps its `setup-` prefix (`setup-before-template`). A screen the guides
do not photograph yet is added to the guide first, so the page never
shows a capture that only it has.

## Publishing

The folder ships inside the web build, so the next dispatch of
`web.yml -f deploy=true` publishes it. Merging alone publishes nothing.

## Hosting it somewhere else

Copy `web/welcome/` to any static web server as it is. The links to the
app, the guides, the setup questionnaire and GitHub are absolute, so they
keep working from another host. Change two things on the copy:

- `<link rel="canonical">` and the `og:url` / `og:image` addresses in
  `index.html`, to the new address;
- the Content-Security-Policy, only if that server adds its own headers.
