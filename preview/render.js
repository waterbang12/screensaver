// Browser approximation of the SwiftUI views in ios/Shared/LauncherViews.swift.
// Same settings JSON, same themes, same layout constants. It is NOT iOS
// rendering: fonts, text metrics and widget sizes are close, not exact.
(function () {
  "use strict";

  // Must match LayoutMetrics in ios/Shared/LauncherViews.swift (checked by scripts/check.mjs).
  const METRICS = /*metrics*/{"headerSpacing":6,"dotSize":5,"clockTracking":-0.02,"metaTracking":0.4,"lineHeight":1.25,"widgetPadding":16,"widgetSpacingScale":0.6,"widgetColumnSpacing":12}/*end*/;

  // Nominal widget sizes on a 6.1" iPhone (393 pt wide), as in WidgetSize.previewSize.
  const WIDGET_SIZES = {
    small: { w: 158, h: 158, max: 1 },
    medium: { w: 338, h: 158, max: 4 },
    large: { w: 338, h: 354, max: 8 },
  };

  // Closest web fonts to Apple's system designs. On a Mac/iPhone browser the
  // real SF / New York fonts are used first.
  const FONT_STACKS = {
    system: '-apple-system, "SF Pro Display", "SF Pro Text", Inter, "Segoe UI Variable Display", system-ui, sans-serif',
    serif: '"New York", ui-serif, "Iowan Old Style", Newsreader, Georgia, serif',
    monospaced: 'ui-monospace, "SF Mono", "JetBrains Mono", Menlo, Consolas, monospace',
    rounded: 'ui-rounded, "SF Pro Rounded", Nunito, "Segoe UI Variable Display", sans-serif',
  };

  const WEIGHTS = { ultraLight: 100, thin: 200, light: 300, regular: 400, medium: 500, semibold: 600, bold: 700 };

  const ALIGN = {
    leading: { items: "flex-start", text: "left" },
    center: { items: "center", text: "center" },
    trailing: { items: "flex-end", text: "right" },
  };

  function el(tag, style, children) {
    const node = document.createElement(tag);
    if (style) Object.assign(node.style, style);
    for (const child of [].concat(children || [])) {
      if (child == null || child === false) continue;
      node.append(child instanceof Node ? child : document.createTextNode(String(child)));
    }
    return node;
  }

  const isHex = (v) => typeof v === "string" && /^#?([0-9a-f]{6}|[0-9a-f]{8})$/i.test(v.trim());
  const hex = (v) => {
    const s = v.trim().replace(/^#/, "");
    if (s.length === 6) return "#" + s;
    const a = parseInt(s.slice(6, 8), 16) / 255;
    return `rgba(${parseInt(s.slice(0, 2), 16)}, ${parseInt(s.slice(2, 4), 16)}, ${parseInt(s.slice(4, 6), 16)}, ${a.toFixed(3)})`;
  };

  // Mirrors LauncherSettings.resolvedTheme(system:)
  function resolveTheme(settings, themes, systemDark) {
    const def = themes.find((t) => t.id === settings.themeId) || themes[0];
    const scheme = settings.appearance === "system" ? (systemDark ? "dark" : "light") : settings.appearance;
    const palette = scheme === "dark" ? def.dark : def.light;
    const pick = (override, base) => (isHex(override) ? hex(override) : hex(base));
    const design = settings.typography.fontDesign === "theme" ? def.fontDesign : settings.typography.fontDesign;
    return {
      id: def.id,
      scheme,
      background: pick(settings.colors.background, palette.background),
      foreground: pick(settings.colors.foreground, palette.foreground),
      secondary: pick(settings.colors.secondary, palette.secondary),
      accent: pick(settings.colors.accent, palette.accent),
      divider: hex(palette.divider),
      design,
      font: FONT_STACKS[design] || FONT_STACKS.system,
    };
  }

  // Mirrors ClockFormat in ios/Shared/Formatting.swift
  const pad2 = (n) => String(n).padStart(2, "0");
  function formatTime(date, use24) {
    return use24 ? `${pad2(date.getHours())}:${pad2(date.getMinutes())}` : `${date.getHours() % 12 || 12}:${pad2(date.getMinutes())}`;
  }
  function formatDate(date, style) {
    const part = (opts) => new Intl.DateTimeFormat(undefined, opts).format(date);
    if (style === "short") return `${part({ weekday: "short" })} ${date.getDate()} ${part({ month: "short" })}`;
    if (style === "numeric") return `${pad2(date.getDate())}.${pad2(date.getMonth() + 1)}.${pad2(date.getFullYear() % 100)}`;
    return `${part({ weekday: "long" })}, ${date.getDate()} ${part({ month: "long" })}`;
  }
  function applyCase(text, mode) {
    if (mode === "lower") return text.toLowerCase();
    if (mode === "upper") return text.toUpperCase();
    return text;
  }

  function visibleShortcuts(s) {
    return s.shortcuts.filter((x) => x.visible && x.name.trim() !== "");
  }

  function hasValidURL(sc) {
    return /^[a-z][a-z0-9+.-]*:/i.test((sc.url || "").trim());
  }

  const line = (extra) => Object.assign({ whiteSpace: "nowrap", overflow: "hidden", textOverflow: "ellipsis", maxWidth: "100%", lineHeight: "1.2" }, extra);

  // ClockText
  function clock(date, s, t, size) {
    return el("div", line({
      fontFamily: t.font, fontSize: size + "px", fontWeight: WEIGHTS[s.typography.clockWeight],
      letterSpacing: size * METRICS.clockTracking + "px", color: t.foreground, fontVariantNumeric: "tabular-nums",
      overflow: "visible",
    }), formatTime(date, s.header.use24Hour));
  }

  // DateLine
  function dateLine(date, s, t) {
    return el("div", { display: "flex", alignItems: "center", gap: "6px", maxWidth: "100%" }, [
      s.header.showAccentDot && el("span", { width: METRICS.dotSize + "px", height: METRICS.dotSize + "px", borderRadius: "50%", background: t.accent, flex: "none" }),
      el("span", line({ fontFamily: t.font, fontSize: s.typography.metaSize + "px", letterSpacing: METRICS.metaTracking + "px", color: t.secondary }),
        applyCase(formatDate(date, s.header.dateStyle), s.typography.labelCase)),
    ]);
  }

  // HeaderBlock
  function header(date, s, t, o) {
    const a = ALIGN[s.layout.alignment];
    const showMotto = o.showMotto && s.header.motto.trim() !== "";
    return el("div", { display: "flex", flexDirection: "column", alignItems: a.items, gap: METRICS.headerSpacing + "px", textAlign: a.text, maxWidth: "100%" }, [
      o.showClock && clock(date, s, t, o.clockSize),
      o.showDate && dateLine(date, s, t),
      showMotto && el("div", {
        fontFamily: t.font, fontSize: s.typography.metaSize + "px", letterSpacing: METRICS.metaTracking + "px",
        color: t.secondary, marginTop: "2px", lineHeight: "1.2", display: "-webkit-box", WebkitLineClamp: "2", WebkitBoxOrient: "vertical", overflow: "hidden",
      }, s.header.motto),
    ]);
  }

  // ShortcutLabel / ShortcutList
  function shortcutLabel(sc, s, t, size) {
    return el("div", line({
      fontFamily: t.font, fontSize: size + "px", fontWeight: WEIGHTS[s.typography.labelWeight],
      letterSpacing: s.typography.tracking + "px", color: t.foreground, opacity: hasValidURL(sc) ? "1" : "0.35",
    }), applyCase(sc.name, s.typography.labelCase));
  }

  function shortcutList(list, s, t, size, spacing) {
    const a = ALIGN[s.layout.alignment];
    return el("div", { display: "flex", flexDirection: "column", alignItems: a.items, gap: spacing + "px", textAlign: a.text, maxWidth: "100%" },
      list.map((sc) => {
        const label = shortcutLabel(sc, s, t, size);
        label.title = sc.url || "(no URL)";
        return label;
      }));
  }

  // WidgetLayoutView
  function widget(family, s, t, date) {
    const size = WIDGET_SIZES[family];
    const w = s.widget;
    const a = ALIGN[s.layout.alignment];
    const pad = METRICS.widgetPadding;
    const spacing = s.layout.itemSpacing * METRICS.widgetSpacingScale;
    const innerH = size.h - pad * 2;
    const mottoOn = w.showMotto && s.header.motto !== "";
    const hasHeader = w.showClock || w.showDate || mottoOn;
    const visible = visibleShortcuts(s);
    const head = () => header(date, s, t, { clockSize: w.clockSize, showClock: w.showClock, showDate: w.showDate, showMotto: w.showMotto });

    const rowsThatFit = (height) => {
      const lineH = w.labelSize * METRICS.lineHeight;
      return Math.max(0, Math.min(Math.floor((height + spacing) / (lineH + spacing)), size.max));
    };
    const headerHeight = () => {
      const meta = s.typography.metaSize * METRICS.lineHeight;
      const parts = [];
      if (w.showClock) parts.push(w.clockSize * 1.2);
      if (w.showDate) parts.push(meta);
      if (mottoOn) parts.push(meta + 2);
      return parts.length ? parts.reduce((x, y) => x + y, 0) + (parts.length - 1) * METRICS.headerSpacing : 0;
    };
    const list = (count) => shortcutList(visible.slice(0, count), s, t, w.labelSize, spacing);

    let content;
    if (family === "small") {
      content = el("div", { display: "flex", flexDirection: "column", alignItems: a.items, height: "100%" }, [
        hasHeader && head(),
        el("div", { flex: "1" }),
        visible[0] && shortcutLabel(visible[0], s, t, w.labelSize),
      ]);
    } else if (family === "medium") {
      const col = (justify, child) => el("div", { flex: "1 1 0", minWidth: "0", height: "100%", display: "flex", flexDirection: "column", alignItems: a.items, justifyContent: justify }, [child]);
      content = el("div", { display: "flex", gap: METRICS.widgetColumnSpacing + "px", height: "100%" }, [
        hasHeader && col("flex-start", head()),
        col(hasHeader ? "flex-end" : "center", list(rowsThatFit(innerH))),
      ]);
    } else {
      const headerSpace = hasHeader ? headerHeight() + 16 : 0;
      content = el("div", { display: "flex", flexDirection: "column", alignItems: a.items, height: "100%" }, [
        hasHeader && head(),
        el("div", { flex: "1", minHeight: hasHeader ? "16px" : "0" }),
        list(rowsThatFit(innerH - headerSpace)),
      ]);
    }

    return el("div", {
      width: size.w + "px", height: size.h + "px", padding: pad + "px", boxSizing: "border-box",
      background: t.background, borderRadius: "22px", overflow: "hidden", textAlign: a.text, flex: "none",
    }, [content]);
  }

  // HomeView (the app's own launcher page), without the tab bar.
  function home(s, t, date) {
    const a = ALIGN[s.layout.alignment];
    return el("div", {
      display: "flex", flexDirection: "column", alignItems: a.items, textAlign: a.text,
      padding: `40px ${s.layout.padding}px 24px`, boxSizing: "border-box", height: "100%", overflow: "hidden",
    }, [
      header(date, s, t, { clockSize: s.typography.clockSize, showClock: s.header.showClock, showDate: s.header.showDate, showMotto: s.header.showMotto }),
      el("div", { flex: "1", minHeight: "32px" }),
      el("div", { width: "100%", display: "flex", flexDirection: "column", alignItems: a.items, overflow: "hidden" }, [
        shortcutList(visibleShortcuts(s), s, t, s.typography.labelSize, s.layout.itemSpacing),
      ]),
    ]);
  }

  // RootView's TabBar
  function tabBar(t, active) {
    return el("div", { display: "flex", justifyContent: "center", gap: "32px", paddingTop: "10px" },
      ["home", "widget", "settings"].map((name) =>
        el("div", { display: "flex", flexDirection: "column", alignItems: "center", gap: "6px", padding: "6px 0" }, [
          el("span", { fontFamily: t.font, fontSize: "14px", letterSpacing: "0.6px", color: name === active ? t.foreground : t.secondary }, name),
          el("span", { width: "4px", height: "4px", borderRadius: "50%", background: t.accent, opacity: name === active ? "1" : "0" }),
        ])));
  }

  window.MarginRender = { METRICS, WIDGET_SIZES, FONT_STACKS, WEIGHTS, el, resolveTheme, formatTime, formatDate, applyCase, visibleShortcuts, widget, home, tabBar, hex, isHex };
})();
