// SPDX-License-Identifier: 0BSD
//
// #1553 — the headers a browser needs before it will hand us an answer.
//
// Two of these functions are called from the app with
// `supabase.functions.invoke`, which on the web is an ordinary
// cross-origin `fetch`. The browser sends `OPTIONS` first and refuses to
// read the reply unless both the preflight and the POST carry these
// headers. `badge-signin` had them; the two that take money did not, so
// on the web the call failed before the server ever ran — and the
// failure looks like a network error rather than a refusal, which is why
// it could sit there.
//
// `*` for the origin because a DesKilo instance is served from wherever
// its owner puts it — GitHub Pages, a custom domain, a kiosk — and there
// is no list to keep. Nothing here is a credential: both functions read
// the caller's JWT from the Authorization header, which is exactly what
// `Access-Control-Allow-Headers` has to name for the browser to send it.
export const CORS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

/// The preflight answer, and nothing else: no body, no work, no auth.
export const preflight = () => new Response("ok", { headers: CORS });
