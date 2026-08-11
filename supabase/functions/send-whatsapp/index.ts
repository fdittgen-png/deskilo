// SPDX-License-Identifier: 0BSD
//
// WhatsApp delivery of member notes (field request): the 0106 trigger
// POSTs {note_id}; this function loads the note ITSELF with the service
// role and computes the recipients — the caller is never trusted with
// recipients or content. Each opted-in recipient (profiles.whatsapp set
// AND profiles.whatsapp_notes true) gets the message as the in-app
// messenger reads it: reference tokens replaced by their labels, each
// reference as a tappable web link, and a final link that opens the app
// directly on the conversation.
//
// Secrets: WHATSAPP_TOKEN + WHATSAPP_PHONE_ID — a WhatsApp Business
// Cloud API access token and phone-number id. Absent -> the function
// no-ops politely so the trigger never fails. NOTE: WhatsApp only
// delivers free-form messages inside the 24h service window; outside it
// the API rejects and the send is logged and dropped (the in-app
// message and push are the source of truth, WhatsApp is a mirror).

import { createClient } from "npm:@supabase/supabase-js@2";

const supabase = createClient(
  Deno.env.get("SUPABASE_URL")!,
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
);

// The published web app — the same Flutter app, hash routing.
const APP_URL = "https://fdittgen-png.github.io/deskilo/#";

// Mirror of lib/features/workspace/domain/member_note_refs.dart.
const REF = /\[(?:res:([A-Za-z0-9-]{4,})|space:(seat|desk|office|level):([A-Za-z0-9-]{4,}))\|([^\]]+)\]/g;

/// Body as the reader sees it (labels), plus one web link per reference.
function render(body: string, noteId: string): string {
  const links: string[] = [];
  const plain = body.replace(
    REF,
    (_m, resId: string, kind: string, spaceId: string, label: string) => {
      links.push(
        resId
          ? `↗ ${label}: ${APP_URL}/res/${resId}`
          : `↗ ${label}: ${APP_URL}/space/${kind}/${spaceId}`,
      );
      return label;
    },
  );
  const parts = [plain];
  if (links.length > 0) parts.push("", ...links);
  parts.push("", `DesKilo: ${APP_URL}/msg/${noteId}`);
  return parts.join("\n");
}

Deno.serve(async (req) => {
  const token = Deno.env.get("WHATSAPP_TOKEN");
  const phoneId = Deno.env.get("WHATSAPP_PHONE_ID");

  const payload = await req.json().catch(() => ({}));
  // The client probes BEFORE offering the opt-in switch as functional —
  // a silently dead channel reads as "not working" (field report).
  if (payload.action === "config") {
    return new Response(
      JSON.stringify({ configured: Boolean(token && phoneId) }),
      { status: 200, headers: { "Content-Type": "application/json" } },
    );
  }
  if (!token || !phoneId) {
    return new Response("whatsapp not configured", { status: 200 });
  }

  const note_id = payload.note_id;
  if (!note_id) return new Response("missing note_id", { status: 400 });

  const { data: note } = await supabase
    .from("member_notes")
    .select("id, workspace_id, from_member_id, to_member_id, body")
    .eq("id", note_id)
    .maybeSingle();
  if (!note) return new Response("unknown note", { status: 200 });

  // Recipients: the direct addressee, or — broadcast — every admin and
  // the owner except the sender.
  let memberQuery = supabase
    .from("members")
    .select("id, user_id")
    .eq("workspace_id", note.workspace_id)
    .eq("status", "active");
  memberQuery = note.to_member_id
    ? memberQuery.eq("id", note.to_member_id)
    : memberQuery.or("is_admin.eq.true,is_owner.eq.true")
        .neq("id", note.from_member_id);
  const { data: recipients } = await memberQuery;
  if (!recipients || recipients.length === 0) {
    return new Response("no recipients", { status: 200 });
  }

  const { data: senderRow } = await supabase
    .from("members")
    .select("user_id")
    .eq("id", note.from_member_id)
    .maybeSingle();
  const { data: senderProfile } = senderRow
    ? await supabase
        .from("profiles")
        .select("display_name")
        .eq("id", senderRow.user_id)
        .maybeSingle()
    : { data: null };
  const sender = senderProfile?.display_name || "DesKilo";

  const { data: profiles } = await supabase
    .from("profiles")
    .select("id, whatsapp, whatsapp_notes")
    .in("id", recipients.map((r: { user_id: string }) => r.user_id));

  const text = `\u{1F4AC} ${sender}\n${render(note.body, note.id)}`;
  let sent = 0;
  for (const p of profiles ?? []) {
    if (!p.whatsapp || !p.whatsapp_notes) continue;
    const to = String(p.whatsapp).replace(/^\+/, "");
    const res = await fetch(
      `https://graph.facebook.com/v20.0/${phoneId}/messages`,
      {
        method: "POST",
        headers: {
          Authorization: `Bearer ${token}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          messaging_product: "whatsapp",
          to,
          type: "text",
          text: { body: text, preview_url: false },
        }),
      },
    );
    if (res.ok) {
      sent += 1;
    } else {
      // Outside the 24h window / bad number: log and move on — the
      // in-app message and the push already delivered.
      console.error("whatsapp send failed", to, await res.text());
    }
  }
  return new Response(JSON.stringify({ sent }), { status: 200 });
});
