# WhatsApp message mirror — the owner's one-time checklist (0106)

Members who shared a WhatsApp number can opt in (Settings → *Receive
messages on WhatsApp*) to get their DesKilo messages mirrored to
WhatsApp. The server side ships DISABLED: the `send-whatsapp` edge
function no-ops until its secrets exist, so everything works without
this checklist — WhatsApp is a mirror, never the source of truth.

## 1. WhatsApp Business Cloud API

1. https://developers.facebook.com → create a (business) app → add the
   **WhatsApp** product. Meta provisions a test number; for production
   register your own business phone number.
2. Note the **Phone number ID** (WhatsApp → API Setup) and create a
   **permanent access token** (System user with `whatsapp_business_messaging`).

## 2. Secrets + deploy

```
supabase secrets set WHATSAPP_TOKEN="<permanent token>"
supabase secrets set WHATSAPP_PHONE_ID="<phone number id>"
supabase functions deploy send-whatsapp
```

## 3. The 24-hour window

WhatsApp only delivers free-form business messages inside the 24h
service window (the member messaged your number in the last 24h).
Outside it the API rejects and the mirror is skipped — the in-app
message and the push still deliver. To open the window, members send
one WhatsApp message to the workspace number (or approve a Meta
message template and extend the function to use it).

## 4. Verify

Toggle the switch on a member with a shared number, send them a
message, and check the function logs:
`supabase functions logs send-whatsapp`.
