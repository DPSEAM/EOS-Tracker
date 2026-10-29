/* EOS service worker: device notifications only. No caching, so updates to the app are never held back. */
self.addEventListener("install", () => self.skipWaiting());
self.addEventListener("activate", e => e.waitUntil(self.clients.claim()));

self.addEventListener("push", e => {
  let d = {};
  try { d = e.data ? e.data.json() : {}; } catch { d = { title: "EOS", body: e.data ? e.data.text() : "" }; }
  const title = d.title || "EOS";
  const opts = {
    body: d.body || "",
    icon: d.icon || "./icon-192.png",
    badge: d.badge || "./icon-192.png",
    tag: d.tag || "eos",
    renotify: true,
    data: { url: d.url || "./" },
  };
  e.waitUntil(self.registration.showNotification(title, opts));
});

self.addEventListener("notificationclick", e => {
  e.notification.close();
  const url = new URL((e.notification.data && e.notification.data.url) || "./", self.registration.scope).href;
  e.waitUntil(self.clients.matchAll({ type: "window", includeUncontrolled: true }).then(list => {
    for (const c of list) {
      if (c.url.startsWith(self.registration.scope)) { c.navigate(url); return c.focus(); }
    }
    return self.clients.openWindow(url);
  }));
});

self.addEventListener("pushsubscriptionchange", e => {
  // The browser rotated the subscription: the page re-registers the next time it opens.
  e.waitUntil(Promise.resolve());
});
