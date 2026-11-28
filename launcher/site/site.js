// Shared by every page on wildcard.jtlab.cc: the header (navigation and a live online indicator), the footer, the
// server status (one fetch per page, refreshed every minute) and the pieces more than one page shows (the weekly
// event, the changelog). A page names itself with <body data-page="...">.
const Wildcard = (() => {
  const STATUS = "https://join.jtlab.cc/api/status";
  const PAGES = [
    ["home", "./", "Home"],
    ["how-to-play", "how-to-play.html", "How to play"],
    ["server", "server.html", "Server"],
    ["leaderboards", "leaderboards.html", "Leaderboards"],
    ["pets", "pets.html", "Tameable pets"],
    ["enchants", "enchants.html", "Mystic Enchants"],
    ["changes", "changes.html", "Changes"],
  ];

  function el(tag, attrs = {}, ...children) {
    const node = document.createElement(tag);
    for (const [key, value] of Object.entries(attrs)) {
      if (value === false || value === null || value === undefined) continue;
      if (key === "class") node.className = value;
      else node.setAttribute(key, value === true ? "" : value);
    }
    for (const child of children.flat()) {
      if (child !== null && child !== undefined) node.append(child.nodeType ? child : String(child));
    }
    return node;
  }

  // Header and footer.
  function chrome() {
    const page = document.body.dataset.page;
    const nav = el("nav", { class: "site-nav", "aria-label": "Site" },
      PAGES.map(([id, href, label]) => el("a", { href, "aria-current": id === page ? "page" : null }, label)));
    const pill = el("a", { class: "pill", id: "live", href: "server.html", title: "Server status" },
      el("span", { class: "dot" }), "Checking...");
    const header = el("header", { class: "site-header" },
      el("div", { class: "inner" },
        el("a", { class: "brand", href: "./" }, el("span", { class: "mark", "aria-hidden": "true" }, "W"), "Wildcard"),
        nav, pill));
    document.body.prepend(header);
    const current = nav.querySelector("[aria-current]");
    if (current) current.scrollIntoView({ block: "nearest", inline: "center" });
    document.body.append(el("footer", { class: "site-footer" },
      el("div", { class: "inner" },
        el("span", {}, "Wildcard: James's World of Warcraft server."),
        el("span", {}, el("a", { href: "https://join.jtlab.cc" }, "Create an account"), " · ",
          el("a", { href: "how-to-play.html" }, "How to play"), " · Restarts nightly at 4:00 am Sydney time"))));
  }

  // Status: one request shared by everything on the page.
  let statusPromise = null;
  const listeners = [];
  function status() {
    if (!statusPromise) {
      statusPromise = fetch(STATUS, { cache: "no-store" }).then((r) => {
        if (!r.ok) throw new Error(r.status);
        return r.json();
      });
      statusPromise.catch(() => {});
    }
    return statusPromise;
  }
  function onStatus(callback) {
    listeners.push(callback);
    status().then(callback, () => callback(null));
  }
  function refresh() {
    statusPromise = null;
    status().then((s) => listeners.forEach((f) => f(s)), () => listeners.forEach((f) => f(null)));
  }

  function players(s) {
    return typeof s.players === "number" ? s.players : null;
  }
  function bots(s) {
    const real = players(s);
    return typeof s.characters === "number" && real !== null ? Math.max(0, s.characters - real) : null;
  }

  function showPill(s) {
    const pill = document.getElementById("live");
    if (!pill) return;
    pill.textContent = "";
    const dot = el("span", { class: "dot" });
    if (!s) {
      pill.append(dot, "Status unavailable");
      return;
    }
    if (s.world) {
      dot.classList.add("up");
      const n = players(s);
      pill.append(dot, el("b", {}, "Online"), n === null ? "" : ` · ${n} playing`);
    } else {
      dot.classList.add("down");
      pill.append(dot, el("b", {}, s.login ? "Restarting" : "Offline"));
    }
  }

  // The weekly event: name, countdown, the coming weeks and the bonuses. compact leaves out the timeline.
  function untilText(ms) {
    const minutes = Math.max(0, Math.floor(ms / 60000));
    const d = Math.floor(minutes / 1440), h = Math.floor(minutes / 60) % 24, m = minutes % 60;
    const s = Math.max(0, Math.floor(ms / 1000)) % 60;
    if (d) return `${d}d ${h}h ${m}m`;
    if (h) return `${h}h ${m}m ${String(s).padStart(2, "0")}s`;
    return `${m}m ${String(s).padStart(2, "0")}s`;
  }
  function whenText(ms) {
    return new Date(ms).toLocaleString(undefined, { weekday: "short", day: "numeric", month: "short",
      hour: "numeric", minute: "2-digit" });
  }

  const events = [];
  function renderEvent(box, w, { compact = false } = {}) {
    box.textContent = "";
    if (!w || !w.current) {
      box.append(el("p", { class: "note" }, "No event this week."));
      return;
    }
    const entry = { box, w, big: el("strong"), small: el("span"), fill: null, pin: null };
    box.append(el("p", { class: "event-name" }, (w.active ? "" : "Coming up: ") + w.current.title),
      el("div", { class: "countdown" }, entry.big, entry.small));
    if (!compact) {
      const weeks = w.weeks && w.weeks.length ? w.weeks : [w.current, w.next].filter(Boolean);
      box.append(el("div", { class: "timeline", role: "list" }, weeks.map((week, n) => {
        const bar = el("div", { class: "bar" });
        if (n === 0) {
          entry.fill = el("div", { class: "fill" });
          entry.pin = el("div", { class: "pin" });
          bar.append(entry.fill, entry.pin);
        }
        return el("div", { class: "week" + (n === 0 ? " now" : ""), role: "listitem" }, bar,
          el("b", {}, week.title), el("small", {}, n === 0 && w.active ? "Now" : week.friday));
      })));
    }
    box.append(el("ul", { class: "boosts" }, (w.current.boosts || []).map((b) => el("li", {}, b))));
    const old = events.findIndex((e) => e.box === box);
    if (old >= 0) events.splice(old, 1);
    events.push(entry);
    tick();
  }
  function tick() {
    const now = Date.now();
    for (const e of events) {
      const { w } = e;
      if (!w.current.endsAt) continue;
      const start = w.current.startsAt, end = w.current.endsAt;
      if (now < start) {
        e.big.textContent = "Starts in " + untilText(start - now);
        e.small.textContent = whenText(start);
      } else if (now < end) {
        e.big.textContent = untilText(end - now) + " left";
        e.small.textContent = w.next ? `then ${w.next.title}, ${whenText(w.next.startsAt || end)}` : `ends ${whenText(end)}`;
      } else {
        e.big.textContent = "Changing over...";
        e.small.textContent = "";
        if (now - end > 5000 && now - end < 7000) refresh();
      }
      const done = Math.min(100, Math.max(0, (now - start) / (end - start) * 100));
      if (e.fill) e.fill.style.width = done + "%";
      if (e.pin) { e.pin.style.left = done + "%"; e.pin.hidden = now < start; }
    }
  }

  // The changelog the publish step writes next to the pages: the last week of changes, by day.
  let changesPromise = null;
  function changes() {
    if (!changesPromise) {
      changesPromise = fetch("changelog.json", { cache: "no-store" }).then((r) => r.json()).then((log) => {
        const days = Array.isArray(log.days) ? log.days : (log.days ? [log.days] : []);
        return days.map((day) => ({ label: day.label || day.date,
          items: (Array.isArray(day.items) ? day.items : (day.items ? [day.items] : [])).map((i) => i.text) }));
      });
    }
    return changesPromise;
  }

  document.addEventListener("DOMContentLoaded", () => {
    chrome();
    onStatus(showPill);
    setInterval(refresh, 60000);
    setInterval(tick, 1000);
  });

  return { el, status, onStatus, refresh, players, bots, renderEvent, changes };
})();
