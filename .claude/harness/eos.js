// EOS test harness: opens the real index.html signed in as a made-up person, with every database call answered from
// stand-in data you pass in (nothing reaches the live database, and nothing real is stored in this folder).
//
//   const eos = require("/home/user/EOS-Tracker/.claude/harness/eos.js");   // or a relative path from your script
//   const { page, close } = await eos.start({ width: 1400, height: 900, theme: "light",
//       fixtures: { "v_budget_lines": rows, "rpc:eos_budget_load": { loaded: 1 } }, grants: ["see.budget"] });
//   await page.to("budget");                 // go to a page by its route name
//   await page.shot("/path/overview.png");   // screenshot (full page: page.shot(path, true))
//   page.errors                              // uncaught page errors so far;  page.asked  = every endpoint the app asked for
//   await close();
//
// fixtures: keys are view names ("v_tasks") or "rpc:<function>"; a value is the JSON to answer with, or a function
// (url, request) => JSON. Anything not listed answers [] (views) or {} (rpc). Put real rows you pulled for a test in your
// scratchpad, never in the repo.
const { chromium } = require("playwright"); const http = require("http"), fs = require("fs"), path = require("path");
const ROOT = path.resolve(__dirname, "../..");
const TYPES = { ".html": "text/html; charset=utf-8", ".js": "text/javascript", ".css": "text/css", ".json": "application/json", ".png": "image/png", ".svg": "image/svg+xml", ".jpg": "image/jpeg", ".webp": "image/webp", ".ico": "image/x-icon" };
const ALL_GRANTS = ["see.budget","see.people","see.meetings","see.documents","see.pavement","see.dashboards","see.system","see.review","events.edit","events.create","tasks.edit","tasks.create","work_orders.edit","work_orders.create","projects.edit","projects.create","documents.edit","documents.upload","notes.add","meetings.edit","directory.manage","roles.manage","kb.edit","dashboards.edit","assets.edit","forms.submit","commitments.edit","invoices.approve","templates.use"];
const ME = { id: "00000000-0000-4000-8000-000000000001", full_name: "Test Person", first_name: "Test", email_address: "tester@example.gov", title: "Tester", department: "Test Division", person_type: "employee", tier_level: 6, tier: "executive", own_level: 6, login_enabled: true, role_id: null, role_title: "Tester", photo_path: null, background_path: null, home_layout: {}, profile_id: "p1", profile_name: "Executive", profile_source: "person", extra_grants: [], preview_set_id: null, preview_name: null, can_preview: true, profiles: [], map_state: null };
const SETTINGS = [{ key: "session_policy", value: { warn_seconds: 60, idle_minutes_admin: 120, idle_minutes_standard: 480 } }, { key: "layouts", value: {} },
  { key: "tiers", value: [{ key: "staff", label: "Staff" }, { key: "management", label: "Management" }, { key: "executive", label: "Executive" }, { key: "partner", label: "Partner" }] }];
function serve() { return new Promise(res => { const s = http.createServer((q, r) => { let p = decodeURIComponent(q.url.split("?")[0]); if (p === "/") p = "/index.html";
    const f = path.join(ROOT, p); if (!f.startsWith(ROOT) || !fs.existsSync(f) || fs.statSync(f).isDirectory()) { r.writeHead(404); return r.end(); }
    r.writeHead(200, { "content-type": TYPES[path.extname(f)] || "application/octet-stream", "cache-control": "no-store" }); fs.createReadStream(f).pipe(r); });
  s.listen(0, "127.0.0.1", () => res(s)); }); }
async function start(o = {}) {
  const srv = await serve(), base = "http://127.0.0.1:" + srv.address().port;
  const browser = await chromium.launch();
  const ctx = await browser.newContext({ viewport: { width: o.width || 1400, height: o.height || 900 }, colorScheme: o.theme === "dark" ? "dark" : "light", deviceScaleFactor: o.scale || 1 });
  const me = { ...ME, grants: o.grants || ALL_GRANTS, ...(o.me || {}) };
  const fx = { v_me: [me], v_features: [{ features: {} }], v_settings: SETTINGS, ...(o.fixtures || {}) };
  await ctx.addInitScript(theme => { localStorage.setItem("eos_auth", JSON.stringify({ access_token: "x.eyJhYWwiOiJhYWwxIn0.x", refresh_token: "r", expires_at: Date.now() + 864e5, user: { id: "u1", email: "tester@example.gov" } }));
    localStorage.setItem("eos_active", String(Date.now())); localStorage.setItem("eos_whatsnew_seen", "v99999"); localStorage.setItem("eos_theme", theme); }, o.theme === "dark" ? "dark" : "light");
  const asked = new Set();
  await ctx.route(/supabase\.co\//, async route => { const q = route.request(), u = new URL(q.url()), p = u.pathname;
    if (p.startsWith("/auth/v1/")) return route.fulfill({ json: { id: "u1", email: "tester@example.gov", factors: [] } });
    if (p.startsWith("/storage/") || p.startsWith("/functions/")) return route.fulfill({ status: 404, body: "" });
    const name = p.replace(/^\/rest\/v1\//, "").replace(/^rpc\//, "rpc:"); asked.add(name);
    let body = fx[name]; if (typeof body === "function") body = await body(u, q); if (body === undefined) body = name.startsWith("rpc:") ? {} : [];
    const n = Array.isArray(body) ? body.length : 1;
    return route.fulfill({ status: 200, contentType: "application/json", headers: { "content-range": `0-${Math.max(0, n - 1)}/${n}` }, body: JSON.stringify(body) }); });
  if (!o.network) await ctx.route(/arcgis|openstreetmap|tile\.|api\.weather\.gov|open-meteo|nws\.noaa|mbta|marinetraffic|ndbc/i, r => r.abort());   // outside services: off unless asked for
  const page = await ctx.newPage(); page.errors = []; page.asked = asked; page.on("pageerror", e => page.errors.push(e.message));
  await page.goto(base + "/index.html#/" + (o.page || "home")); await page.waitForTimeout(o.wait || 3500);
  page.to = async (pg, ms) => { await page.evaluate(x => { location.hash = "#/" + x; }, pg); await page.waitForTimeout(ms || 1500); };
  page.shot = (file, full) => page.screenshot({ path: file, fullPage: !!full });
  page.theme = async t => { await page.evaluate(t => { localStorage.setItem("eos_theme", t); document.documentElement.dataset.theme = t; if (typeof render === "function") render(); }, t); await page.waitForTimeout(400); };
  return { page, browser, base, close: async () => { await browser.close(); srv.close(); } };
}
module.exports = { start, ALL_GRANTS };
// run directly for a quick look:  node .claude/harness/eos.js budget /path/out.png [dark] [390]
if (require.main === module) (async () => { const [pg = "home", out, theme, w] = process.argv.slice(2);
  const { page, close } = await start({ page: pg, theme, width: +w || 1400 }); if (out) await page.shot(out, true);
  console.log("page:", await page.evaluate(() => document.body.dataset.page || location.hash)); console.log("errors:", JSON.stringify(page.errors.slice(0, 5))); console.log("asked:", [...page.asked].join(" ")); await close(); })();
