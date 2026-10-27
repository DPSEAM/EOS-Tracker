// eos-ics: serves one person's private calendar feed (.ics) at  /functions/v1/eos-ics?t=<token>
// Deploy with "Verify JWT" OFF: calendar apps cannot send a login header; the long random token in the link is the secret.
import { createClient } from "npm:@supabase/supabase-js@2";
import { buildIcs } from "./ics.ts";

const APP_URL = "https://dpseam.github.io/EOS-Tracker/";
Deno.serve(async (req) => {
  const t = new URL(req.url).searchParams.get("t") || "";
  if (!/^[a-f0-9]{32,128}$/.test(t)) return new Response("Not found", { status: 404 });
  const sb = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!);
  const { data, error } = await sb.rpc("eos_ics_feed", { p_token: t });
  if (error || !data) return new Response("Not found", { status: 404 });
  return new Response(buildIcs(data, new Date(), { appUrl: APP_URL }), {
    headers: { "Content-Type": "text/calendar; charset=utf-8", "Cache-Control": "private, max-age=900", "Content-Disposition": 'inline; filename="eos.ics"' },
  });
});
