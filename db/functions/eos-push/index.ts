// EOS · eos-push
// Called by the database (trg_notif_push, via pg_net) with { id } whenever a notification is written for a person
// who has turned on device notifications. Fetches the notification and the person's push subscriptions through
// eos_push_fetch (cron token from Vault), sends a Web Push to each device, and reports dead subscriptions back.
// Auth: verify_jwt is off; the x-eos-token header must match the Vault secret eos_cron_token.
// Keys: VAPID public key in settings.push, private key in Vault (eos_vapid_private). Nothing is in this file.
import webpush from "npm:web-push@3.6.7";

const SB_URL = Deno.env.get("SUPABASE_URL")!;
const SB_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const APP_URL = "https://dpseam.github.io/EOS-Tracker/";

async function rpc(fn: string, body: Record<string, unknown>) {
  const r = await fetch(`${SB_URL}/rest/v1/rpc/${fn}`, {
    method: "POST",
    headers: { apikey: SB_KEY, Authorization: `Bearer ${SB_KEY}`, "Content-Type": "application/json" },
    body: JSON.stringify(body),
  });
  const txt = await r.text();
  try { return JSON.parse(txt); } catch { return { ok: false, reason: txt.slice(0, 200) }; }
}

function pageFor(t: string | null, id: string | null): string {
  if (t === "tasks" && id) return `#/tasks/${id}`;
  if (t === "work_orders" && id) return `#/workorders/${id}`;
  if (t === "messages" && id) return `#/messages/${id}`;
  if (t === "requests") return `#/requests`;
  if (t === "packages" && id) return `#/packages/${id}`;
  return `#/`;
}

Deno.serve(async (req) => {
  const token = req.headers.get("x-eos-token") || "";
  let id = "";
  try { id = String((await req.json()).id || ""); } catch { /* no body */ }
  if (!id) return new Response(JSON.stringify({ ok: false, reason: "no_id" }), { status: 400 });
  const n = await rpc("eos_push_fetch", { p_token: token, p_id: id });
  if (!n.ok) return new Response(JSON.stringify(n), { status: n.reason === "bad_token" ? 401 : 200 });
  if (!n.public_key || !n.private_key) return new Response(JSON.stringify({ ok: false, reason: "no_keys" }), { status: 200 });
  webpush.setVapidDetails(n.subject || "mailto:dpseam@beverlyma.gov", n.public_key, n.private_key);
  const payload = JSON.stringify({
    title: n.title, body: n.body || "", tag: `eos-${n.kind}-${n.record_id || n.person_id}`,
    url: APP_URL + pageFor(n.record_table, n.record_id), icon: APP_URL + "icon-192.png", badge: APP_URL + "icon-192.png",
  });
  const sent: string[] = [], gone: string[] = [], errors: string[] = [];
  for (const s of (n.subscriptions || [])) {
    try {
      await webpush.sendNotification({ endpoint: s.endpoint, keys: { p256dh: s.p256dh, auth: s.auth } }, payload, { TTL: 3600, urgency: "normal" });
      sent.push(s.id);
    } catch (e: any) {
      const code = e && e.statusCode;
      if (code === 404 || code === 410) gone.push(s.id); else errors.push(`${code || "?"} ${String(e && e.body || e).slice(0, 120)}`);
    }
  }
  if (sent.length || gone.length) await rpc("eos_push_result", { p_token: token, p_sent: sent, p_gone: gone });
  return new Response(JSON.stringify({ ok: true, sent: sent.length, removed: gone.length, errors }), { headers: { "Content-Type": "application/json" } });
});
