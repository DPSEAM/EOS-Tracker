// Design check:  node .claude/harness/design-check.js [--all]
// Counts the old patterns the Design Kit replaces (see .claude/design.md, section 2), app-wide and by function.
// A module that has been moved to the new system is listed in design-modules.json with its functions; if an old
// pattern shows up inside one of those functions the check prints DESIGN_FAIL and exits 1. Otherwise DESIGN_OK.
const fs = require("fs"), path = require("path");
const html = fs.readFileSync(path.resolve(__dirname, "../../index.html"), "utf8");
const i = html.lastIndexOf("\n<script>\n"), j = html.lastIndexOf("</script>");
const startLine = html.slice(0, i + 10).split("\n").length;
const lines = html.slice(i + 10, j).split("\n");
const cfgPath = path.join(__dirname, "design-modules.json");
const cfg = fs.existsSync(cfgPath) ? JSON.parse(fs.readFileSync(cfgPath, "utf8")) : { modules: {} };

// The old patterns, in plain words. Each one has a kit piece that replaces it.
const PATTERNS = [
  ["dialog",   "Browser confirm / prompt / alert box", /(?<![\w.$])(?:window\.)?(?:confirm|prompt|alert)\(/g, "a kit window, or Undo"],
  ["date",     "Plain date or time box",             /type=["']?(?:date|datetime-local|time)\b/g,             "the EOS calendar picker"],
  ["datalist", "Old type-ahead list (<datalist>)",   /<datalist/g,                                            "the type-ahead picker"],
  ["loading",  "\"Loading…\" written on its own",    /Loading(?:…|\.\.\.)/g,                                  "K.loading (thin bar, old list faded)"],
  ["button",   "Old button style (tbtn, ed-btn, bd-btn…)", /class=["'`][^"'`]*\b(?:tbtn|ed-btn|bd-btn|h4btn|mp-btn)\b/g, "K.btn / K.iconBtn"],
  ["sheet",    "Old dialog (pvSheet)",               /\bpvSheet\(/g,                                          "a kit window"],
  ["colour",   "Colour typed into a style",          /style=["'`][^"'`]*#[0-9a-fA-F]{3,8}\b/g,                "a token"],
];

// Which top-level function each line belongs to.
const owner = []; let cur = "(top level)";
const top = /^(?:async\s+)?function\s+([A-Za-z0-9_$]+)|^(?:const|let|var)\s+([A-Za-z0-9_$]+)\s*=|^(GADGETS\.[A-Za-z0-9_$]+)\s*=/;
lines.forEach((l, n) => { const m = l.match(top); if (m) cur = m[1] || m[2] || m[3]; owner[n] = cur; });

const totals = {}, byFn = {};
lines.forEach((l, n) => {
  if (/^\s*\/\//.test(l)) return;                                   // comments do not count
  for (const [id, , re] of PATTERNS) { re.lastIndex = 0; const hits = (l.match(re) || []).length; if (!hits) continue;
    totals[id] = (totals[id] || 0) + hits; const f = owner[n]; (byFn[f] ||= {})[id] = (byFn[f][id] || 0) + hits;
    (byFn[f].__lines ||= []).push(startLine + n); }
});

console.log("Old patterns left in the app (the Design Kit replaces each one):");
for (const [id, name, , kit] of PATTERNS) console.log(`  ${String(totals[id] || 0).padStart(5)}  ${name}  →  ${kit}`);

// Converted modules must be clean.
let fail = 0;
const mods = Object.entries(cfg.modules || {});
if (mods.length) console.log("\nModules:");
for (const [name, m] of mods) {
  const fns = new Set(m.functions || []), pre = m.prefixes || [];
  const mine = Object.entries(byFn).filter(([f]) => fns.has(f) || pre.some(p => f.startsWith(p)));
  const left = mine.reduce((a, [, c]) => a + PATTERNS.reduce((b, [id]) => b + (c[id] || 0), 0), 0);
  const state = m.status || "not started";
  console.log(`  ${name} (${m.task || "no task"}): ${state} — ${left} old pattern${left === 1 ? "" : "s"} in its ${fns.size + pre.length} function names/prefixes`);
  if (state === "converted" && left) { fail = 1; for (const [f, c] of mine) { const ids = PATTERNS.filter(([id]) => c[id]).map(([id]) => `${id}×${c[id]}`); if (ids.length) console.log(`      ${f}: ${ids.join(", ")} (lines ${c.__lines.slice(0, 6).join(", ")}${c.__lines.length > 6 ? "…" : ""})`); } }
}

if (process.argv.includes("--all")) {
  console.log("\nFunctions with the most old patterns:");
  Object.entries(byFn).map(([f, c]) => [f, PATTERNS.reduce((a, [id]) => a + (c[id] || 0), 0), c])
    .sort((a, b) => b[1] - a[1]).slice(0, 40)
    .forEach(([f, n, c]) => console.log(`  ${String(n).padStart(4)}  ${f}  (${PATTERNS.filter(([id]) => c[id]).map(([id]) => `${id}×${c[id]}`).join(", ")})`));
}
console.log(fail ? "\nDESIGN_FAIL — a converted module has old patterns again" : "\nDESIGN_OK");
process.exit(fail);
