# DesKilo site — Node.js package for GoDaddy

The DesKilo **welcome page as the landing page** (`/` goes to `/welcome/#top`), the **web
app under `/app/`**, and the five-language user guide, the setup guide, the setup
questionnaire, the evaluation page, the privacy page and the API docs beside them — served by a dependency-free Node.js server
(`server.js`). `public/` is committed, so the host needs no build step and
`npm install` downloads nothing.

| URL | What |
|---|---|
| `/` | redirects to `/welcome/#top` — the landing page never opens the app directly |
| `/welcome/` | the advertising page; its demo and sign-in buttons open the app |
| `/app/` | the web app (any path under it the app routes, e.g. `/app/money`, opens it too) |
| `/guide/en.html` (`fr` `de` `es` `it`) | the user guide |
| `/guide/setup-en.html` (…) | the setup guide |
| `/setup.html` | the setup questionnaire |
| `/product.html`, `/privacy.html`, `/api/` | evaluation planner, privacy, API docs |
| `/healthz` | `ok` — for a monitor |

## Updating the package (CI)

Run **Publish · GoDaddy site package** (Actions tab, or
`gh workflow run godaddy-site.yml`). It builds the web app (base href `/app/`) from `master` (or the ref you
give), assembles `public/`, commits it to this branch and attaches
`deskilo-site.zip` to the rolling release `godaddy-site`. Nothing else is needed.

`public/BUILD.txt` records which master commit the package was built from and when.

## Deploy on GoDaddy

**From this branch** (cPanel → Setup Node.js App): repository `fdittgen-png/deskilo`,
branch `hosting/godaddy`, startup file `server.js`, Node 18 or newer. Run NPM Install
(a no-op), then Restart. To update: pull in the deploy tool, then Restart.

**From the zip**: download `deskilo-site.zip` from the `godaddy-site` release, unzip it
into the application root (it holds `server.js`, `package.json` and `public/`), set the
startup file to `server.js`, Restart.

`npm run build` is deliberately a no-op (the host runs it on deploy and `public/` is
already built).

## Before the app works on the domain

The app signs in through Supabase. The domain has to be allowed there: **Authentication
→ URL configuration** → add `https://www.deskilo.org/**` (and `https://deskilo.org/**`) to
the redirect URLs, on every project the app should reach; and, for Google sign-in, add the
origin in the Google OAuth client. Until then, sign-in, password reset and the invitation
links may refuse the new domain.

## By hand

```sh
# pages only, from a checkout of the repository
SITE_URL=https://www.deskilo.org node build/build-site.mjs --src ../deskilo
# pages and the web app, from `flutter build web --base-href /app/`
SITE_URL=https://www.deskilo.org node build/build-site.mjs --web ../deskilo/build/web
PORT=4000 npm start        # then open http://localhost:4000 (the landing page) and /app/
```

`SITE_URL` makes the absolute links (share previews, cross-links) point at this domain.
The build fails if a relative link or image does not resolve.

This branch is **protected against deletion** and must be kept: GoDaddy deploys from it.
