# EOS design standard

The written standard for how EOS looks and behaves. It is the Design Kit (Administration › Design Kit) in words.
All 25 kit sections were approved by Sam between Nov 23 and Nov 25, 2026 (recorded in `settings.design_kit_review`);
this file was rewritten from the kit on Nov 25, 2026 (v555). The kit is the live reference — when this file and
the kit disagree, the kit wins and this file is fixed.

## 1. How to use it

- **Building something new or changing a screen:** use the kit's pieces (section 4) and follow the section that
  covers the job (section 5). Never hand-build a button, field, table, menu, status, window or toast.
- **Moving a module to the new system** (one module at a time, Sam, Nov 25): see section 2. The rollout is tracked
  as one task per module on WO #385 (T-27-03572 to T-27-03586).
- **Checking:** a must-fix is anything that breaks a rule in section 5 or Sam's standing decisions (section 3),
  breaks on a phone or in dark, cannot be used by keyboard, or would confuse the person.
- **Not converted yet:** a module that has not had its rollout task keeps its old look until then. Its old
  patterns are listed in section 10; they are not bugs to fix on sight.

## 2. Moving a module to the new system

1. **Swap the parts.** Replace the module's own buttons, fields, tables, menus, dialogs, statuses, empty and
   loading states with the kit pieces (section 4). Browser `confirm()`/`prompt()`/`alert()` become kit windows
   or Undo; plain date boxes become the EOS calendar picker; `<datalist>` becomes the type-ahead picker.
2. **Switch it on.** The kit's sizes, corners and spacing live under the `.ks` scope. A module gets them by
   putting its page inside `.ks` once its parts are swapped. Nothing outside a converted module changes.
