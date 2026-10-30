// eos-users: creating sign-ins from System Health › Access (v203).
//   POST {action:"create", email}  -> creates the sign-in account, links it to the person, turns access on, returns a one-time temporary password
//   POST {action:"reset",  email}  -> sets a new temporary password on an existing account
// The caller's own token is checked with eos_can('directory.manage'); the service key never leaves this function.
import { createClient } from "npm:@supabase/supabase-js@2.45.4";

const URL_ = Deno.env.get("SUPABASE_URL")!;
const ANON = Deno.env.get("SUPABASE_ANON_KEY")!;
const SERVICE = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const cors = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};
const out = (status: number, body: unknown) =>
  new Response(JSON.stringify(body), { status, headers: { ...cors, "Content-Type": "application/json" } });

function tempPassword(): string {
  const words = "Harbor Cabot Rantoul Lothrop Hale Elliott Dane Corning Ober Brimbal".split(" ");
  const b = new Uint32Array(3); crypto.getRandomValues(b);
  const sym = "!#$%&*+?";
  return `${words[b[0] % words.length]}-${100000 + (b[1] % 900000)}${sym[b[2] % sym.length]}`;
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  if (req.method !== "POST") return out(405, { error: "POST only" });
  const auth = req.headers.get("Authorization") || "";
  const asCaller = createClient(URL_, ANON, { global: { headers: { Authorization: auth } } });
  const { data: allowed, error: canErr } = await asCaller.rpc("eos_can", { p_key: "directory.manage" });
  if (canErr) return out(401, { error: "Sign in to EOS first." });
  if (!allowed) return out(403, { error: "Only someone who manages the Directory can create sign-ins." });

  let body: any; try { body = await req.json(); } catch { return out(400, { error: "Bad request" }); }
  const email = String(body.email || "").trim().toLowerCase();
  if (!/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(email)) return out(400, { error: "This person needs a valid email address first." });
  const admin = createClient(URL_, SERVICE, { auth: { persistSession: false } });

  const findUser = async () => {
    const list = await admin.auth.admin.listUsers({ perPage: 1000 });
    return list.data?.users?.find((x) => (x.email || "").toLowerCase() === email) || null;
  };

  if (body.action === "create") {
    const password = tempPassword();
    const u = await findUser();
    if (!u) {
      const { error } = await admin.auth.admin.createUser({ email, password, email_confirm: true });
      if (error && !/already/i.test(error.message)) return out(400, { error: error.message });
      if (error) { const u2 = await findUser(); if (u2) await admin.auth.admin.updateUserById(u2.id, { password }); }
    } else {
      await admin.auth.admin.updateUserById(u.id, { password });
    }
    // turn access on; the profile comes from the job or is set on the person afterwards
    let r = await asCaller.rpc("eos_set_access", { p_email: email, p_enabled: true });
    if (r.error && /eos_set_access|p_level|schema cache/i.test(r.error.message)) {
      r = await asCaller.rpc("eos_set_access", { p_email: email, p_level: null, p_enabled: true });   // before db/022
    }
    if (r.error) return out(400, { error: r.error.message });
    return out(200, { ok: true, email, temp_password: password, access: r.data });
  }

  if (body.action === "reset") {
    const u = await findUser();
    if (!u) return out(404, { error: "This person has no EOS account yet." });
    const password = tempPassword();
    const { error } = await admin.auth.admin.updateUserById(u.id, { password });
    if (error) return out(400, { error: error.message });
    return out(200, { ok: true, email, temp_password: password });
  }
  return out(400, { error: "Unknown action" });
});
