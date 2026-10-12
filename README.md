# DesKilo site — Node.js package for GoDaddy

The welcome page, the five-language user guide, the setup guide, the setup
questionnaire, the evaluation page, the privacy page and the API docs, served by
a dependency-free Node.js server (`server.js`). `public/` is committed, so the
host needs no build step and `npm install` downloads nothing.

| URL | What |
|---|---|
| `/` | redirects to `/welcome/` (the advertising page) |
| `/guide/en.html` (`fr` `de` `es` `it`) | the user guide |
| `/guide/setup-en.html` (…) | the setup guide |
| `/setup.html` | the setup questionnaire |
| `/product.html`, `/privacy.html`, `/api/` | evaluation planner, privacy, API docs |
| `/healthz` | `ok` — for a monitor |

The **app itself** is not in this package: the "Open DesKilo" / "Sign in" links
point to the Flutter web app (`APP_URL`, default the GitHub Pages one).

## Deploy on GoDaddy (cPanel → Setup Node.js App)

1. Repository `fdittgen-png/deskilo`, branch `hosting/godaddy` (this branch).
2. Application root: the folder the deploy tool clones into · Startup file: `server.js`
   · Node 18 or newer · Application URL: your domain.
3. Run NPM Install (it is a no-op), then Restart. Open the domain.

Re-deploy after a push: pull in the deploy tool, then Restart.

## Refresh the content (when master changed)

```sh
git clone https://github.com/fdittgen-png/deskilo ../deskilo       # or update it
SITE_URL=https://www.your-domain.tld node build/build-site.mjs --src ../deskilo
git add -A && git commit -m "site: refresh from master" && git push
```

`SITE_URL` makes the absolute links (share previews, cross-links) point at your
domain; `APP_URL` moves the "open the app" links if you host the Flutter build
elsewhere. The build fails if any relative link or image does not resolve.
`public/BUILD.txt` records which master commit the site was built from.

`npm run build` is deliberately a no-op (the host runs it on deploy and `public/` is already built); the real rebuild is `npm run refresh`.

Local check: `PORT=4000 npm start`, then open `http://localhost:4000`.
