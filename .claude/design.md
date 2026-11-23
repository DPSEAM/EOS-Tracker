# EOS look-and-feel standards

The written standard every visible change is checked against. It describes what `index.html` does **today** (surveyed at v469, 2026-11-19), names the one
way to keep where the app does a job several ways, and lists the rest under "Not yet consistent".

How to use it:

- **Building:** reuse the pattern named here. Use token names, never typed-in values. New work follows the
  "keep" variant even where older screens do not.
- **Checking:** a must-fix is something that breaks section 1 (Sam's decisions), breaks a "keep" rule in a new
  or changed screen, breaks on a phone or in dark, cannot be used by keyboard, or would confuse the person.
- **Old screens** listed under "Not yet consistent" are not bugs to fix on sight. They are fixed when Sam asks,
  or when that screen is being changed anyway.

---

## 1. Sam's decisions

These outrank everything else in this file. Decisions 1–5 are from 2026-11-19; decision 6 is from 2026-11-20.

| # | Decision | In practice |
|---|----------|-------------|
| 1 | **Revenue is shown in green.** | Use `--s-done` (the green the Budget page already uses for revenue: pill, row bar, numbers, tile edge, bar). Spending is never green. |
| 2 | **A chart's pop-up must not cover the chart's lines; the numbers go in a row above the plot.** | Use the read-out row `.bo-read` (`BO_READ`, hint "Point at the chart to read its numbers here.") with a crosshair line. No floating box over the plot. |
| 3 | **Every pop-up says which date its numbers are from.** | The read-out or pop-up starts with the date or period ("As of Nov 19, 2026", "Nov 2026", "FY27"), written with `fd()`. Applies to chart read-outs, map pop-ups and hover titles that carry numbers. |
| 4 | **Tables are clean and plain, with a blue box on the selected cell.** | Hairline row rules, no zebra, no fills, no glow, plain grey header. The selected cell gets an outlined box (today: `.gtb td.cell`, 1.5px `--accent`). |
| 5 | **Plain words on screen, no developer terms.** | Nothing a City employee would not say: no table/view/file names, SQL, status codes, "ingest", "API key", "token", "level 6", raw field names or raw error text. |
| 6 | **EOS looks clean, simple and modern, the way Apple's software reads** (2026-11-20: "a good clean and easy … how apple says modern software look"). | See "What decision 6 means" below. |

### What decision 6 means

Each line can be checked on a screenshot at 1400 and 390 wide, light and dark.

1. **One thing leads.** Every screen and dialog has one title and at most one accent-filled button. The eye
   lands on the title, then the content; tools are quieter than content.
2. **Grouped, not scattered.** Related settings or facts sit together in one white rounded group with a short
   plain heading (the "Settings list" pattern in section 3). No loose controls on the canvas.
3. **Room to breathe.** At least 24px between groups, 16px inside a group's edges, rows at least 44px high.
   Text never touches a border.
4. **Nothing wraps awkwardly.** A label is one line. A value that is too long is cut with "…" and shown in full
   on hover. A control never drops under its label by accident: it either fits beside it or the row is built
   stacked (label above, control below) on purpose.
5. **Few sizes, few weights.** No more than three text sizes on a screen (title, body, caption). Hierarchy
   comes from size and weight, not from colour, boxes or capitals.
6. **Restrained colour.** The accent is for the main action, links and the "on" state. Status colours are for
   status only. No gradients, glows, coloured headers or decorative icons. Surfaces are `--bg`, `--panel` and
   `--panel-2`; separation is by space, a hairline (`--line-2`) or a soft shadow (`--shadow`), never a heavy border.
7. **Plain, short words.** A label of one to three words; where it needs explaining, one quiet line under it.
8. **Changes apply at once.** A setting takes effect when it is changed; there is no Save button for a
   switch or a choice. What cannot be undone asks first.
9. **Calm movement.** Things appear in place or fade (0.12–0.2s); nothing bounces or slides across the screen,
   and `prefers-reduced-motion` turns movement off.

### Where the app does not yet follow them

1. **Revenue green**
   - Budget "Revenue collected" / "Funding received" tile: the bar is teal (`.bo-thin i.r` uses `--bo-1`); its top edge is green.
   - Project money: "revenue to date", payments received, the recycling Revenue column and funding-source tables are plain ink.
   - Project spending (`pdBurn`, `.pd-stack`) uses `--accent`, so a person who picks the green accent sees spending in green.
2. **Read-out above the plot** — only the two Budget charts (`boTSVG`, `boCatBars`) do this. Not yet:
   - Asset charts (condition, Gantt, failures, centerline, histogram, risk matrix): floating `#cpTip` follows the cursor over the plot.
   - Budget hero bar: floating `.bo-tip`. Admin email-activity bars: bubble inside the plot. Gantt drag: `.g-tip`.
   - Forestry, project and package charts and the main Gantt: browser hover titles. Pavement charts: no read-out (values are printed on the chart).
3. **Date in every pop-up** — missing on: Forestry bar and stack charts, Budget meter and thin-bar titles, project spent/open bars and burn chart titles, asset histogram and risk matrix, the Ask AI usage ring ("this month" without the month), and the Forestry, GIS feature, nearby-records map pop-ups. Forestry months and the Forestry history pop-up show a raw date ("2026-11").
4. **Plain tables, box on the selected cell**
   - The selected-cell box exists only in the GIS Records table. Every other table selects a whole row (accent tint plus a 4px bar).
   - The box uses `--accent`: it is blue by default but follows the person's accent colour (question for Sam below).
   - Every `.tbl`, `.bl-t` and `.fg-tbl` row gets an accent fill and a glow on hover (lines 5135–5136).
   - Budget tables: tinted uppercase header and footer with accent rules. Zebra rows in three Gantt/timeline charts. Filled headers on admin, GIS-import and some other tables. Full gridlines on tables in chat answers.
5. **Plain words** — on everyday screens:
   - "ingest" (home, task and work order updates, people, organizations, events; the Tasks empty state reads "The hourly Gmail ingest hasn't filed any tasks").
   - The "Some data didn't load" banner shows "404 Not Found · v_tasks" and, for some errors, SQL to run.
   - "Run db/0xx_….sql once in the Supabase SQL editor" on Requests, Work packages, Messages, Budget, Calendar link and Favorites; "Needs the v211 database update" (9 places).
   - "API key", "Tokens", "level 6", "tier", raw GIS field names and "#OBJECTID", raw lowercase status values in project money.
   - Raw error text wherever `edError()` has no plain wording for it (most save failures) and in about 38 red error boxes.
   - Administration pages carry more (file names, "Edge Functions", "bucket"); those are read by administrators only.
6. **Clean and modern** — the account menu under your initials holds 14 different things in one 250px column
   and several rows wrap ("Work spaces", "View as", "Device notifications"); it is being replaced by the My
   profile page (T-27-03522). The other items in "Not yet consistent" (section 8) are the rest of the gap.

---

## 2. Tokens

All in `index.html`. Use the names; never type a size, radius, shadow or colour.

**Look and theme.** `html[data-style="mac"]` is the only look in use (graphite, civic and classic rules remain in
the file but are never switched on). `html[data-theme]` is `light` or `dark`; the person picks Light / Dark /
Auto in the account menu (default Light). `html[data-accent]` is the person's accent, default `blue`; 19 named
accents plus a custom colour.

### Colour (mac look)

| Token | Light | Dark | Used for |
|-------|-------|------|----------|
| `--bg` | `#F5F5F7` | `#1C1C1E` | Page canvas |
| `--panel` | `#FFFFFF` | `#2C2C2E` | Cards, tables, dialogs, fields |
| `--panel-2` | `#F2F2F7` | `#3A3A3C` | Quiet fill: search box, segmented track, hover |
| `--line` / `--line-2` | `#D2D2D7` / `#E8E8ED` | `#3A3A3C` / `#323234` | Borders / hairlines between rows |
| `--ink` | `#1D1D1F` | `#F5F5F7` | Main text |
| `--ink-2` | `#424245` | `#D1D1D6` | Secondary text |
| `--ink-3` | `#6F6F73` | `#98989D` | Labels, captions, table headers |
| `--ink-4` | `#8D8D91` | `#76767A` | Disabled, faint marks only |
| `--accent` | `#0071E3` (blue) | `#0A84FF` | Links, primary button, selection. Changes with the person's accent |
| `--accent-soft` / `--accent-line` / `--row-sel` | accent at 12% / 35% / 12% | 12% / 35% / 20% | Tints derived from the accent |
| `--accent-ink` | `#FFFFFF` | `#FFFFFF` (dark text on light accents) | Text on an accent fill |
| `--s-pending` (+`-bg`) | `#6E6E73` | `#98989D` | Status: not started |
| `--s-progress` (+`-bg`) | `#0066CC` | `#409CFF` | Status: in progress |
| `--s-blocked` (+`-bg`) | `#D70015` | `#FF6961` | Status: blocked, overdue, errors |
| `--s-done` (+`-bg`) | `#248A3D` | `#30D158` | Status: done. **Revenue.** |
| `--s-cancel` (+`-bg`) | `#8E8E93` | `#8E8E93` | Status: canceled |
| `--warn` (+`-bg`) | `#C93400` | `#FF9F0A` | Warnings, waiting, on hold |
| `--p-urgent` `--p-high` `--p-medium` `--p-low` | `#FF3B30` `#FF9500` `#FFCC00` `#C7C7CC` | `#FF453A` `#FF9F0A` `#FFD60A` `#636366` | Priority dot |
| `--row-hover` | `#F5F5F7` | white at 5% | Row hover |
| `--glass`, `--hair`, `--bar-bg` | translucent | translucent | Frosted header bar, account menu, record header |

Fixed in every theme: `--white`, `--black`, `--danger #C0392B` (`--bad` is the same), `--danger-strong #B42318`,
`--success #2E9D6B`, `--success-strong #1D6B43`, `--warning #F59E0B`, `--warning-strong #B45309`,
`--warning-ink #7A5600`, `--orange #E07B00`, `--surface-inverse #1D2B3A` (toasts, rail tooltips),
`--brand-navy #061321`.

Chart colours: Budget `--bo-1 #1F6F78`, `--bo-2 #5EA7AE`, `--bo-track`; Asset `--cp-1` to `--cp-4`, `--cp-wo`
(dark values at line 590). A chart or map colour that *is* the data (condition bands, layer symbols) may be a
typed value; everything else uses a token.

### Type

- Family: `--sans` (system font: SF Pro / Segoe UI), headings `--display`, numbers and ids `--mono`. Body is
  `--fs-base` 14px at line height 1.5.
- Sizes: `--fs-2xs` 11 · `--fs-xs` 12 · `--fs-sm` 13 · `--fs-base` 14 · `--fs-md` 15 · `--fs-lg` 17 ·
  `--fs-xl` 20 · `--fs-2xl` 22 · `--fs-3xl` 27 · `--fs-4xl` 32. Nothing smaller than 11px.
  In practice: `--fs-sm` is the working size (tables, buttons, fields); `--fs-xs` captions; `--fs-lg` page and
  dialog titles; `--fs-label` (11px, uppercase, `--ls-label`) small labels.
- Weights: `--fw-regular` 400 · `--fw-medium` 500 · `--fw-semibold` 600 · `--fw-bold` 700 · `--fw-heavy` 800.
- Line height `--lh-none/tight/snug/normal/relaxed` (1 / 1.2 / 1.3 / 1.5 / 1.6); tracking `--ls-display` to `--ls-label`.
- Text roles `--text-display`, `-h1`, `-h2`, `-h3`, `-title`, `-body`, `-body-sm`, `-caption`, `-label`, `-micro`
  are defined (use as `font:var(--text-title)`) — see "Not yet consistent".
- Numbers in columns: class `.num` (tabular figures).

### Shape and depth

- Radius: `--radius-2xs` 2 · `-xs` 4 · `-sm` 6 · `-md` 8 · `-lg` 10 · `-xl` 12 · `-2xl` 16 · `-3xl` 20 ·
  `-pill` · `-round`. Controls (buttons, fields, menu items) `--radius-md`; cards and table sheets `--r-lg`
  (14px); dialogs `--radius-2xl`; status pills `--radius-pill`.
- Shadow: `--shadow` (cards, tables) · `--shadow-1` raised button · `--shadow-2` · `--shadow-3` menus, popovers,
  toasts · `--shadow-4` dialogs and floating windows. Focus: `--focus-ring` (3px `--accent-soft`), `--focus-ring-sm`.
- Spacing: there is no spacing token. Use 4, 6, 8, 10, 12, 14, 16, 20 or 24px. Usual values: gap 6 or 8
  between controls; table cell 10px 12px; card header 12px 16px; tile 14px 16px; dialog 18px 20px.

---

## 3. Patterns

### The page bar
One bar, 48px, on every page (`html.bar-merged .rail`; the page's own tools in `#bar` sit inside it). Left to
right: seal and **EOS** menu · where you are (page title `h1`, or section tabs `.hd-tabs` with counts) ·
search this page (`.hd-s`) · Filters (`.hd-fbtn` / `.hd-fsplit`, count badge) · view switcher (`.hd-view`) ·
round accent **+** (`#newMenuBtn`) · **⋯** more (`.hd-mbtn`) · notifications and your initials. Every control
in the bar is 32px high. The bar never wraps: as the window narrows it folds in a fixed order (`hd-l1` to
`hd-l4`). No sentences in the bar. One accent button per page.

### Buttons
| Job | Class | Looks like |
|-----|-------|-----------|
| Ordinary action | `.tbtn` | `--panel` fill, 1px `--line`, `--radius-md`, 6px 12px, `--fs-sm` medium, `--shadow-1`; hover `--panel-2` |
| Main action (one per bar, dialog or record header) | `.tbtn.new`; `.btn-update` in a record header or dialog footer | `--accent` fill, `--accent-ink` text, semibold |
| Switched on | `.tbtn.on` | Same as main action |
| Action in a record header or editor | `.ed-btn` | `--panel-2` fill, `--line-2` border; hover `--accent-soft` |
| Text button | `.lnk` | Accent text, no box |
| Icon button in the bar | `.hd-ib` | 32×32, no border, 18px icon; needs `aria-label` and `title` |

Busy buttons change their label ("Saving…", "Uploading…") and are disabled until done.

### Fields
Dialog and editor fields: `.ed-grid` (two columns, gap 10px 12px) of `.ed-f`: label above (`--fs-xs` semibold
`--ink-3`), input `--fs-sm`, `--radius-md`, 1px `--line` on `--panel`; focus = accent border plus
`--focus-ring`. Required mark: `<i>` in the label (`--s-blocked`). Help text `.ed-hint2`. The form's error goes
in `.ed-err` at the left of the footer. Checkboxes are the browser's, tinted with the accent. The one switch is
`.hd-swi`. Search and filter boxes in a bar: `--panel-2` fill, no border, `--radius-lg`, 32px.

### Settings list (new 2026-11-20, first used by My profile)
For a page of personal settings or facts about one thing. One centred column, at most 720px wide, on `--bg`.

- **Group** `.set-group`: a heading `.set-h` above it (`h2`, `--fs-sm` semibold `--ink-3`, sentence case), then
  a box of rows: `--panel`, `--r-lg`, `--shadow`, no border. An optional footnote under the box in `--fs-xs`
  `--ink-3`. 28px between groups.
- **Row** `.set-row`: at least 48px high, padding 10px 16px, label on the left and one control or value on the
  right, 16px apart, centred vertically. A `--line-2` hairline between rows, starting at the text (16px in).
  - Label `.set-l`: `--fs-base` medium `--ink`, one line. Optional help under it: `--fs-xs` `--ink-3`, two
    lines at most.
  - Value `.set-v`: `--fs-base` `--ink-2`, right-aligned, one line, cut with "…", full text in `title`.
  - Control: a switch `.hd-swi` (on/off), `.seg` (one of two to four), a `<select>` (one of many), a `.tbtn`
    (do something), or a "›" in `--ink-4` when the whole row opens something. A row that opens something is
    itself the link or button and shows `--row-hover` on hover.
- **Stacked row** `.set-row.stack`: label above, control below at full width. For controls wider than about
  half the row (colour swatches, a paragraph of text).
- **Phone:** page padding 16px. A row whose control is a `.seg` of three or more, a `<select>` or a long value
  (`.set-row.wide`) stacks at 700px and under; switches, short buttons and "›" stay beside the label.
- A section the person has nothing in, or may not use, is left out; a group is never shown empty.

### Cards and tiles
`.card` = `--panel`, no border, `--r-lg`, `--shadow`; header `.ch` (title `h3`, 12px 16px, hairline under);
body `.cb`. Number tiles: `.tiles` grid of `.tile` (big number `b`, label `span` in `--ink-3`); hover shows a
1px accent ring; switched on (`.on`) a 2px accent ring.

### Status and priority
Status: `pill(status)` → `.pill.st-*`, text in the status colour on its `-bg` tint. Priority: `prio(p)` → a 9px
dot in `--p-*` plus the word. Colour is never the only signal: the word is always there.

### Tables
A plain `<table>` inside `.tbl`: a white rounded sheet (`--r-lg`, `--shadow`); sticky header in `--fs-sm`-ish
grey semibold (`--ink-3`) on `--panel`, click to sort; cells 10px 12px in `--fs-sm`; a `--line-2` hairline
under each row; no zebra. A clickable row is `tr.r` with `tabindex="0"` and Enter opens it. Money and counts
are right-aligned with `.num`. Empty cells show "—". On a phone, tables scroll sideways.
Selection: see decision 4 — the box on the selected cell is `.gtb td.cell`; arrow keys move it, Enter opens,
Ctrl/⌘+C copies.

### Tabs and switches
- Sections of a page: underline tabs in the bar, `.hd-tabs` (active = `--ink` semibold with a 2px accent line).
- Choosing one of a few views or modes: `.seg` (grey track, raised white active button).
- Tabs inside a record: `.dtabs`.

### Dialogs
Built with `pvSheet(title, bodyHTML, actionsHTML, onWire)`: dimmed backdrop, `--panel` box, `--radius-2xl`,
title on the left of the header. Small forms use `.ed-dialog` (560px) with the footer `.ed-foot`: error text on
the left, then **Cancel**, then the main action, right-aligned. Every dialog closes with Esc, a click on the
backdrop, and a visible Close or ✕. On a phone (620px and under) a dialog becomes a sheet from the bottom.

### Record windows
A task, work order, project or other record opens in `#detail`. On a computer it docks as the right half of the
screen; **Float** turns it into a movable window with sizes S / M / L / full, **Snap** holds it beside EOS, and
⤢ makes it a full page (content capped at 980px). Header `.dh`: the record number line (for example
"TASK T-27-01909"), the title, a copy button, then actions in `.dh-actions`. On a phone (820px and under) the
record fills the screen; Float, Snap and sizes are hidden.

### Menus, hover text, messages
- Menu: `.exp-menu` (opened with `openExportMenu` or as `#lkPop`); bar popovers `.hd-pop`. `--shadow-3`, items
  at least 34px high.
- Hover text: the browser's own (`title=`), with a matching `aria-label` on icon-only buttons.
- Confirmation: `editToast(message)` — dark pill at the bottom centre, 4 seconds; with **Undo** it stays 9
  seconds. Anything that can be undone offers Undo instead of asking first.

### Charts
Hand-drawn SVG; no chart library. Decisions 1–3 apply to every chart. Lines and bars use the chart tokens
above; budget and target lines are `--ink-3`, projections dashed. A legend sits above or beside the plot, not
over it. Labels on the axis use short dates ("Nov ’26").

### Empty, loading, failed, not permitted
| State | Pattern |
|-------|---------|
| Empty | `.empty`: a heading that says what is missing ("No fuel logged yet") and one line on what to do next. Inside a card or list, one muted line ("No attendees yet"). |
| Loading | `.loading` — a shimmer block where the content will be. A button that is working changes its label ("Saving…"). |
| Failed to load | `.err` — a red-tinted box that says what could not be loaded and what to try ("Couldn't load this dashboard. Check your connection, then Refresh."). |
| Failed to save | `.ed-err` in the dialog footer, or a toast: "Couldn't save: " plus a plain reason from `edError()`. |
| Not permitted | The control is not shown (`can()`, `canEdit()`, `canCreate()`). A whole page the person cannot use says so in `.empty` and who to ask ("Ask an administrator for …"). Never a disabled button without a reason. |

---

## 4. Wording

- **Plain words** (decision 5). Write what a City employee would say.
- **Sentence case** for headings, buttons, table headers and menu items ("Save current view", "Open
  commitments"). Small labels are made uppercase by CSS (`--fs-label`), not typed in capitals.
- **Buttons**: a verb, or verb plus noun. Create is **"+ Task"**, "+ Event" (`+` and the noun). Commit is
  **Save**. Dismiss is **Cancel** in a form and **Close** where nothing was changed. **Remove** takes something
  off a list or record; **Delete** destroys it. A label that opens a dialog or picker ends in "…" ("Merge…").
- **Messages** (toasts): short, no full stop: "Saved", "Note added", "Link removed". Failures start
  "Couldn't …" and say what to do.
- **Dates**: `fd()` → "Nov 19, 2026". Date and time: `fdt()` → "Nov 19, 3:05 PM". How long ago: `ago()` →
  "2d ago". Month: "November 2026". Never 11/19/26 or 2026-11-19 on screen.
- **Money**: `usd()` → "$1,234.56", negative "-$1,234.56". Short forms only on tiles and chart axes: `boK()` →
  "$12K", "$1.2M".
- **Percent**: `boPct()` → "42%". **Hours**: "1.5 h".
- **Record numbers**: `taskRef()` "T-27-01565", `woNum()` "W-27-00385", `projRef()` "P-27-00041", `rqRef()`
  "R-27-00001", `pkRef()` "WP-27-00004" (`recRef()` for the bare number). Never build one by hand.
- **Nothing to show**: "—" in a cell or field; "None yet" for an empty list inside a record.

---

## 5. Phone (about 390 wide)

- **700px and under is "phone"**; **820px and under** the layout changes (record windows fill the screen).
  Use these two breakpoints. Dialogs become bottom sheets at 620px.
- Navigation moves to a bottom tab bar (`#tabbar`: Home, Work, Mapping, Scheduling, More); More opens a sheet.
  The page bar keeps search (as an icon), Filters, **+**, ⋯ and your initials; the page title and section tabs
  give way to the bottom bar and a section switcher.
- Tables scroll sideways inside their sheet; the page itself never scrolls sideways.
- On touch screens fields are 17px text and at least 38px high (so iOS does not zoom); things to tap are at
  least 34px, 44px for the main action of a form.
- Print and Export are not offered in the phone bar.
- Check every change at 390 wide in light and dark, with long titles and an empty state.

## 6. Light and dark

- Dark is `html[data-theme="dark"]`, set by the person's choice. Style dark with
  `[data-theme="dark"] …` rules or, better, with tokens that already change. Do not use
  `@media (prefers-color-scheme: dark)`: a person can choose Light on a dark computer.
- A colour that is right in light is usually wrong in dark. Tints are made from tokens
  (`color-mix(in srgb, var(--accent) 12%, var(--panel))`), not typed hex.
- Text on an accent fill is `--accent-ink`, never `#fff` (some accents are light).
- Printed pages (timesheets, reports, field sheets) are their own white documents and do not follow the theme.

## 7. Keyboard

- Everything that can be clicked can be reached with Tab and worked with Enter or Space. Use a `<button>`; a
  clickable row gets `tabindex="0"` and an Enter handler.
- Focus shows as a 2px `--accent` outline (the global `:focus-visible` rule). Do not remove it without putting
  `--focus-ring` or an accent border in its place.
- Esc closes the top-most dialog, menu or floating record.
- Shortcuts in use: Ctrl/⌘+K find anything · `/` search this page · `?` help · Alt+R the navigation ·
  Ctrl/⌘+F find in the open record · Ctrl/⌘+Enter send a note · arrow keys in lists, menus and the cell grid.

---

## 8. Not yet consistent

The same job done several ways. The first-named is the one to keep (section 3); the others stay until Sam asks
for them to change or the screen is being reworked. No rewrites are requested here.

| Job | Keep | Also in the app |
|-----|------|-----------------|
| Ordinary button | `.tbtn` (about 456) | `.ed-btn` (53), `.bd-btn` on dashboards (31, 16px radius, 32px high), `.h4btn`, `.mp-btn` |
| Main button | `.tbtn.new` / `.btn-update` | `.bd-btn.pri`; hard-coded green and purple buttons (`.tt-ready`, `.mo-go`, `.mm-go`) |
| Delete (danger) button | `.tbtn.danger` in red | In the live look `.tbtn.danger` and `.ed-btn.danger` are **not red** (the mac rule wins); red shows only in the bulk bar and one menu |
| Small or disabled button | — (no standard yet) | About 7 one-off small sizes; 6 different disabled looks (opacity .4 to .6) |
| Form field | `.ed-f` in `.ed-grid` | `.pd-f`, `.p14-f`, `.wf-f` (defined twice), `.fw-f` (field forms, larger on purpose), `.fm-g`, and others; input padding from 5px to 12px |
| Card | `.card` (no border, shadow) | About 15 bordered, unshadowed cards (`pd-card`, `cp-card`, `fg-card`, `gi-card`, `po-card`, …) with radii from 10 to 16px |
| Number tile | `.tile` | `.bo-tile`, `.fl-kpi`, `.evd-tile` |
| Status badge | `pill()` → `.pill.st-*` | `.flag` (32), `.chip` (defined twice, two shapes), `.pd-chip` and `.tt-chip` (typed colours), `.gp-tag`, `.ct-badge` |
| Table | `<table>` in `.tbl` | `pd-t`, `bl-t`, `ac-mt`, `fin-lines`, `p14-t`, `gi-t` and a dozen single-use table styles, each with its own cell padding and header |
| Right-aligned numbers | `.num` | `.num` only sets even-width digits; right alignment is added table by table |
| Selected row / cell | Cell box `.gtb td.cell` (decision 4) | Row tint plus 4px bar (`tr.r.sel`) everywhere else; 2px outline on picked cards; 3px ink outline in the criticality matrix |
| Tabs | `.hd-tabs` (page), `.seg` (views), `.dtabs` (record) | `.pv-tabs` / `.sr7-tabs` (ink underline), folder tabs (`.ws-tab`, `.snap-tab`), pill tabs `.gd-tabs`, `.fw-seg` |
| Dialog | `pvSheet` (about 68) | Browser `confirm()` (60), `prompt()` (14), `alert()` (1); `.gcfg` (4), `.ed-modal` (2), and four one-off overlays. Seven backdrop tints, four radii, layers from 90 to 7000 |
| Dialog buttons | Footer: Cancel, then main action | `pvSheet` puts actions in the header with "Close" last; the dashboard editor puts Save before Cancel |
| Close control | — (✕ or "Close", not settled) | Six differently styled ✕ buttons; `pvSheet` uses the word "Close" |
| Menu | `.exp-menu` | `.hd-pop`, account menu, and four other menu builders; `.exp-menu` does not close on Esc |
| Hover text | Browser `title=` (about 705) | Five custom tooltip boxes |
| Confirmation message | `editToast` (about 375) | `exportToast` (own element, 2.5 seconds, typed red) |
| Empty state | `.empty` (91) / one muted line (149) | About 15 one-off `*-empty` classes |
| Loading | `.loading` shimmer | Plain "Loading…" text (about 66); one spinner. Note: the shimmer hides its text, so written loading messages are not seen |
| Error | `.err` with plain words | `.err` showing raw error text (about 38); four different `.err` definitions; "Couldn't" (17) and "Could not" (7) |
| Create label | "+ Task" (86) | "+ New task" (21), "Add …" (24), "Create …" (7), "New …" (7) |
| Commit label | "Save" | "Done" (15), "Apply" (8), "OK" (1) |
| Edit label | "Edit" (19) | "✎ Edit" (12); icon prefixes in general are used on some buttons and not others |
| Case | Sentence case | Title Case on a few buttons ("Money Mode", "Exit Meeting Mode") and on Budget column headers ("Revised Budget") |
| Date | `fd()` "Nov 19, 2026" | `pvD()` (a copy of `fd`), "Nov 19" without year, "11/19/26", raw "2026-11" |
| Money | `usd()` with cents | `money()` no cents (5), typed-in `"$"+…` (3), `boM()` |
| Percent | `boPct()` | Typed-in `toFixed` + "%" (23) |
| Nothing to show | "—" | Blank (very common), "–", "-", "None" |
| Greens | `--s-done` | `#16a34a`, `#15803d`, `--success`, `#1baf7a` for done, met and finished |
| Chart colours | `--bo-*` (money), `--cp-*` (assets) | A 12-colour typed list (`BO_PAL`), typed hex in Forestry, project, Gantt and package charts, `--accent` for spending |
| Chart read-out | `.bo-read` row above the plot (decision 2) | See section 1 |
| Phone breakpoint | 700px and 820px | 620, 640, 560, 760, 900 one-offs |
| Phone table | Scrolls sideways | Assets and Fleet turn into cards |
| Dark rules | `[data-theme="dark"]` | `@media (prefers-color-scheme:dark)` at lines 681–682 (system badges) is not tied to the person's choice: on a dark computer set to Light they show dark colours |
| Token use | Token names | Text roles `--text-*` are defined and used nowhere; 78 typed font sizes (some 10 and 10.5px, below the 11px floor); 144 typed radii; about 545 typed colours in the stylesheet; `--r` / `--r-lg` / `--shadow` / `--shadow-lg` alongside `--radius-*` / `--shadow-1..4` |
| Keyboard | `<button>` or `tr.r` with `tabindex` | About 34 clickable `div`/`span` with no keyboard access; dialogs do not keep Tab inside them or return focus; a few fields lose their focus ring |

### Sam's earlier design pages and the app

| Page | What it proposed | The app today |
|------|------------------|---------------|
| EOS Design Tokens | 10 type sizes, 5 weights, 10 radii, 4 shadows, 2 focus rings, 14 fixed colours; "use these names, never raw values" | The tokens are in the app as proposed. Typed values remain (see "Token use" above). The page shows the old teal/stone colours; the app now uses the mac look with a blue default accent. |
| EOS Type Scale | 14px base, one ratio, ten text roles with their own line height and weight, nothing under 11px, grey text at 4.5 : 1 | Sizes and the role tokens are in the app. The ten roles are defined but not used anywhere; a few typed 10 and 10.5px sizes remain. Contrast of `--ink-3` in the mac look was not re-measured for this file. |
| EOS Header System | One bar per page (option A), 56px, tabs in the bar, only notifications and your initials on every page, a labelled "+ New task ▾" | One bar is built and folds as proposed, with the phone bottom bar. It is 48px, not 56. The create button is a round **+**, not a labelled "+ New task". More than two controls are on every page (the bar also shows a calendar-add button, "Mine", and a calendar button). |

---

*Could not be determined from the code alone:* whether the bottom safe-area padding works on an installed iPhone
app (the page does not ask for it); exact contrast figures; what a few map pop-ups show for a date.
