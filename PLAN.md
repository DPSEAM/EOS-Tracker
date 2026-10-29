# What's coming in EOS

The next builds in order, then everything else on the list by area. When a build goes out, its lines move to the changelog.

## Next builds, in order

1. **Ask AI hands you the file.** Ask for a document and the chat opens it, shows it and can quote from it. Answers carry document, task and person cards that open the record.
2. **Saved AI conversations.** Your conversations are kept, with titles, a history list and search, so you can pick one up again.
3. **Roles and permissions.** One place to see and change what each role can see and do, with ready-made role templates. Deleting records becomes its own permission here (today it goes with editing).
4. **Requisitions and purchase orders.** Quote → requisition → PO in one place (everything starts as a requisition), with the Commonwealth purchasing checks built in: three quotes above the threshold, prevailing wage, review over $5,000, City contracts. Foremen load quotes and pick the account, so coding questions stop going back and forth. A projected budget on a project before any PO exists, which becomes the encumbrance once the real PO is cut.
5. **Work tied to assets.** Link tasks, work orders and requests to assets on the map; see the full work history on an asset; existing work matched to assets; the OpenGov activity list on tasks.
6. **GIS symbols by default.** Every layer carries a saved symbol set, so the map looks finished the moment you sign in; symbols that rotate with the asset (valves, signs, flow direction); pop-ups that follow the ArcGIS Online set-up.
7. **Document collections.** Group documents into collections and folders, nested, with a collections view on records.
8. **Invoices from email.** Invoice emails and PDFs sent to the EOS mailbox become invoices, matched to the purchase order and routed for sign-off.
9. **Sign-in screen.** A better first screen: City imagery, a status line, one-tap sign-in on a trusted device, and a way to request access.
10. **3D and LiDAR.** The CYVL street-level scan of the City in a 3D view, and extracting GIS layers from engineering plans.

## Open questions

- Who may edit the Directory: today only the system owner; supervisors and administrators could.
- Whether permissions stay as a single access level per person or become per-role grants.
- Pop-ups on the map: configured in ArcGIS Online (recommended) or in EOS.
- Whether sign-in should remember a trusted device and sign you in with one tap.
- The PO log: whether EOS syncs it through OneDrive or Google Sheets (the spreadsheets stay the place where transfers, reclasses and police details are worked; EOS reflects them).
- Harbor Management enterprise accounts: Sam to pull them so they load under the Enterprise tab.

## Everything else, by area

### App-wide
- Deleting: a delete button on notes and knowledge entries, and on people (merge or delete a duplicate person).
- A Trash view on Documents that also removes the file from Drive when a document is deleted for good.
- Built-in help on each tab and a short tour at first sign-in.
- Open any record in its own browser tab, with links you can share.
- Edit and correct notes after saving, with the change kept in history.
- A history panel on every record showing every change.
- One export and print menu on every list and record.
- A voicemail player for voice messages sent to EOS.
- Accessibility to WCAG 2.1 AA.
- A full tab-by-tab review and polish pass.
- Restyle EOS from a prompt or an image.

### Work: tasks, work orders, projects
- A clearer work order status lifecycle (status groups, "Waiting on vendor").
- A project record page with tabs, a health strip and required fields.

### Home and messages
- Messages: @mention a person (with a notification), replies on Home, instant delivery and attachments.
- Notifications by email: a daily digest, or straight away for the kinds you choose; instant push on the phone app.
- Reminder emails for overdue tasks, new requests and repeating tasks.
- Weather bulletins from the City's forecasting service on Home.

### Map and GIS
- Clean-up and update of the premade saved maps.
- Measure, sketch, buffer select and abutter lists on the map, feeding abutter notice letters.
- One map engine shared by GIS, Pavement and Documents.
- Street basemaps that stay sharp at any zoom.
- Correct GIS records from LiDAR and 3D scans.
- A Fire Department live map with truck locations and calls.
- Live water meter reads from Neptune.
- Augmented reality on iPad: point the camera at the street and see utilities and assets.

### Field and iPad
- Asset condition, risk and priority on the asset register.
- Asset history in the map pop-up: forms and tasks on this asset.
- Crew review of drafted field forms before they are sent.
- Follow-up actions on a form create follow-up tasks.
- Forms per role: who can fill which forms.
- Photos inside punch-list items.
- Photos and a map pin on a request.
- The app loads offline on field devices.
- Fleet management: vehicles and equipment as assets, with service history.

### Documents
- A Knowledge Base of how the City runs and its history.
- AI-written summaries on document records.
- Public records obligations in the Knowledge Base, and a records retention helper.
- A Drive drop folder: drop files, folders and zips and they appear in EOS.
- Bring the old Access database into the document library.
- Document version history.

### Budget and invoices
- Automatic monthly reload of the ledger (today the workbook is loaded by hand from the Budget tab).
- Invoice routing by who owns the project: Engineering projects to the division's administrative assistant by default, DPS projects to the contracts and PO clerk and the invoice clerk, with reassignment. Flags at 80% of any line or of the PO, and when an amendment spans two POs.
- Permissions by division: foremen and crews see only their own lines; the same division codes the Overview uses.
- Purchase order and invoice approval workflow with full sign-off.
- Building-related fields in the budgeting view.
- Fiscal-year rollover of open purchase orders and commitments.
- Grant reimbursement tracking.
- Retainage tracking on pay requisitions.
- Vendor and consultant profiles with contracts and certificates of insurance.
- Vendor numbers from the City ledger, so purchase orders match vendors.
- Supplier and Service vendor groups alongside Consultant.

### Calendar and meetings
- The DPS recurring meeting schedule, with attendees and agendas.
- Meeting minutes and files on a meeting, processed at the next ingest.
- Real-time meeting notes.
- Connect your Google or Outlook calendar both ways.
- Gantt charts for projects, work orders and the Calendar.

### Dashboards and reports
- Hydrant flushing dashboard, with the map.
- Catch basin cleanout tracking.
- A Monday morning Water Division work plan, generated and sent automatically.
- A Monday follow-up report for each person, listing only their own items.
- A City Council project report.

### Directory and people
- Invite new users by email instead of a temporary password; require a password change at first sign-in.
- Administrators can add users.
- Visibility settings for work order programs by level.
- Clean-up passes: school staff and vendors listed as employees, out-of-date aliases, assignments and work order names, two programs that should be merged, roles with no level.
- Job descriptions on roles.
- Data quality checks run nightly and trended.

### Email intake
- One task per line when an email lists work under headings, with the statuses written on each line.
- Safeguards: email cannot add City employees to the Directory or change how EOS works.
- Notes keep the date the email was received, not the date it was read.
- Invoice emails create invoices.
- Public service requests from Q-Alert.
- A Gmail inbox view inside EOS with important and awaiting flags.
- Intake that runs the moment an email arrives instead of every hour.

### Pavement
- Pavement layers on the GIS tab.
- Budget scenarios projecting the network condition.
- A paving list optimizer by condition gain per dollar.
- Abutter notice letters from street addresses.
- Water and utility layers feed the utility items on paving jobs.
- The December CYVL scan.

### Platform
- Where EOS lives: Supabase cloud or a City server.
- IT onboarding of EOS.
- Align work orders with OpenGov and plan the path to push records to OpenGov, with a Draft, Reviewed, Pushed lifecycle.
- Record numbers: keep them readable as volume grows.
- Performance: faster loading on every tab.
- Admin screens for settings, rules and the data dictionary.
- System Health in three sections: Ingest, Checks, Admin.
- Two-step sign-in required for senior levels.
