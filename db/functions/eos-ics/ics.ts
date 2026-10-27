// Builds an iCalendar (.ics) feed from the JSON returned by eos_ics_feed().
// Plain JavaScript that is also valid TypeScript, so it runs in Deno (the Edge Function) and in Node (tests).
const TZ = "America/New_York";
const pad = (n) => String(n).padStart(2, "0");
const esc = (s) => String(s == null ? "" : s).replace(/\\/g, "\\\\").replace(/;/g, "\\;").replace(/,/g, "\\,").replace(/\r?\n/g, "\\n");
function fold(line) {
  const enc = new TextEncoder(), out = []; let cur = "", bytes = 0;
  for (const ch of line) { const b = enc.encode(ch).length; if (bytes + b > 73) { out.push(cur); cur = " " + ch; bytes = 1 + b; } else { cur += ch; bytes += b; } }
  out.push(cur); return out.join("\r\n");
}
// local (New York) wall-clock parts of an instant
const fmt = new Intl.DateTimeFormat("en-US", { timeZone: TZ, hourCycle: "h23", year: "numeric", month: "2-digit", day: "2-digit", hour: "2-digit", minute: "2-digit" });
function nyParts(d) { const o = {}; for (const p of fmt.formatToParts(d)) o[p.type] = p.value; return { y: +o.year, mo: +o.month, d: +o.day, h: +o.hour, mi: +o.minute }; }
const stamp = (y, mo, d, h, mi) => `${y}${pad(mo)}${pad(d)}T${pad(h)}${pad(mi)}00`;
const dateOnly = (s) => String(s).slice(0, 10).replace(/-/g, "");
function nextDay(s) { const [y, m, d] = String(s).slice(0, 10).split("-").map(Number); const t = new Date(Date.UTC(y, m - 1, d + 1)); return `${t.getUTCFullYear()}${pad(t.getUTCMonth() + 1)}${pad(t.getUTCDate())}`; }
const STEP = { weekly: 7, biweekly: 14, "bi-weekly": 14 };
// every occurrence of one meeting between [from, to], as New York wall-clock parts (same rules as the app's calendar)
export function occurrences(m, from, to) {
  if (!m.scheduled_at) return [];
  const a = new Date(m.scheduled_at), p = nyParts(a), cad = String(m.cadence || "").toLowerCase(), out = [];
  const durMin = m.ends_at ? Math.max(15, Math.round((new Date(m.ends_at) - a) / 60000)) : 60;
  const push = (y, mo, d) => { const day = Date.UTC(y, mo - 1, d, 12); if (day >= from.getTime() - 864e5 && day <= to.getTime() + 864e5) out.push({ y: t(y, mo, d).y, mo: t(y, mo, d).mo, d: t(y, mo, d).d, h: p.h, mi: p.mi, dur: durMin }); };
  const t = (y, mo, d) => { const x = new Date(Date.UTC(y, mo - 1, d)); return { y: x.getUTCFullYear(), mo: x.getUTCMonth() + 1, d: x.getUTCDate() }; };
  if (STEP[cad]) { for (let n = -60; n < 400; n++) push(p.y, p.mo, p.d + n * STEP[cad]); }
  else if (cad === "monthly") { for (let n = -6; n < 16; n++) { const x = new Date(Date.UTC(p.y, p.mo - 1 + n, 1)); const last = new Date(Date.UTC(x.getUTCFullYear(), x.getUTCMonth() + 1, 0)).getUTCDate(); push(x.getUTCFullYear(), x.getUTCMonth() + 1, Math.min(p.d, last)); } }
  else push(p.y, p.mo, p.d);
  return out;
}
const VTZ = ["BEGIN:VTIMEZONE", "TZID:" + TZ, "BEGIN:DAYLIGHT", "TZOFFSETFROM:-0500", "TZOFFSETTO:-0400", "TZNAME:EDT", "DTSTART:19700308T020000", "RRULE:FREQ=YEARLY;BYMONTH=3;BYDAY=2SU", "END:DAYLIGHT",
  "BEGIN:STANDARD", "TZOFFSETFROM:-0400", "TZOFFSETTO:-0500", "TZNAME:EST", "DTSTART:19701101T020000", "RRULE:FREQ=YEARLY;BYMONTH=11;BYDAY=1SU", "END:STANDARD", "END:VTIMEZONE"];