3. **Go through the checklist.** Every approved kit section is listed for the module in
   `.claude/harness/design-modules.json` and marked done, kept (Sam chose today's look for that piece), n/a or todo. Past
   decisions apply without being asked again (Sam, Nov 25: decisions made before must not be left out). The checklist
   goes with every before/after picture, and a module is not converted while anything is todo.
4. **Run the design check** — `node .claude/harness/design-check.js` (add `--all` for the worst functions). It
   counts the old patterns app-wide; a module's functions are listed in `.claude/harness/design-modules.json`, and
   once its status is `converted` the check fails if an old pattern appears in them again.
5. **Show Sam before and after** (light, dark, phone) for each group of pieces — **one picture at a time, each with
   its own multiple-choice question** (A · As today / B · the proposal / other choices, with a recommendation), and
   wait for his answer before the next picture (Sam, Nov 25). **Work collects on the module's own
   branch (`design/<module>`, e.g. `design/administration`) and goes to main only when the whole module is done**, as
   one build (Sam, Nov 25). Push the branch as work goes so nothing is lost; don't bump `BUILD` or take a `vNNN` until
   the module ships. Administration goes first and is shown to Eric for his feedback.
6. **A decision made while moving a module is a decision for the whole app** (Sam, Nov 25: "as we go implementing
   modules, my decisions impact the whole app"). When Sam picks a look for something in one module — a new one, or
   keeping today's — it becomes a kit piece (built from today's code when he keeps today's look) and a section in
   the kit and in section 5 below, the same day. Every module converted afterwards uses it, and modules already
   converted are updated in the same build.
   **Keeping today's look covers only the piece being decided** (Sam, Nov 25). Keeping today's page top keeps the page
   top; every other approved kit piece — the header, icon buttons, buttons, fields, windows instead of browser boxes,
   messages, tables — still comes to the module.

## 3. Sam's standing decisions

These outrank everything else. Decisions 1–5 are from 2026-11-19 and still apply; the old decision 6 ("the way
Apple's software reads") is replaced by the approved Design Kit.

| # | Decision | In practice |
|---|----------|-------------|
| 1 | **Revenue is shown in green.** | `--s-done`. Spending is never green. |
| 2 | **A chart's read-out goes in a line above the chart, not in a box over it.** | `.bo-read` / `BO_READ` ("Point at the chart to read its numbers here."). Kept in section 23. |
| 3 | **Every pop-up says which date its numbers are from.** | Starts with the date or period, written with `fd()`. |
| 4 | **Tables are clean and plain, with a blue box on the selected cell.** | The kit table (`kGrid`, section 16). |
| 5 | **Plain words on screen, no developer terms.** | No table names, SQL, status codes, "ingest", "level 6", raw field names or raw errors. |
| 6 | **The Design Kit is the standard** (approved Nov 23–25, 2026). | Sections 4 and 5. Where the kit keeps today's look (Home gadgets, charts, Budget, symbology, things in a calendar day) that is deliberate: users are not to be thrown. |

## 4. Tokens and pieces

### Tokens inside the new system (`.ks` scope)

- **Text:** `--fs-label` 12 · `--fs-2xs` 12 · `--fs-xs` 13 · `--fs-sm` 14 · `--fs-base` 14 · `--fs-md` 16 · `--fs-lg` 16 ·
  `--fs-xl` 21 · `--fs-2xl` 21 · `--fs-3xl` 28. Body is 14. Two weights: regular and semibold.
- **Corners:** `--radius-sm` 4 · `--radius-md` 5 (buttons, fields) · `--radius-lg` 6 · `--r-lg` 7 (cards) · `--radius-2xl` 9.
- **Room:** `--sp-1` 4 · `--sp-2` 8 · `--sp-3` 12 · `--sp-4` 16. Nothing nudged by eye.
- **Icons:** `--icon-w` 1.4 (thin lines), sizes 16 / 18 / 20.
- **Surfaces:** `--glass-card` (frosted card, 80% solid) over the person's background picture; `--accent-text`
  (the accent nudged to stay readable as text).

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

### The pieces (in `index.html`)

- **`K.*` helpers** — `pageHead`, `hub`, `setList`, `setRow`, `toggle`, `check` (with `setForm`), `btn`, `iconBtn`, `pill`, `prio`, `status`, `dot`, `bars`, `person`, `asset`, `due`, `progress`,
  `count`, `row`, `list`, `recRow`, `card`, `stat`, `tabs`, `seg`, `ro`, `field`, `input`, `select`, `textarea`, `sw`,
  `note`, `empty`, `loading`, `facts`, `recHead`, `attn`, `feed`, `av`, `composer`, `chat`, `docType`, `docTag`,
  `docPv`, `docCard`, `drop`, `photoStrip`.
- **`kGrid(host, cfg)`** — the table (Find, Filter, Columns, sort, the selected-cell box, rows on a narrow card).
- **`kIc(name)`** — the one drawn icon set (`K_IC`).
- **Kit demonstrations still to become shared pieces** the first time a module needs them: windows (move, snap,
  minimise, full screen — `kitWinHTML`), the record split (`kSplitWire`), pickers (`kitPk*`), menus (`kitMn*`),
  the document window (`kitDc*`), the map (`kitMp*`), the calendar and Gantt (`kc*`, `kgn*`) and the print preview
  (`kpr*`, `kitPrPrint`).

## 5. The 25 sections

The rules exactly as approved in the kit.

### Foundations

#### 1. Colour and surfaces

The base every screen sits on: the page, the cards on it, the text, and the few colours that carry meaning.

- One look. Light and dark both always work.
- The page is your background picture, covered about 80% so words on the page stay easy to read. No picture chosen means a plain page.
- Cards are separate panes of frosted glass (80% solid) with a thin outline and a soft shadow. No cards inside cards: inside a card, thin lines separate the parts.
- Text has four strengths — main, secondary, label, faint — and nothing in between.
- Colour means something in only two places: status (grey planned, blue in progress, orange waiting, green done, red overdue or blocked) and priority. They never change with your accent.
- Accent: each person picks their own, from any of the 19 or a colour of their own, as today. It is used only for the main button, links, and whatever is selected. Tap one above to try it.
- Some accents are close to a status colour (green, red, orange, gold). So a status is always its dot and its word, never colour alone, and words in your accent are nudged lighter or darker where needed so they stay easy to read.

*Replaces:* Today: eight accents whose button words vanish in dark mode (fixed in v507); eight older looks still in the code that nobody can choose any more; cards that are solid on some pages and see-through on others; and the background picture is hidden on Administration pages.

#### 2. Text sizes and spacing

How big words are, how round corners are, and how much room things get. Three short ladders, used everywhere.

- Six text sizes and no others: page title, record title, card title, body, small, label. Most words are body, 14 points — one step bigger than before.
- Two weights: regular for values, semibold for titles and whatever is selected. Bold only on a page title.
- Corners are tight: 7 on a card, 5 on a button or field, 4 on small things. Only dots, pictures of people and on/off switches are round.
- Room comes from one ladder — 4, 8, 12, 16: 4 inside a control, 8 between cards, 12 inside a card, 16 at the edge of the page. Nothing is nudged by eye.
- Table and list rows stay roomy enough to tap (your earlier decision).

*Replaces:* Today the styles hold 79 different text sizes (most follow 11), 59 corner sizes, 62 gaps and 354 paddings.

#### 3. Icons

Small pictures that stand for an action or a kind of thing. One drawn set, used the same way everywhere.

- One drawn set, thin lines, the same line weight on every icon.
- Three sizes: 16 beside words, 18 when the icon is the whole button, 20 in the navigation.
- An icon takes the colour of the words beside it. Red only for a warning or a delete; your accent only when it is selected.
- A button may be only an icon when everyone knows it: Close, More, Find, Filter, Columns, Export, Refresh, Full page and the arrows. Its name shows when you point at it. Every other action has a word.
- Typed symbols and emoji become drawn icons (arrows, ×, ✓, pencil, lock, document, pin, camera…). Colour emoji stay only for the weather.

*Replaces:* Today: 145 drawn icons kept in 17 separate lists, with more than ten line weights and two grid sizes; and 63 typed symbols and emoji used as icons in 742 places, which look different on an iPad, Windows and Android.

### App frame

#### 4. Global header

The bar across the top of every page: where you are on the left, the same few buttons on the right.

- Left, unchanged: the EOS button opens the list of modules; the module's sections are tabs across the bar.
- Right, in this order: search · + New · a thin line · ⋯ this page · Modes · Messages · Alerts · What's Happening · you. Nothing else, and the same on every page.
- ⋯ is always there, holds only the rare actions for this whole page, and always ends with Print this page and Help for this page. Tools for a list live on the list; tools for a record live on the record.
- Modes holds Meeting Mode, Money Mode (Budget staff) and Work space. While one is on, the Modes button becomes that mode's coloured chip with its own Exit — try it.
- Search is an icon, not a box: the magnifier (or Ctrl K, ⌘K on a Mac) searches all of EOS — records, addresses, pages — from any page.
- Find lives on whatever it searches: the list card for a list, the map's own box on the map, the calendar's toolbar, the top of Messages.
- No Mine / Everyone switch: each list chooses Whose — Mine, Unassigned or Everyone — on the list itself.
- On a phone: the sections become a drop-down, and Messages, Alerts and What's Happening share one bell.

*Replaces:* Today: 13 controls after the tabs in five different shapes; the ⋯ button disappears on some pages so the icons move; Meeting Mode and the Work space switch are on every page, Money Mode only on Budget; Mine / Everyone in the header is changed by only some pages.

#### 5. Navigation

How you move from one module to another, on a computer and on a phone.

- On a computer the EOS button opens one plain list: Search all of EOS first, then every module you can use, always in the same order.
- The module you are in is highlighted. Modules you have no access to are left out, never shown greyed.
- No counts in the menu or on the tabs — what needs you is in Messages, Alerts and What's Happening.
- Inside a module, its sections are tabs across the header (on a phone, a drop-down) — see Global header.
- On a phone the bar at the bottom has Home, Work, Mapping, Scheduling and More. More opens a sheet with search and every other module.

*Replaces:* Today the list order and the phone bar are already right; this writes them down so new modules follow them. Home and Messages show counts in the menu today; those go.

#### 6. Page layout

How a page sits under the header, and how a record opens.

- Full width. A page uses all the room the screen gives it, so tables keep their columns.
- A list page is the header, then a row of status tiles — one per status, with its count; click one to hide or show that status — then the list. Finished statuses start hidden.
- Clicking a row opens the record beside the list. Drag the edge between them to share the room; EOS remembers where you leave it, and a double-click puts it back to half and half.
- ⤢ makes the record the full page, with a way back to the list. On a phone a record is always the full page.
- Every module follows this, so a list page always starts the same way.

*Replaces:* Today the status tiles are only on Work; Requests has a row of buttons in the page, Documents and Assets have their own; a record opens in a panel whose width cannot be changed.

#### 6a. Page tops and hub pages (decided while moving Administration, Nov 25)

The top of a page that is not a list or a record, and a page that lists other pages — today's Administration look,
kept and used everywhere.

- **Keep today's look** (Sam, Nov 25: "I like our design we have today"). This is the Administration look, and it is now the standard for every page of this kind in EOS.
- **The top of a page** (`K.pageHead`): ‹ back to where you came from; a coloured icon for the area; the area in small capitals in its colour; the title; one sentence on what the page is for.
- **A hub page** (`K.hub`): cards with a coloured top edge and the area's icon, a one-line hint, then each page as a row. A row that needs a look has a dot (orange to look at, red to act on); a page not built yet is greyed with its task number.

*Replaces:* Administration built these by hand; other modules (Budget, Dashboards, Scheduling, Mapping) each start their pages their own way.

#### 6b. Settings, switches and tick boxes (decided while moving Administration, Nov 25)

Pages where you change how something works: values you type, on/off settings, and tick boxes in a table.

- **Settings you type into** (`K.setList`, `K.setRow`, wired with `setForm`): the label and one line of help on the left, the box on the right; **Cancel and Save at the bottom of the card**, which stay off until something changes and say how many changes are not saved (Sam, Nov 25).
- **An on/off setting is a switch on the right** (`K.toggle`, or class `k-tg` on a tick box), green when on (Sam, Nov 25).
- **Tick boxes where you tick many in a table** (Required, On the form) are the kit tick box (`K.check`, or class `k-ck` on a tick box), blue when ticked (Sam, Nov 25). Both sit on a real tick box, so existing code reading `.checked` keeps working.
- Tables in Administration keep today's look (Sam, Nov 25).

*Replaces:* a Save button beside one box, the browser's own tick boxes, and on/off settings written as a tick box before the words.

#### 7. Dialogs and windows

Editing or creating opens a window over the page that you can move, snap, enlarge or tuck away; deleting asks first, small removals offer Undo.

- Edit or New opens a window in the middle of the page. Drag its title to move it; snap it to the left or right half, make it full screen, or minimise it to the bar at the bottom and carry on working — click it there to bring it back. Try it.
- Title on the left; on the right, always in this order: minimise · snap left · snap right · full screen · close.
- Footer: Delete in red on the left (only when editing); Cancel, then the main action (Save, Create task) on the right.
- A click outside never closes it. Only Cancel, × or Esc do — and if you typed something, EOS asks “Discard your changes?” first.
- Deleting or cancelling a record, or anything with things attached, asks first in a small dialog that names exactly what goes, with a red button that says what it does (“Delete task”).
- Small removals — a note, a tag, a link — happen straight away with Undo for 10 seconds.
- Never the browser's grey box. On a phone a window is the full screen.
- One window system. These windows are the same as the Work space, Snap and Float windows EOS already has: snapping uses the same zones and layouts, a minimised edit sits in the same bar as Work space tabs, and an edit window opened inside a Work space pane opens over the whole screen, not squeezed inside the pane. With Meeting Mode on, windows stop at the edge of the minutes.

*Replaces:* Today: 9 kinds of dialog (pvSheet in 77 places, pv-modal, ad-sheet, ed-modal, fw-wrap and others), none of which can be moved; and 64 places that use the browser's own grey “OK / Cancel” box.

### Building blocks

#### 8. Buttons

Every action on a button. Four kinds, two sizes — nothing else.

- One Primary per screen, dialog or record — the main thing you came to do.
- Secondary for every other action. Quiet for small, low-key ones (Cancel, Show all).
- Danger only for removing or cancelling something, and it offers Undo or asks first.
- Labels are short verbs in sentence case: “Add update”, “Save”, not “OK”.
- Order: Quiet, Secondary, then Primary last (on the right).
- Height 32 (28 for tight spots such as a table row). Secondary is white with a thin outline (Sam, Nov 24).
- Every button has the same states: pointed at, pressed, a blue ring for keyboard focus, faded when it can't be used (and its tooltip says why), and busy — a spinner with “Saving…” that stops a second click.

*Replaces:* About 125 button styles today. On rollout: tbtn (500 places) and ed-btn become Secondary; tbtn new and btn-update become Primary; lnk becomes Quiet; bd-btn and h4btn become small Secondary; the rest are matched one by one.

#### 9. Icon buttons

Tools that are understood by their picture: close, more, star, zoom.

- 32 × 32 with an 18 icon; a rounded square shows when you point at it, the same corners as other buttons (Sam, Nov 24).
- Switched on (a filter applied, a column chooser open) = tinted in your accent with a small dot.
- Its name shows straight away in EOS's own label when you point at it, with the shortcut if there is one — never the browser's slow yellow label.
- Only for actions everyone knows by their picture (see Icons). Never the main action of a screen — that's a Primary button with words.

*Replaces:* Today: a typed × in 95 places and ✕ in 19, the header's hd-ib, and tw-ib, gmp-ib, rec-x, gai-x, dl-x and others, each a little different.

Pieces added while moving Administration (Nov 25): `K.back(href, label, attrs)` — a back link with the drawn arrow
(“All layouts”), used by `K.pageHead`; the drawn `up` / `down` chevrons for Move up / Move down; inside a chip, a
smaller 22 × 22 ✕ (`.k-xs`) so the chip keeps its height (Sam, Nov 25: B · small drawn ✕). Sam approved each one
picture by picture: drawn move arrows, drawn ✕ remove buttons named on hover, drawn back arrow. For a small removal on a page
that isn't saved yet (a question on a form), `editToast(message, () => putItBack())` gives the bottom bar with Undo — no
more red “Remove?” second click (Sam, Nov 25, Field Forms).

#### 10. Fields

Typing and choosing in forms and dialogs.

- Label above the box, short; a red * when it must be filled (Sam, Nov 24).
- The box is grey with no outline; it turns white with a blue ring while you type in it (Sam, Nov 24). On a frosted card the grey would vanish into the frost, so the box takes a faint see-through shade of the text colour instead (`color-mix(in srgb,var(--ink) 6%,transparent)`, Sam, Nov 25, from Administration).
- A grey hint under the box when it helps. When something is wrong the box turns red, the message replaces the hint under that field, and the footer counts them: “2 things need your attention”.
- A field you can't change is plain text with a small lock and why (“Set by the work order”) — never a faded box.
- On/off is a switch; one of a few is a segmented choice; one of many is a drop-down.
- Two columns on a computer, one on a phone.

*Replaces:* Today: ed-f, fw-f, set-row, fi-f, wf-f, fm-g and others; errors show as one line by the buttons; read-only fields are faded boxes marked read-only.

#### 11. Pickers

Choosing a date, a person, a street or a work order — EOS's own, the same on every device.

- A date opens EOS's own calendar under the box — no quick choices beside it (Sam, Nov 24). Today has a ring, the chosen day is filled; ‹ › change the month.
- From a long list (a street, a person, a work order) you type and EOS's own list narrows as you go. Each choice has a second line that helps you pick the right one: a person's team and whether they sign in to EOS, a street's ward and open tasks, a work order's number and status.
- More than one (people on a task) shows as chips inside the box, each with ×; type to add another.
- ↑ ↓ move through the list, Enter picks, Esc closes. Nothing is typed into a list you can't see.

*Replaces:* Today: the browser's own date box in 40 places and its plain suggestion list in 24, each looking different on an iPad, Windows and Android.

#### 12. Menus and pop-overs

A short list of actions under a button, or a small panel of settings that opens in place.

- A menu: an icon, the words, and the keyboard shortcut on the right; thin lines between groups; a small grey heading names the group (Sam, Nov 24).
- A short grey description under each choice only in + New, where picking the right kind of record matters. Every other menu is words only.
- A red item for anything that removes; it still asks first (see Dialogs and windows). A greyed item says why when you point at it.
- A pop-over (Filter, Columns) is the same panel with a title, ×, its fields, and its buttons at the bottom.
- Opens under its button on the side with room, never off-screen. Closes with Esc, a click outside, or picking an item. ↑ ↓ move, Enter picks, → opens a sub-menu, ← closes it.
- On a phone a menu slides up from the bottom of the screen.

*Replaces:* Today: exp-menu in 17 places, the header's + New and ⋯, the account menu (frosted glass), lk-pop, wf-pop, fg-pop, gai-pop and others.

#### 13. Tabs and choices

Tabs switch between sections. A segmented choice switches between views of the same thing.

- Tabs: words with a line under the one that is open; a small count where useful.
- One row that scrolls sideways when there are more tabs than fit (Sam, Nov 24). An arrow appears only on a side with hidden tabs; swipe, scroll or click it. The open tab is always scrolled into view.
- Tabs are in the same order on every record of a kind; the ones used most come first.
- Choosing one of a few (List · Grid · Map, Chart · Table): 2 to 4 options as joined buttons, the chosen one filled in your accent (Sam, Nov 24).
- More than 4 options is a drop-down instead.

*Replaces:* Today: an open task shows its 12 sections as three rows of boxes; hd-tabs, dtabs, gmp-tabs, seg, tl-c and other view switchers each look different.

#### 14. Status and field looks

What state a record is in, and the standard look of the fields every list shares.

- Each task status keeps its own colour and its two-letter code, as today: “PR - Prioritized”, “WM - Waiting on Materials” (Sam, Nov 24).
- In a list or a table a status is a coloured dot and its label. At the top of a record it is a coloured pill.
- Colour is never the only signal: the words are always there.
- Priority is bars (Urgent in bold); a person who uses EOS has their picture; a due date that has passed is red with a warning sign, today's is blue; progress is a small bar with “3 of 5”; notes and documents are an icon and a count; an asset shows its map symbol.

*Replaces:* Today: pill, st-*, flag, chip, dm-st, ms-c, p14-chip and others; the same 11 colours already used on the Work status tiles.

#### 15. Messages, notices, empty and loading

Telling people what happened, what to watch for, what to do when there is nothing yet, and that something is on its way.

- After you do something, a dark bar at the bottom middle says what happened in one sentence, with Undo when it can be undone. It goes away by itself (4 seconds; 9 with Undo) (Sam, Nov 24).
- A notice on a page is a tinted bar with an icon and one plain sentence: blue information, green done, orange warning, red problem — and at most one button.
- While a list loads a thin bar moves under the header; the list you had stays, faded, until the new one is ready, so nothing jumps (Sam, Nov 24). Never the word “Loading…” on its own.
- An empty page shows a large faint icon, says what is missing, why, and offers one button to fix it (Sam, Nov 24).

*Replaces:* Today: editToast in 427 places (already bottom middle); “Loading…” in 71; err, ed-err, flag, empty, gd-empty, fm-empty and other notices and empty states.

### Showing records

#### 16. Tables

Many records with the same columns — to sort, filter, select and compare. Try everything in this one: it has 120 stand-in tasks.

- Sort: click a column header (again for the other way, a third time to stop). Shift-click a second header to sort by both.
- The header row stays put while the rows scroll, and the first column can stay frozen while you scroll sideways.
- Columns: tick to show or hide, drag or use the arrows to reorder, drag a header's edge to resize, Reset to go back.
- Select with the tick boxes; Shift-click a second box to select everything between. The bar above the table says how many and what you can do with them.
- Find narrows the rows as you type. Filter works like ArcGIS Pro's Select By Attributes: build conditions (field, how, value) joined by and / or, see how many rows match, then Show only these or Select these (new selection, add to, remove from, or within).
- Plain and clean: thin lines between rows, no stripes, a grey header; the selected cell gets a blue box — move it with the arrow keys, Ctrl/⌘+C copies it (your decisions).
- Standard fields look the same in every list: status is a coloured dot and the word; priority is bars; a person who uses EOS gets their picture; a late due date is red; progress is a small bar; notes and documents are an icon and a count; an asset shows its map symbol (your decisions, Nov 22).
- Clicking a row opens the record beside the list — try it. Drag the record's edge to share the room. The arrows step to the next record, the ⤢ button makes it the full page with a way back, and on a phone it is always the full page. Rows are roomy; record numbers use the normal font; tick boxes always show.
- On your background picture the card is frosted glass: the picture shows through, softly blurred.

*Replaces:* Today each list does some of this its own way: tbl, bl-t, gtb (GIS records), doc-tbl (Documents), fi-t and others — some sort, some choose columns, few select, and the filters differ on every page.

#### 17. Lists

Short lists inside something else — on Home, inside a record (a work order's tasks, a task's documents), in side panels. A full module list is always a table.

- A short list shows a few records (usually 3 to 10) where a table won't fit: no column headers, nothing to sort or filter. A full list of records is always a table (see Tables) — there is no Table / List switch (Sam, Nov 24).
- On a phone a table draws itself as these rows.
- A row: the title first, then a grey line with the number and who / where; on the right the status, with the due date under it; › at the end. The whole row opens the record (Sam, Nov 24).
- End a short list with “View all (24)” when there are more, which opens the full table.

*Replaces:* Today: My tasks, Catch up and What's happening on Home, the related lists inside each record, and the alert panel are each drawn their own way.

#### 18. Cards and number tiles

A card holds one topic on a page or dashboard. A number tile shows one number and what it means, and opens the list behind it.

- Card: the title and count on the left, one quiet link on the right (View all, Edit), then its content. Nothing else goes in the top (Sam, Nov 24).
- Number tile: a small coloured icon on the left; beside it the label, the number and one grey line (Sam, Nov 24).
- The icon's colour says what the number means: red needs attention, blue is in hand, green is money coming in or finished, grey is a plain count. Spending is never green.
- Clicking a tile opens the list behind the number — Overdue opens the overdue tasks. A tile lifts when you point at it (Sam, Nov 24).
- No borders — a soft shadow separates cards from the page; on a background picture they are frosted.

*Replaces:* Today: card, pd-card, sp-card, fg-card, cp-card, gi-card, gmp-card, ast-card, bo-tile, gl… each with its own padding and corners. Home's tiles show a red edge; Administration's cards have coloured tops.

#### 19. Record header and details

The top of every task, work order, project, asset or document, and its Details tab.

- The top: the kind, small, on the first line, with icon buttons on the right; the title with its status beside it; a grey line with the number, priority and where it belongs (Sam, Nov 25).
- Icon buttons only: Add update, Discuss, Open as the full page, ⋯ and ×; each says its name when you point at it. Everything else is in ⋯ (Sam, Nov 25).
- Something needs attention: a small pill beside the status in plain words (“71 days late”, “No change in 41 days”); point at it for more, click it to see that field in Details.
- Details is the first tab and lists every field the record has, grouped, with the label on the left and the value on the right (Sam, Nov 25). Empty fields can be hidden.
- The other tabs follow in one row that scrolls (see Tabs).

*Replaces:* Today: the record headers are built 6 different ways; a task shows chips (OVERDUE, NO CHANGE IN 71 DAYS), five loose buttons, a box of four fields at the top and no tab with all of its fields.

#### 20. Notes, messages and activity

What people write on a record (updates, comments, notes), what changed on it, and people writing to each other in Messages.

- Activity on a record: a thin line down the left; each entry has a small picture, the name, what it is (update, comment), the time, then the words (Sam, Nov 25).
- You write at the top; the newest is first (Sam, Nov 25). @ mentions someone; the paperclip attaches a file; Post adds it.
- Changes — status, dates, who it is assigned to — are small grey one-line entries in the same list (Sam, Nov 25).
- Messages: conversations on the left; chat bubbles on the right, yours in the accent colour on the right, theirs on the left with their picture (Sam, Nov 25). The box you write in sits at the bottom; Enter sends, Shift+Enter starts a new line.
- What's Happening (the header panel) uses the same rows as Activity.

*Replaces:* Today: activity cards (tinted boxes, a broken photo strip), notes, What's Happening and Messages each draw their entries their own way.

#### 21. Documents and files

Files on a record — plans, photos, videos, quotes: how they show, how they are added and how they open.

- Each document is a card with a small preview, a coloured mark for the kind of file, its name, and a grey line: kind · date · who added it (Sam, Nov 25). ⋯ on the card: Open, Download, Open in Drive, Remove from this record.
- A drop area always shows at the top — drop files on it, or click it to choose files (Sam, Nov 25). Dropping anywhere on the documents works too. A thin bar shows while files are added.
- Photos are a strip of small pictures above the other files; +N shows the rest (Sam, Nov 25).
- A document opens in an EOS window over the page — move it, snap it to a side, make it full screen or minimise it — with Download, Open in Drive, and ‹ › to step through (Sam, Nov 25). The same window system as Dialogs. Whether it is filed in Drive shows at the bottom of the window.
- Removing a document from a record offers Undo; deleting the file itself happens on the Documents page and asks first.

*Replaces:* Today: the Documents tab (a FILE badge, a link, a status menu and Delete under each), a separate Historical documents box, photo strips on activity cards, and the Documents page's own rows.

### Special screens

#### 22. Map

Every map in EOS — GIS, Work, and the small maps inside records: where the controls go, layers, what happens when you click, and how things are drawn.

- Controls in one column on the right: zoom, then Near me, full screen and Layers (Sam, Nov 25). Search sits at the top left of the map; a scale bar at the bottom left.
- Layers in a panel on the left with three tabs: Layers (a tick shows or hides one; ⋯ for zoom to layer, its table and transparency), Legend, and Basemap (Sam, Nov 25).
- Clicking opens a pop-up like ArcGIS Map Viewer and Pro (Sam, Nov 25): beside the point with a pointer; the layer's symbol, the title and the layer; then every field as label and value. When several things are under the click it says ‹ 1 of 3 ›. Dock pins it to the side. Actions along the bottom: Zoom to, Street View, Add to work, Edit, and ⋯. Clicking the empty map closes it. On a phone it sits at the bottom.
- Points and lines keep the EOS standard symbols (v356, Sam, Nov 25): APWA utility colours, an icon chosen from the layer's name, sizes by kind (mains thicker than services); an administrator sets everyone's default. Work on the map keeps its colours by kind of record.
- Drag the map to move it; the selected thing gets a bright ring, as in ArcGIS.

*Replaces:* Today: GIS (Leaflet + − at the top left, round buttons on the right, a basemap chip, layers on the left), Work (layers and colours on the right), and the maps inside records and Documents, each with its own controls and pop-ups.

#### 23. Charts and Home gadgets

Numbers drawn as pictures — on Home, Budget, Forestry, Schools and asset pages — and the gadgets that hold them on Home.

- Home gadgets keep today's look, inside and out (Sam, Nov 25): the name in small capitals and the link at the top right, and today's rows, I owe / Owed to me tabs, ✓ Done buttons, Budget meters and package bars — so nobody is thrown. The rest of the kit still applies everywhere else.
- Each gadget is as tall as what's in it and keeps today's width (1 to 4 columns); gadgets fit together like bricks, so there are no empty boxes (Sam, Nov 25).
- Charts are the ones EOS already draws (Sam, Nov 25): the accent for what matters now and grey for earlier years; the parts of a whole as shades of one colour; a small legend with squares; and a line above the chart that reads out the numbers you point at, instead of a box drawn over it.
- Kept from Budget (Sam, Nov 25): one big number at the top, bars with a mark for where you should be by now, cards that light up in the accent when you point at them, and cards that slide in one after another when a page opens.
- Glow stays a personal setting in My profile › Appearance (Sam, Nov 25): selected buttons and rows glow, and late or over rows glow red.

*Replaces:* Today: fgBars (Forestry), schChartHTML (Schools), spLineChart and boCatBars (Budget), cpCondChart and acSpark (Assets), the Budget gadget, and 22 Home gadgets — these are the standard; new charts reuse them.

#### 24. Calendar and timeline

Scheduling's Calendar and Gantt charts, and the dates on records — fewer controls, each kept for what it does.

- Only the controls that move you around stay on top (Sam, Nov 25): Calendar — ‹ month › Today and the count; Find, Filter, Month · Week · Day · Agenda and ⋯ on the right (12 controls → 6). Gantt — the chart's name as the title (click to pick another), By work · By labor; Find, Filter, Day · Week · Month · Quarter, Today and ⋯ (27 controls → 7).
- The colour key is the filter (Sam, Nov 25): click a kind to hide it; a hidden kind is struck through. Whose (Mine · Unassigned · Everyone), Person, Crew, Division, what each Gantt row draws, and cancelled meetings are inside Filter — the same Filter as the tables. What you have filtered shows as chips with ×.
- ⋯ holds the rest: Expand all, Collapse all, Sort by…, Recurring meetings…, Subscribe in Outlook…, Print this page. Window sizes go to Work space.
- Things in a day keep today's look (Sam, Nov 25): a thin coloured bar on the left, the time, the title; late in red with ⚑.
- Week and Day have hours down the side (Sam, Nov 25): meetings sit at their time, due dates in an All day row, and a red line shows now.

*Replaces:* Today: the Calendar bar (a stretched ‹, wrapping title and labels, S M L ⤢ Snap Float, Subscribe, Print month, Recurring), the Gantt bar (27 controls in three rows), Week and Day without hours.

#### 25. Print

What EOS puts on paper — a record, a list, a calendar — and what happens when you press Print.

- Print opens a print preview window first (Sam, Nov 25): an EOS window (as in Dialogs) with what to print on the left and the page on the right; then Print, or Save as PDF.
- A record prints as a Report by default, or as a Form when you choose it (Sam, Nov 25). Report: the fields in two columns, instructions, next steps, activity and notes. Form: boxes, room to write by hand, and signature lines — for crews in the field.
- A wide list prints landscape with every column you have on the screen; what you filtered is written at the top (Sam, Nov 25).
- Every page has the City header — the seal, City of Beverly · Department of Public Services, what it is and its number — and a footer with who printed it, when, and Page x of y. No buttons, filters or links go on paper; late dates print in red.

*Replaces:* Today: the browser's print of whatever page is open — printing an open task prints the list, screen controls (Only mine ×, Clear all, Click a row for details) go on paper, right-hand columns are cut off, and nothing says what or when.

## 6. Wording

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

## 7. Phone (about 390 wide)

- **700px and under is "phone"**; **820px and under** the layout changes (record windows fill the screen).
  Use these two breakpoints. Windows fill the screen on a phone.
- Navigation moves to a bottom tab bar (`#tabbar`: Home, Work, Mapping, Scheduling, More); More opens a sheet.
  The page bar keeps search (as an icon), Filters, **+**, ⋯ and your initials; the page title and section tabs
  give way to the bottom bar and a section switcher.
- Tables scroll sideways inside their sheet; the page itself never scrolls sideways.
- On touch screens fields are 17px text and at least 38px high (so iOS does not zoom); things to tap are at
  least 34px, 44px for the main action of a form.
- Print and Export are not offered in the phone bar.
- Check every change at 390 wide in light and dark, with long titles and an empty state.

## 8. Light and dark

- Dark is `html[data-theme="dark"]`, set by the person's choice. Style dark with
  `[data-theme="dark"] …` rules or, better, with tokens that already change. Do not use
  `@media (prefers-color-scheme: dark)`: a person can choose Light on a dark computer.
- A colour that is right in light is usually wrong in dark. Tints are made from tokens
  (`color-mix(in srgb, var(--accent) 12%, var(--panel))`), not typed hex.
- Text on an accent fill is `--accent-ink`, never `#fff` (some accents are light).
- Printed pages are their own white documents (section 5, Print) and do not follow the theme.

## 9. Keyboard

- Everything that can be clicked can be reached with Tab and worked with Enter or Space. Use a `<button>`; a
  clickable row gets `tabindex="0"` and an Enter handler.
- Focus shows as a 2px `--accent` outline (the global `:focus-visible` rule). Do not remove it without putting
  `--focus-ring` or an accent border in its place.
- Esc closes the top-most menu or pop-over; a window with unsaved typing asks first.
- Shortcuts in use: Ctrl/⌘+K find anything · `/` search this page · `?` help · Alt+R the navigation ·
  Ctrl/⌘+F find in the open record · Ctrl/⌘+Enter send a note · arrow keys in lists, menus and the cell grid.

---

## 10. The rollout backlog (from the v469 survey)

Surveyed at v469, before the Design Kit. Each row is one job done several ways in the app today. A module's rollout task replaces them with the kit piece from section 5; the "Keep" column below is the *old* keep and is superseded by the kit.

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
