#!/usr/bin/env node
// Checks that run without a Mac. They catch the mistakes most likely to break
// the iOS build or make the browser preview drift from the app:
//   - generated files are up to date with shared/*.json
//   - shared/defaults.json and themes.json match the Swift Codable structs
//     (a mismatch would crash the app at launch: LauncherSettings.defaults)
//   - enum values, hex colours, text contrast, preset URLs
//   - App Group id identical in entitlements, Info.plist and code
//   - layout constants identical in Swift and preview/render.js
//   - preview JS parses; Swift files have balanced brackets
// This is not a Swift compiler. Only the GitHub Actions build proves the app compiles.

import { readFileSync, readdirSync, statSync } from "node:fs";
import { join, relative } from "node:path";
import { spawnSync } from "node:child_process";
import { ROOT, readJSON, parseSwiftEnums, sync } from "./sync-shared.mjs";

const errors = [];
const warnings = [];
const fail = (msg) => errors.push(msg);
const warn = (msg) => warnings.push(msg);
const read = (rel) => readFileSync(join(ROOT, rel), "utf8");

// 1. Generated files
try {
  const stale = sync({ check: true });
  if (stale.length) fail(`Generated files out of date: ${stale.join(", ")} — run: node scripts/sync-shared.mjs`);
} catch (err) {
  fail(err.message);
}

