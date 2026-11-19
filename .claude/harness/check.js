// Syntax check for the app's main script block:  node .claude/harness/check.js   → prints SYNTAX_OK or the error.
const fs = require("fs"), path = require("path"), os = require("os"), { execFileSync } = require("child_process");
const t = fs.readFileSync(path.resolve(__dirname, "../../index.html"), "utf8"), i = t.lastIndexOf("\n<script>\n"), j = t.lastIndexOf("</script>");
const f = path.join(fs.mkdtempSync(path.join(os.tmpdir(), "eos-")), "main.js"); fs.writeFileSync(f, t.slice(i + 10, j));
try { execFileSync(process.execPath, ["--check", f], { stdio: "pipe" }); console.log("SYNTAX_OK"); } catch (e) { console.log(String(e.stderr || e.message)); process.exit(1); }
