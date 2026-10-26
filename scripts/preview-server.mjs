#!/usr/bin/env node
// Zero-dependency dev server for the browser preview.
//  - serves preview/ at http://localhost:5173/
//  - regenerates shared data when shared/*.json or ios/Shared/Models.swift change
//  - tells open pages to reload (Server-Sent Events) after any change
//
//   node scripts/preview-server.mjs [--port 5173] [--open]

import { createServer } from "node:http";
import { readFile, stat } from "node:fs/promises";
import { watch } from "node:fs";
import { join, extname, normalize, sep } from "node:path";
import { exec } from "node:child_process";
import { ROOT, sync } from "./sync-shared.mjs";

const args = process.argv.slice(2);
const portArg = args.indexOf("--port");
const PORT = Number(portArg >= 0 ? args[portArg + 1] : process.env.PORT || 5173);
const PREVIEW = join(ROOT, "preview");

const TYPES = {
  ".html": "text/html; charset=utf-8",
  ".js": "text/javascript; charset=utf-8",
  ".css": "text/css; charset=utf-8",
  ".json": "application/json; charset=utf-8",
  ".png": "image/png",
  ".svg": "image/svg+xml",
};

const clients = new Set();

function regenerate() {
  try {
    const changed = sync();
    if (changed.length) console.log(`  regenerated ${changed.join(", ")}`);
  } catch (err) {
    console.error(`  sync failed: ${err.message}`);
  }
}

const server = createServer(async (req, res) => {
  const url = new URL(req.url, "http://localhost");

  if (url.pathname === "/__events") {
    res.writeHead(200, { "Content-Type": "text/event-stream", "Cache-Control": "no-cache", Connection: "keep-alive" });
    res.write("retry: 1000\n\n");
    clients.add(res);
    req.on("close", () => clients.delete(res));
    return;
  }

  let rel = decodeURIComponent(url.pathname);
  if (rel.endsWith("/")) rel += "index.html";
  const file = normalize(join(PREVIEW, rel));
  if (!file.startsWith(PREVIEW + sep) && file !== PREVIEW) {
    res.writeHead(403).end("Forbidden");
    return;
  }
  try {
    if (!(await stat(file)).isFile()) throw new Error("not a file");
    const body = await readFile(file);
    res.writeHead(200, { "Content-Type": TYPES[extname(file)] || "application/octet-stream", "Cache-Control": "no-store" });
    res.end(body);
  } catch {
    res.writeHead(404, { "Content-Type": "text/plain" }).end("Not found");
  }
});

let timer;
function onChange(dir, filename) {
  if (!filename || filename.includes("generated")) return;
  clearTimeout(timer);
  timer = setTimeout(() => {
    console.log(`  changed: ${dir}/${String(filename).replace(/\\/g, "/")}`);
    if (dir !== "preview") regenerate();
    for (const client of clients) client.write("data: reload\n\n");
  }, 120);
}

for (const dir of ["preview", "shared", "ios/Shared"]) {
  try {
    watch(join(ROOT, dir), { recursive: true }, (_event, filename) => onChange(dir, filename));
  } catch (err) {
    console.warn(`  cannot watch ${dir}: ${err.message}`);
  }
}

regenerate();
server.listen(PORT, "127.0.0.1", () => {
  const address = `http://localhost:${PORT}/`;
  console.log(`Margin design preview: ${address}`);
  console.log("Edit settings in the page, or edit preview/, shared/ or ios/Shared/ files — the page reloads automatically.");
  if (args.includes("--open")) {
    const cmd = process.platform === "win32" ? `start "" "${address}"` : process.platform === "darwin" ? `open ${address}` : `xdg-open ${address}`;
    exec(cmd);
  }
});