// 2. Swift model vs JSON
const swiftSources = ["ios/Shared/Models.swift", "ios/Shared/Theme.swift"].map(read).join("\n");
const enums = parseSwiftEnums(swiftSources);
const structs = {};
for (const m of swiftSources.matchAll(/^(?:private\s+)?struct\s+(\w+)\s*:\s*Codable\b[^{]*\{([\s\S]*?)\n\}/gm)) {
  const fields = {};
  for (const f of m[2].matchAll(/^\s{4}var\s+(\w+)\s*:\s*([\w\[\]?]+)\s*$/gm)) fields[f[1]] = f[2];
  structs[m[1]] = fields;
}

function validate(value, type, path) {
  if (type.endsWith("?")) {
    if (value === undefined || value === null) return;
    type = type.slice(0, -1);
  }
  if (value === undefined) return fail(`${path}: missing (Swift expects ${type})`);
  const arr = type.match(/^\[(\w+)\]$/);
  if (arr) {
    if (!Array.isArray(value)) return fail(`${path}: expected array`);
    value.forEach((v, i) => validate(v, arr[1], `${path}[${i}]`));
    return;
  }
  switch (type) {
    case "String": if (typeof value !== "string") fail(`${path}: expected string`); return;
    case "Bool": if (typeof value !== "boolean") fail(`${path}: expected boolean`); return;
    case "Int": if (!Number.isInteger(value)) fail(`${path}: expected integer`); return;
    case "Double": if (typeof value !== "number") fail(`${path}: expected number`); return;
  }
  if (enums[type]) {
    if (!enums[type].includes(value)) fail(`${path}: "${value}" is not a ${type} (${enums[type].join(", ")})`);
    return;
  }
  const fields = structs[type];
  if (!fields) return fail(`${path}: checker does not know Swift type ${type}`);
  if (typeof value !== "object" || value === null || Array.isArray(value)) return fail(`${path}: expected object`);
  for (const [name, t] of Object.entries(fields)) validate(value[name], t, `${path}.${name}`);
  for (const key of Object.keys(value)) if (!(key in fields)) warn(`${path}.${key}: not in Swift ${type}; ignored by the app`);
}

const defaults = readJSON("shared/defaults.json");
const themes = readJSON("shared/themes.json");
const presets = readJSON("shared/presets.json");
if (!structs.LauncherSettings) fail("Could not find struct LauncherSettings in Swift sources");
else validate(defaults, "LauncherSettings", "defaults");
themes.themes.forEach((t, i) => validate(t, "ThemeDefinition", `themes[${i}]`));
presets.presets.forEach((p, i) => validate(p, "ShortcutPreset", `presets[${i}]`));

const ids = defaults.shortcuts.map((s) => s.id);
if (new Set(ids).size !== ids.length) fail("defaults.shortcuts: duplicate ids");
if (!themes.themes.some((t) => t.id === defaults.themeId)) fail(`defaults.themeId "${defaults.themeId}" is not a theme`);

// 3. Colours and contrast (WCAG relative luminance)
const HEX = /^#[0-9A-Fa-f]{6}$/;
const lum = (hex) => {
  const c = [1, 3, 5].map((i) => parseInt(hex.slice(i, i + 2), 16) / 255).map((v) => (v <= 0.03928 ? v / 12.92 : ((v + 0.055) / 1.055) ** 2.4));
  return 0.2126 * c[0] + 0.7152 * c[1] + 0.0722 * c[2];
};
const contrast = (a, b) => { const [x, y] = [lum(a), lum(b)].sort((m, n) => n - m); return (x + 0.05) / (y + 0.05); };
for (const t of themes.themes) {
  for (const mode of ["dark", "light"]) {
    const p = t[mode];
    for (const [k, v] of Object.entries(p)) if (!HEX.test(v)) fail(`themes.${t.id}.${mode}.${k}: "${v}" is not #RRGGBB`);
    if (Object.values(p).every((v) => HEX.test(v))) {
      const main = contrast(p.foreground, p.background);
      const sec = contrast(p.secondary, p.background);
      if (main < 7) fail(`themes.${t.id}.${mode}: text contrast ${main.toFixed(1)}:1 is below 7:1`);
      if (sec < 3.5) warn(`themes.${t.id}.${mode}: secondary contrast ${sec.toFixed(1)}:1 is below 3.5:1`);
    }
  }
}
for (const [k, v] of Object.entries(defaults.colors)) if (v !== "" && !HEX.test(v)) fail(`defaults.colors.${k}: "${v}" must be "" or #RRGGBB`);

// 4. URLs
const SCHEME = /^[a-z][a-z0-9+.-]*:/i;
for (const p of presets.presets) if (!SCHEME.test(p.url)) fail(`presets: "${p.name}" url has no scheme`);
for (const s of defaults.shortcuts) if (!SCHEME.test(s.url)) fail(`defaults.shortcuts: "${s.name}" url has no scheme`);

// 5. Widget theme picker covers every theme
const widgetSrc = read("ios/Widget/MarginWidget.swift");
const themeOption = parseSwiftEnums(widgetSrc).ThemeOption || [];
for (const t of themes.themes) if (!themeOption.includes(t.id)) fail(`ThemeOption in MarginWidget.swift lacks theme "${t.id}"`);
for (const o of themeOption) if (o !== "app" && !themes.themes.some((t) => t.id === o)) fail(`ThemeOption.${o} has no theme in themes.json`);

// 6. App Group id is the same everywhere
const groupIds = {
  "ios/App/Margin.entitlements": [...read("ios/App/Margin.entitlements").matchAll(/<string>(group\.[^<]+)<\/string>/g)].map((m) => m[1]),
  "ios/Widget/MarginWidget.entitlements": [...read("ios/Widget/MarginWidget.entitlements").matchAll(/<string>(group\.[^<]+)<\/string>/g)].map((m) => m[1]),
  "project.yml": [...read("project.yml").matchAll(/MarginAppGroup:\s*(\S+)/g)].map((m) => m[1]),
  "Models.swift": [...read("ios/Shared/Models.swift").matchAll(/fallbackAppGroup\s*=\s*"([^"]+)"/g)].map((m) => m[1]),
};
const allGroups = new Set(Object.values(groupIds).flat());
if (allGroups.size !== 1) fail(`App Group ids differ: ${JSON.stringify(groupIds)}`);
if (groupIds["project.yml"].length !== 2) fail("project.yml should set MarginAppGroup for both the app and the widget");

// 7. Layout constants: Swift vs browser
const swiftMetrics = Object.fromEntries(
  [...read("ios/Shared/LauncherViews.swift").matchAll(/static let (\w+): CGFloat = (-?[\d.]+)/g)].map((m) => [m[1], Number(m[2])]),
);
const jsMetricsMatch = read("preview/render.js").match(/\/\*metrics\*\/(\{.*?\})\/\*end\*\//);
const jsMetrics = jsMetricsMatch ? JSON.parse(jsMetricsMatch[1]) : {};
for (const key of new Set([...Object.keys(swiftMetrics), ...Object.keys(jsMetrics)])) {
  if (swiftMetrics[key] !== jsMetrics[key]) fail(`LayoutMetrics.${key}: Swift ${swiftMetrics[key]} vs preview ${jsMetrics[key]}`);
}

// 8. Preview JS parses
for (const file of ["preview/render.js", "preview/app.js", "preview/live.js", "preview/generated/shared-data.js", "scripts/preview-server.mjs"]) {
  const r = spawnSync(process.execPath, ["--check", join(ROOT, file)], { encoding: "utf8" });
  if (r.status !== 0) fail(`${file}: syntax error\n${r.stderr}`);
}

// 9. Swift bracket balance (cheap typo catch; ignores strings and comments)
function swiftFiles(dir) {
  return readdirSync(dir).flatMap((name) => {
    const full = join(dir, name);
    return statSync(full).isDirectory() ? swiftFiles(full) : name.endsWith(".swift") ? [full] : [];
  });
}
for (const file of swiftFiles(join(ROOT, "ios"))) {
  const src = readFileSync(file, "utf8");
  const stack = [];
  const pairs = { ")": "(", "]": "[", "}": "{" };
  let i = 0;
  let line = 1;
  let bad = null;
  while (i < src.length && !bad) {
    const ch = src[i];
    if (ch === "\n") { line++; i++; continue; }
    if (src.startsWith("//", i)) { i = src.indexOf("\n", i); if (i < 0) break; continue; }
    if (src.startsWith("/*", i)) { const end = src.indexOf("*/", i + 2); line += src.slice(i, end).split("\n").length - 1; i = end + 2; continue; }
    if (src.startsWith('#"""', i)) { const end = src.indexOf('"""#', i + 4); line += src.slice(i, end).split("\n").length - 1; i = end + 4; continue; }
    if (src.startsWith('"""', i)) { const end = src.indexOf('"""', i + 3); line += src.slice(i, end).split("\n").length - 1; i = end + 3; continue; }
    if (src.startsWith('#"', i)) { i = src.indexOf('"#', i + 2) + 2; continue; }
    if (ch === '"') {
      // Skip a string, including \( ... ) interpolations.
      i++;
      let depth = 0;
      while (i < src.length) {
        if (src[i] === "\\" && src[i + 1] === "(") { depth++; i += 2; continue; }
        if (src[i] === "\\") { i += 2; continue; }
        if (depth > 0 && src[i] === "(") depth++;
        else if (depth > 0 && src[i] === ")") depth--;
        else if (depth === 0 && src[i] === '"') break;
        else if (src[i] === "\n") { bad = `unterminated string at line ${line}`; break; }
        i++;
      }
      i++;
      continue;
    }
    if ("([{".includes(ch)) stack.push([ch, line]);
    else if (")]}".includes(ch)) {
      const top = stack.pop();
      if (!top || top[0] !== pairs[ch]) bad = `unexpected "${ch}" at line ${line}`;
    }
    i++;
  }
  if (!bad && stack.length) bad = `unclosed "${stack.at(-1)[0]}" from line ${stack.at(-1)[1]}`;
  if (bad) fail(`${relative(ROOT, file)}: ${bad}`);
}

// Report
for (const w of warnings) console.log(`warning: ${w}`);
if (errors.length) {
  for (const e of errors) console.error(`error: ${e}`);
  console.error(`\n${errors.length} check(s) failed.`);
  process.exit(1);
}
console.log(`All checks passed (${warnings.length} warning${warnings.length === 1 ? "" : "s"}).`);
