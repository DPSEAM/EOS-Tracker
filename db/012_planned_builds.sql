-- 012 · The planned builds shown on the "Coming" tab of What's new (settings.deployment.planned).
-- Data only, no structure. Safe to run again: it replaces the list. Edit the list here or in the settings row; the app reads it live.
-- status: testing (on the test site) · next (up next) · planned · design (being designed)
update public.settings
   set value = value || jsonb_build_object('planned', $j$[
 {"key":"v188","title":"Mini pages, What's new, Directory","status":"testing","note":"Drag mini pages by a grip strip; no blur behind mini pages or Add update; What's new on Home with the full history and the planned builds; Remove and Restore on the person page."},
 {"key":"work-packages","title":"Work packages","status":"next","note":"Bundle tasks, work orders, documents, assets and map points and give them to one person (db/011 is in). Packages for you on Home, progress, accept or send back, print as a field sheet."},
 {"key":"ai-files","title":"Ask AI hands you the file","status":"next","note":"Ask for a document and the chat opens it, previews it and can quote from it; sources are real records, not just links."},
 {"key":"ai-history","title":"Saved AI conversations","status":"planned","note":"Conversations saved per person with titles, a history list and search, like Claude and ChatGPT."},
 {"key":"permissions","title":"Roles and permissions manager","status":"design","note":"One place to see and change what each role can see and do; OpenGov-style role templates on top of the EOS information levels."},
 {"key":"document-collections","title":"Document collections","status":"planned","note":"Group documents into collections and folders, nested, shareable by level, with a documents-in-this-collection view on records."},
 {"key":"gis-links","title":"Work tied to assets","status":"planned","note":"Link tasks, work orders and requests to GIS assets; see work history on an asset and assets on a record; back-fill links from existing work."},
 {"key":"activities","title":"OpenGov activities","status":"planned","note":"Load the OpenGov activities table so each task carries the activity it performs on an asset."},
 {"key":"gis-symbols","title":"GIS symbols by default","status":"planned","note":"Every layer carries a saved symbol set so a new sign-in sees a finished map; symbol rotation by field."},
 {"key":"budget-chart","title":"Budget chart and forecast","status":"planned","note":"Spending by date against budget with a projection to June 30; division cards; drill down from budget line to purchase orders, invoices and work."},
 {"key":"invoice-extraction","title":"Invoices from email","status":"planned","note":"Invoice emails and PDFs to the EOS mailbox become invoice rows, matched to purchase orders and routed for sign-off."},
 {"key":"notifications","title":"Notifications","status":"planned","note":"In-app notification bell for messages, requests, packages and mentions; optional email digests."},
 {"key":"login","title":"Sign-in screen","status":"design","note":"A sign-in screen worth looking at: City imagery, status line, one-tap sign-in on a trusted device."},
 {"key":"cyvl-3d","title":"CYVL LiDAR and 3D","status":"design","note":"Street-level point cloud from the CYVL drive in a 3D view, and plan-to-GIS extraction."}
]$j$::jsonb), updated_at = now()
 where key = 'deployment';
select jsonb_array_length(value->'planned') as planned_items from public.settings where key = 'deployment';
