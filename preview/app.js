// Control panel + phone mockup for the browser preview.
(function () {
  "use strict";

  const SHARED = window.MARGIN_SHARED;
  const R = window.MarginRender;
  const { el } = R;
  const ENUMS = SHARED.enums;
  const STORE_KEY = "margin.preview.settings.v1";
  const UI_KEY = "margin.preview.ui.v1";

  // ---------- state ----------

  const clone = (v) => JSON.parse(JSON.stringify(v));

  // Same deep merge as JSONMerge in ios/Shared/Models.swift: missing keys keep defaults.
  function merge(base, over) {
    if (!isObj(base) || !isObj(over)) return over === undefined ? base : over;
    const out = { ...base };
    for (const [k, v] of Object.entries(over)) out[k] = k in base ? merge(base[k], v) : v;
    return out;
  }
  function isObj(v) { return v && typeof v === "object" && !Array.isArray(v); }

  function load(key, fallback) {
    try {
      const raw = localStorage.getItem(key);
      return raw ? merge(clone(fallback), JSON.parse(raw)) : clone(fallback);
    } catch { return clone(fallback); }
  }
  function save(key, value) {
    try { localStorage.setItem(key, JSON.stringify(value)); } catch { /* private mode etc. */ }
  }

  let settings = load(STORE_KEY, SHARED.defaults);
  const ui = load(UI_KEY, { view: "homescreen", size: "medium", icons: true, bounds: false, freeze: false, systemDark: true, compare: false });

  // Optional URL overrides for quick comparisons and screenshots (not saved):
  // ?view=app&size=large&theme=washi&appearance=light&freeze=1
  const params = new URLSearchParams(location.search);
  if (params.has("view")) ui.view = params.get("view");
  if (params.has("size")) ui.size = params.get("size");
  if (params.has("freeze")) ui.freeze = params.get("freeze") === "1";
  if (params.has("theme")) settings.themeId = params.get("theme");
  if (params.has("appearance")) settings.appearance = params.get("appearance");

  const get = (path) => path.split(".").reduce((o, k) => o[k], settings);
  function set(path, value) {
    const keys = path.split(".");
    const last = keys.pop();
    keys.reduce((o, k) => o[k], settings)[last] = value;
    commit();
  }
  function commit() {
    save(STORE_KEY, settings);
    render();
  }
  function setUI(key, value) {
    ui[key] = value;
    save(UI_KEY, ui);
    renderToolbar();
    render();
    if (key === "systemDark") buildControls();
  }

  // ---------- controls ----------

  const controls = document.getElementById("controls");

  function section(title, children) {
    return el("section", null, [el("h2", null, title), ...children]);
  }

  function row(label, control, extra) {
    const r = el("div", null, [el("div", null, [el("span", null, label), extra || null]), control]);
    r.className = "row";
    r.firstChild.className = "row-head";
    return r;
  }

  function choice(label, path, options, fmt) {
    const wrap = el("div");
    wrap.className = "choices";
    const paint = () => [...wrap.children].forEach((b) => b.classList.toggle("on", b.dataset.value === String(get(path))));
    for (const opt of options) {
      const b = el("button", null, fmt ? fmt(opt) : opt);
      b.type = "button";
      b.dataset.value = opt;
      b.onclick = () => { set(path, opt); paint(); if (path === "appearance") buildControls(); };
      wrap.append(b);
    }
    paint();
    return row(label, wrap);
  }

  function range(label, path, min, max, step) {
    const input = el("input");
    Object.assign(input, { type: "range", min, max, step, value: get(path) });
    const out = el("output", null, fmtNum(get(path), step));
    input.oninput = () => { set(path, Number(input.value)); out.textContent = fmtNum(Number(input.value), step); };
    return row(label, input, out);
  }
  const fmtNum = (v, step) => (step < 1 ? v.toFixed(1) : String(Math.round(v)));

  function toggle(label, path) {
    const input = el("input");
    input.type = "checkbox";
    input.checked = get(path);
    input.onchange = () => set(path, input.checked);
    const l = el("label", null, [el("span", null, label), input]);
    l.className = "toggle";
    return l;
  }

  function text(label, path, placeholder) {
    const input = el("input");
    Object.assign(input, { type: "text", value: get(path), placeholder: placeholder || "" });
    input.oninput = () => set(path, input.value);
    return row(label, input);
  }

  function colorOverride(label, key) {
    const input = el("input");
    input.type = "color";
    const status = el("button", null, "");
    status.type = "button";
    status.className = "link";
    const paint = () => {
      const v = settings.colors[key];
      const theme = R.resolveTheme(settings, SHARED.themes, ui.systemDark);
      input.value = R.isHex(v) ? "#" + v.replace("#", "").slice(0, 6) : toHex6(theme[key]);
      status.textContent = v ? "reset" : "theme";
      status.disabled = !v;
    };
    input.oninput = () => { settings.colors[key] = input.value.toUpperCase(); commit(); paint(); };
    status.onclick = () => { settings.colors[key] = ""; commit(); paint(); };
    paint();
    colorPainters.push(paint);
    const wrap = el("div", null, [input, status]);
    wrap.className = "color";
    return row(label, wrap);
  }
  const colorPainters = [];
  const toHex6 = (c) => (c.startsWith("#") ? c.slice(0, 7) : "#000000");

  function themeCards() {
    const wrap = el("div");
    wrap.className = "themes";
    const paint = () => [...wrap.children].forEach((c) => c.classList.toggle("on", c.dataset.id === settings.themeId));
    for (const def of SHARED.themes) {
      const scheme = R.resolveTheme(settings, SHARED.themes, ui.systemDark).scheme;
      const p = scheme === "dark" ? def.dark : def.light;
      const font = R.FONT_STACKS[def.fontDesign];
      const card = el("button", { background: p.background, fontFamily: font }, [
        el("span", { color: p.foreground, fontSize: "24px", fontWeight: "200", letterSpacing: "-0.5px" }, "09:41"),
        el("span", { color: p.secondary, fontSize: "11px", display: "flex", alignItems: "center", gap: "5px" }, [
          el("i", { width: "4px", height: "4px", borderRadius: "50%", background: p.accent, display: "inline-block" }), def.name.toLowerCase()]),
        el("span", { color: p.foreground, fontSize: "11px", fontWeight: "300", marginTop: "auto", lineHeight: "1.3" }, ["music", el("br"), "notes"]),
      ]);
      card.type = "button";
      card.dataset.id = def.id;
      card.title = def.description;
      card.onclick = () => { settings.themeId = def.id; commit(); paint(); colorPainters.forEach((f) => f()); };
      wrap.append(card);
    }
    paint();
    return wrap;
  }

  function shortcutsEditor() {
    const wrap = el("div");
    wrap.className = "shortcuts";
    const build = () => {
      wrap.replaceChildren();
      settings.shortcuts.forEach((sc, i) => {
        const vis = el("input");
        vis.type = "checkbox";
        vis.checked = sc.visible;
        vis.title = "visible";
        vis.onchange = () => { sc.visible = vis.checked; commit(); };
        const name = el("input");
        Object.assign(name, { type: "text", value: sc.name, placeholder: "name" });
        name.oninput = () => { sc.name = name.value; commit(); };
        const url = el("input");
        Object.assign(url, { type: "text", value: sc.url, placeholder: "url scheme, e.g. music://" });
        url.className = "mono";
        url.oninput = () => { sc.url = url.value; commit(); url.classList.toggle("bad", !/^[a-z][a-z0-9+.-]*:/i.test(url.value.trim())); };
        url.classList.toggle("bad", !/^[a-z][a-z0-9+.-]*:/i.test(sc.url.trim()));
        const btn = (label, title, fn) => { const b = el("button", null, label); b.type = "button"; b.title = title; b.onclick = fn; return b; };
        const move = (d) => () => {
          const j = i + d;
          if (j < 0 || j >= settings.shortcuts.length) return;
          [settings.shortcuts[i], settings.shortcuts[j]] = [settings.shortcuts[j], settings.shortcuts[i]];
          commit(); build();
        };
        const item = el("div", null, [
          el("div", null, [vis, name, btn("↑", "move up", move(-1)), btn("↓", "move down", move(1)),
            btn("×", "delete", () => { settings.shortcuts.splice(i, 1); commit(); build(); })]),
          url,
        ]);
        item.className = "shortcut";
        wrap.append(item);
      });

      const presets = el("select");
      presets.append(el("option", null, "+ add preset…"));
      for (const p of SHARED.presets) {
        const o = el("option", null, `${p.name} — ${p.url}`);
        o.value = p.name;
        presets.append(o);
      }
      presets.onchange = () => {
        const p = SHARED.presets.find((x) => x.name === presets.value);
        if (p) { settings.shortcuts.push({ id: newId(), name: p.name, url: p.url, visible: true }); commit(); build(); }
      };
      const blank = el("button", null, "+ blank");
      blank.type = "button";
      blank.onclick = () => { settings.shortcuts.push({ id: newId(), name: "New", url: "", visible: true }); commit(); build(); };
      const actions = el("div", null, [presets, blank]);
      actions.className = "shortcut-actions";
      wrap.append(actions);
    };
    build();
    return wrap;
  }
  const newId = () => (crypto.randomUUID ? crypto.randomUUID() : String(Date.now() + Math.random())).toUpperCase();

  function dataSection() {
    const msg = el("p");
    msg.className = "note";
    const button = (label, fn) => { const b = el("button", null, label); b.type = "button"; b.onclick = fn; return b; };
    const say = (t) => { msg.textContent = t; };
    const json = () => JSON.stringify(settings, null, 2);
    const buttons = el("div", null, [
      button("Copy JSON", async () => {
        try { await navigator.clipboard.writeText(json()); say("Copied. On the iPhone: Margin → settings → paste settings from clipboard."); }
        catch { say("Clipboard blocked by the browser. Use Download instead."); }
      }),
      button("Download", () => {
        const a = el("a");
        a.href = URL.createObjectURL(new Blob([json()], { type: "application/json" }));
        a.download = "margin-settings.json";
        a.click();
        URL.revokeObjectURL(a.href);
      }),
      button("Import…", () => document.getElementById("import-dialog").showModal()),
      button("Reset", () => { if (confirm("Reset all preview settings to defaults?")) { settings = clone(SHARED.defaults); commit(); buildControls(); } }),
    ]);
    buttons.className = "buttons";
    return section("Data", [
      buttons, msg,
      el("p", { marginTop: "8px" }, "The JSON is the same format the iOS app imports and exports, so a look designed here can be pasted into the app."),
    ]);
  }

  function buildControls() {
    colorPainters.length = 0;
    const E = ENUMS;
    controls.replaceChildren(
      section("Theme", [themeCards(), choice("appearance", "appearance", E.Appearance)]),
      section("Typography", [
        choice("typeface", "typography.fontDesign", E.FontDesignChoice),
        range("clock size", "typography.clockSize", 32, 120, 1),
        choice("clock weight", "typography.clockWeight", E.WeightChoice),
        range("label size", "typography.labelSize", 14, 44, 1),
        choice("label weight", "typography.labelWeight", E.WeightChoice),
        range("small text size", "typography.metaSize", 10, 20, 1),
        range("letter spacing", "typography.tracking", -1, 4, 0.1),
        choice("case", "typography.labelCase", E.LabelCase),
      ]),
      section("Layout", [
        choice("alignment", "layout.alignment", E.TextAlign),
        range("spacing", "layout.itemSpacing", 4, 40, 1),
        range("side margin", "layout.padding", 12, 56, 1),
      ]),
      section("Clock & text", [
        toggle("clock", "header.showClock"),
        toggle("24-hour", "header.use24Hour"),
        toggle("date", "header.showDate"),
        choice("date style", "header.dateStyle", E.DateStyleChoice),
        toggle("accent dot", "header.showAccentDot"),
        toggle("motto", "header.showMotto"),
        text("motto text", "header.motto", "a line for yourself"),
      ]),
      section("Shortcuts", [
        el("p", null, "Unchecked = hidden. Red URL = not a valid URL; it shows dimmed, as on iOS."),
        shortcutsEditor(),
      ]),
      section("Widget", [
        toggle("clock", "widget.showClock"),
        toggle("date", "widget.showDate"),
        toggle("motto", "widget.showMotto"),
        range("clock size", "widget.clockSize", 20, 72, 1),
        range("label size", "widget.labelSize", 11, 30, 1),
        choice("tap opens", "widget.launchMode", E.LaunchMode, (v) => (v === "direct" ? "app directly" : "via margin")),
      ]),
      section("Colour overrides", [
        colorOverride("background", "background"),
        colorOverride("text", "foreground"),
        colorOverride("secondary", "secondary"),
        colorOverride("accent", "accent"),
      ]),
      dataSection(),
    );
  }

  // ---------- toolbar ----------

  const toolbar = document.getElementById("toolbar");

  function renderToolbar() {
    const group = (label, key, options) => {
      const g = el("div", null, [el("span", null, label)]);
      g.className = "seg";
      for (const [value, text] of options) {
        const b = el("button", null, text);
        b.type = "button";
        b.className = ui[key] === value ? "on" : "";
        b.onclick = () => setUI(key, value);
        g.append(b);
      }
      return g;
    };
    const check = (label, key) => {
      const input = el("input");
      input.type = "checkbox";
      input.checked = !!ui[key];
      input.onchange = () => setUI(key, input.checked);
      const l = el("label", null, [input, label]);
      l.className = "check";
      return l;
    };
    toolbar.replaceChildren(
      group("view", "view", [["homescreen", "home screen"], ["app", "app"]]),
      group("widget", "size", [["small", "S"], ["medium", "M"], ["large", "L"]]),
      check("app icons", "icons"),
      check("widget bounds", "bounds"),
      check("freeze 09:41", "freeze"),
      check("system dark", "systemDark"),
      check("compare themes", "compare"),
    );
  }

  // ---------- phone ----------

  const phone = document.getElementById("screen");
  const strip = document.getElementById("strip");

  function now() {
    if (!ui.freeze) return new Date();
    const d = new Date();
    d.setHours(9, 41, 0, 0);
    return d;
  }

  function icon(t) {
    return el("div", { display: "flex", flexDirection: "column", alignItems: "center", gap: "6px" }, [
      el("div", { width: "60px", height: "60px", borderRadius: "14px", background: t.divider }),
      el("div", { width: "34px", height: "4px", borderRadius: "2px", background: t.secondary, opacity: "0.35" }),
    ]);
  }

  function boundsWrap(node, t) {
    if (ui.bounds) node.style.outline = `1px dashed ${t.secondary}`;
    return node;
  }

  function homeScreen(t, date) {
    const iconRow = () => el("div", { display: "flex", justifyContent: "space-between", width: "338px" }, [icon(t), icon(t), icon(t), icon(t)]);
    const widget = boundsWrap(R.widget(ui.size, settings, t, date), t);
    const showIcons = ui.icons;
    let grid;
    if (ui.size === "small") {
      const square = el("div", { display: "grid", gridTemplateColumns: "60px 60px", gap: "16px 24px", width: "158px", justifyContent: "center", visibility: showIcons ? "visible" : "hidden" },
        [icon(t), icon(t), icon(t), icon(t)]);
      grid = [el("div", { display: "flex", justifyContent: "space-between", width: "338px" }, [widget, square]), showIcons && iconRow()];
    } else if (ui.size === "medium") {
      grid = [widget, showIcons && iconRow()];
    } else {
      grid = [widget];
    }

    return el("div", { position: "absolute", inset: "0", background: t.background, fontFamily: R.FONT_STACKS.system }, [
      statusBar(t),
      el("div", { position: "absolute", top: "72px", left: "27.5px", display: "flex", flexDirection: "column", gap: "26px" }, grid),
      showIcons && el("div", {
        position: "absolute", left: "12px", right: "12px", bottom: "12px", height: "92px", borderRadius: "32px",
        background: t.scheme === "dark" ? "rgba(255,255,255,0.07)" : "rgba(0,0,0,0.05)",
        display: "flex", alignItems: "center", justifyContent: "space-around", padding: "0 16px",
      }, [0, 1, 2, 3].map(() => el("div", { width: "60px", height: "60px", borderRadius: "14px", background: t.divider }))),
      homeIndicator(t),
    ]);
  }

  function statusBar(t) {
    return el("div", { position: "absolute", top: "0", left: "0", right: "0", height: "54px", display: "flex", alignItems: "center", justifyContent: "space-between", padding: "4px 34px 0 46px", boxSizing: "border-box", color: t.foreground, fontFamily: R.FONT_STACKS.system, fontWeight: "600", fontSize: "17px" }, [
      el("span", null, R.formatTime(now(), true)),
      el("span", { fontSize: "12px", letterSpacing: "1px", opacity: "0.9" }, "▮▮▮ 100%"),
    ]);
  }

  function homeIndicator(t) {
    return el("div", { position: "absolute", bottom: "8px", left: "50%", transform: "translateX(-50%)", width: "134px", height: "5px", borderRadius: "3px", background: t.foreground, opacity: "0.85" });
  }

  function appScreen(t, date) {
    return el("div", { position: "absolute", inset: "0", background: t.background, display: "flex", flexDirection: "column" }, [
      statusBar(t),
      el("div", { position: "absolute", top: "59px", bottom: "34px", left: "0", right: "0", display: "flex", flexDirection: "column" }, [
        el("div", { flex: "1", minHeight: "0" }, [R.home(settings, t, date)]),
        R.tabBar(t, "home"),
      ]),
      homeIndicator(t),
    ]);
  }

  function render() {
    const t = R.resolveTheme(settings, SHARED.themes, ui.systemDark);
    const date = now();
    phone.replaceChildren(ui.view === "app" ? appScreen(t, date) : homeScreen(t, date));
    document.documentElement.style.setProperty("--phone-bezel", t.scheme === "dark" ? "#1a1a1a" : "#d9d9d9");

    // Actual-size widgets (1 CSS px = 1 pt), or one medium per theme.
    const items = ui.compare
      ? SHARED.themes.map((def) => {
          const s = { ...settings, themeId: def.id, colors: { background: "", foreground: "", secondary: "", accent: "" } };
          const tt = R.resolveTheme(s, SHARED.themes, ui.systemDark);
          return [def.name, R.widget("medium", s, tt, date)];
        })
      : ["small", "medium", "large"].map((size) => [size, R.widget(size, settings, t, date)]);
    strip.replaceChildren(...items.map(([label, node]) =>
      el("figure", null, [boundsWrap(node, t), el("figcaption", null, label)])));
    strip.style.setProperty("--wallpaper", t.background);
  }

  // ---------- phone scaling ----------

  function fit() {
    const stage = document.getElementById("phone-wrap");
    const scale = Math.min(1, (stage.clientHeight - 8) / 876, (stage.clientWidth - 8) / 417);
    document.documentElement.style.setProperty("--scale", String(Math.max(0.4, scale)));
  }
  window.addEventListener("resize", fit);

  // ---------- import dialog ----------

  const dialog = document.getElementById("import-dialog");
  document.getElementById("import-apply").onclick = (e) => {
    e.preventDefault();
    const area = document.getElementById("import-text");
    const err = document.getElementById("import-error");
    try {
      const parsed = JSON.parse(area.value);
      if (!isObj(parsed)) throw new Error("Expected a JSON object.");
      settings = merge(clone(SHARED.defaults), parsed);
      commit();
      buildControls();
      err.textContent = "";
      dialog.close();
    } catch (ex) {
      err.textContent = "Not valid settings JSON: " + ex.message;
    }
  };
  document.getElementById("import-cancel").onclick = () => dialog.close();

  // ---------- start ----------

  buildControls();
  renderToolbar();
  render();
  fit();
  let lastMinute = new Date().getMinutes();
  setInterval(() => {
    const m = new Date().getMinutes();
    if (m !== lastMinute) { lastMinute = m; render(); }
  }, 1000);
})();
