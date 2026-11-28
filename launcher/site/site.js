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
    ["racials", "racials.html", "Racials"],
    ["pets", "pets.html", "Tameable pets"],
    ["wildcard", "wildcard.html", "Abilities and talents"],
    ["enchants", "enchants.html", "Mystic Enchants"],
    ["planner", "planner.html", "Build planner"],
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

  // Spell tooltips, as the game shows them: enchant-tooltips.json and pet-tooltips.json, with icons/<name>.png.
  // Made on the VM from the server's spell data and the client's icons (launcher/tooltips/build_spell_data.py).
  // Every piece of text goes in with textContent.
  const tipFiles = {};
  function tooltips(file) {
    if (!tipFiles[file]) {
      tipFiles[file] = fetch(file, { cache: "no-store" }).then((r) => {
        if (!r.ok) throw new Error(r.status);
        return r.json();
      });
      tipFiles[file].catch(() => {});
    }
    return tipFiles[file];
  }

  function icon(name, size = 36) {
    const img = el("img", { class: "spell-icon", width: size, height: size, alt: "", loading: "lazy",
                            src: "icons/" + (name || "inv_misc_questionmark") + ".png" });
    img.onerror = () => { img.onerror = null; img.src = "icons/inv_misc_questionmark.png"; };
    return img;
  }

  function tipLines(lines) {
    return lines.map((line) => {
      const p = el("p", { class: line.length ? "" : "gap" });
      for (const [text, style] of line) {
        if (!style) p.append(text);
        else if (style === "note") p.append(el("span", { class: "tip-note" }, text));
        else {
          const span = el("span", {}, text);
          span.style.color = "#" + style;
          p.append(span);
        }
      }
      return p;
    });
  }

  // A tooltip card. extra: { quality: "legendary", qualityLabel, limit: 1, rank: 2 (a talent's rank), facts: [..],
  // source: "where it comes from" }
  function tipCard(tip, extra = {}) {
    const ranks = tip.ranks || [];
    const rank = ranks.length ? Math.min(Math.max(extra.rank || ranks.length, 1), ranks.length) : 0;
    const card = el("div", { class: "tip-card" },
      el("div", { class: "tip-head" }, icon(tip.icon, 40),
        el("div", {}, el("div", { class: "tip-name " + (extra.quality || "") }, extra.name || tip.name),
          extra.qualityLabel ? el("div", { class: "tip-sub" }, extra.qualityLabel) : null,
          rank ? el("div", { class: "tip-sub" }, `Rank ${rank} of ${ranks.length}`) : null)));
    for (const fact of extra.facts || []) card.append(el("div", { class: "tip-sub" }, fact));
    for (const name of tip.req || []) card.append(el("div", { class: "tip-req" }, "Requires " + name));
    for (const name of tip.unlock || []) card.append(el("div", { class: "tip-req" }, "Unlocked by " + name));
    card.append(el("div", { class: "tip-body" }, tipLines(rank ? ranks[rank - 1] : tip.lines || [])));
    if (extra.subsLabel && (tip.subs || []).length) card.append(el("div", { class: "tip-sub tip-embed" }, extra.subsLabel));
    for (const sub of tip.subs || []) {
      card.append(el("div", { class: extra.subsLabel ? "tip-embed flat" : "tip-embed" },
        el("div", { class: "tip-head small" }, icon(sub.icon, 22), el("div", { class: "tip-name" }, sub.name)),
        el("div", { class: "tip-body" }, tipLines(sub.lines || []))));
    }
    if (tip.change) card.append(el("div", { class: "tip-change" }, el("b", {}, "Changed on Wildcard: "), tip.change));
    if (tip.note) card.append(el("div", { class: "tip-change" }, tip.note));
    if (tip.where) card.append(el("div", { class: "tip-where" }, el("b", {}, "Ascension's hint: "), tip.where));
    if (extra.source) card.append(el("div", { class: "tip-change" }, extra.source));
    if (extra.limit) card.append(el("div", { class: "tip-limit" },
      extra.limit === 1 ? "One per character" : "Up to " + extra.limit + " per character"));
    return card;
  }

  // One floating tooltip for the page: hover or keyboard focus shows it, and a tap toggles it on a phone.
  let floating = null;
  let owner = null;
  function hideTip() {
    if (floating) floating.remove();
    floating = null;
    owner = null;
  }
  function showTip(node, make, pinned = false) {
    hideTip();
    owner = node;
    floating = el("div", { class: "tip-float" + (pinned ? " pinned" : ""), role: "tooltip" }, make());
    floating.addEventListener("click", (event) => event.stopPropagation());
    document.body.append(floating);
    const box = node.getBoundingClientRect();
    const w = floating.offsetWidth;
    const h = floating.offsetHeight;
    let left = Math.min(box.left, window.innerWidth - w - 8);
    let top = box.bottom + 6;
    if (top + h > window.innerHeight - 8 && box.top - h - 6 > 8) top = box.top - h - 6;
    floating.style.left = Math.max(8, left) + "px";
    floating.style.top = Math.max(8, top) + "px";
  }
  function attachTip(node, make) {
    node.tabIndex = 0;
    node.classList.add("has-tip");
    node.addEventListener("mouseenter", () => showTip(node, make));
    node.addEventListener("mouseleave", () => { if (floating && !floating.classList.contains("pinned")) hideTip(); });
    node.addEventListener("focus", () => showTip(node, make));
    node.addEventListener("blur", () => { if (floating && !floating.classList.contains("pinned")) hideTip(); });
    node.addEventListener("click", (event) => {
      event.stopPropagation();
      // A tap pins it, so a long one can be scrolled on a phone; tap again or anywhere else to close.
      if (owner === node && floating && floating.classList.contains("pinned")) hideTip(); else showTip(node, make, true);
    });
  }
  document.addEventListener("click", hideTip);
  document.addEventListener("scroll", hideTip, { passive: true });
  document.addEventListener("keydown", (event) => { if (event.key === "Escape") hideTip(); });

  document.addEventListener("DOMContentLoaded", () => {
    chrome();
    onStatus(showPill);
    setInterval(refresh, 60000);
    setInterval(tick, 1000);
  });

  return { el, status, onStatus, refresh, players, bots, renderEvent, changes, tooltips, icon, tipCard, attachTip };
})();