export function buildIcs(feed, now, opts) {
  const app = (opts && opts.appUrl) || "", from = new Date(now.getTime() - 14 * 864e5), to = new Date(now.getTime() + 180 * 864e5), dtstamp = now.toISOString().replace(/[-:]/g, "").replace(/\.\d+/, "");
  const L = ["BEGIN:VCALENDAR", "VERSION:2.0", "PRODID:-//City of Beverly DPS//EOS//EN", "CALSCALE:GREGORIAN", "METHOD:PUBLISH", "X-WR-CALNAME:" + esc("EOS – " + (feed.name || "me")),
    "X-WR-TIMEZONE:" + TZ, "REFRESH-INTERVAL;VALUE=DURATION:PT1H", "X-PUBLISHED-TTL:PT1H", ...VTZ];
  const ev = (uid, summary, lines) => { L.push("BEGIN:VEVENT", "UID:" + uid, "DTSTAMP:" + dtstamp, "SUMMARY:" + esc(summary), ...lines, "END:VEVENT"); };
  const link = (path) => (app ? "Open in EOS: " + app + "#/" + path : "");
  const seen = new Set();
  for (const m of feed.meetings || []) {
    for (const o of occurrences(m, from, to)) {
      const st = stamp(o.y, o.mo, o.d, o.h, o.mi), key = String(m.title).toLowerCase() + "|" + st; if (seen.has(key)) continue; seen.add(key);
      const e = new Date(Date.UTC(o.y, o.mo - 1, o.d, o.h, o.mi + o.dur)), en = stamp(e.getUTCFullYear(), e.getUTCMonth() + 1, e.getUTCDate(), e.getUTCHours(), e.getUTCMinutes());
      const desc = [m.purpose, link("meetings/" + m.id)].filter(Boolean).join("\n");
      ev("m-" + m.id + "-" + st + "@eos", m.title || "Meeting", [`DTSTART;TZID=${TZ}:${st}`, `DTEND;TZID=${TZ}:${en}`, ...(m.location ? ["LOCATION:" + esc(m.location)] : []), ...(desc ? ["DESCRIPTION:" + esc(desc)] : [])]);
    }
  }
  const allDay = (uid, summary, date, desc) => ev(uid, summary, ["DTSTART;VALUE=DATE:" + dateOnly(date), "DTEND;VALUE=DATE:" + nextDay(date), "TRANSP:TRANSPARENT", ...(desc ? ["DESCRIPTION:" + esc(desc)] : [])]);
  for (const t of feed.tasks || []) {
    const d = [t.status, link("tasks/" + t.id)].filter(Boolean).join("\n"), name = `${t.ref || ""} ${t.title || ""}`.trim();
    if (t.due_date) allDay("t-" + t.id + "-due@eos", "Due: " + name, t.due_date, d);
    if (t.start_date) allDay("t-" + t.id + "-start@eos", "Planned start: " + name, t.start_date, d);
    if (t.stop_date && t.stop_date !== t.due_date) allDay("t-" + t.id + "-stop@eos", "Planned finish: " + name, t.stop_date, d);
  }
  for (const w of feed.workorders || []) {
    const d = [w.status, link("workorders/" + w.id)].filter(Boolean).join("\n");
    if (w.start_date) allDay("w-" + w.id + "-start@eos", "Work order starts: " + w.title, w.start_date, d);
    if (w.stop_date) allDay("w-" + w.id + "-stop@eos", "Work order finishes: " + w.title, w.stop_date, d);
  }
  L.push("END:VCALENDAR");
  return L.map(fold).join("\r\n") + "\r\n";
}
