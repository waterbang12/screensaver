#!/usr/bin/env node
// Draws the 1024×1024 app icon (black, three white text-lines, a red dot) and
// writes it as a PNG with no dependencies. Run once; the output is committed.

import { writeFileSync } from "node:fs";
import { deflateSync, crc32 } from "node:zlib";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const SIZE = 1024;
const OUT = join(dirname(fileURLToPath(import.meta.url)), "..", "ios/App/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png");

// Shapes as signed-distance functions; coverage gives smooth edges.
const capsule = (x1, x2, y, r) => (px, py) => {
  const cx = Math.max(x1, Math.min(x2, px));
  return Math.hypot(px - cx, py - y) - r;
};
const circle = (cx, cy, r) => (px, py) => Math.hypot(px - cx, py - cy) - r;

const shapes = [
  { sdf: capsule(250, 640, 470, 15), color: [255, 255, 255] },
  { sdf: capsule(250, 540, 560, 15), color: [255, 255, 255] },
  { sdf: capsule(250, 700, 650, 15), color: [255, 255, 255] },
  { sdf: circle(770, 300, 34), color: [215, 25, 33] },
];

const rowBytes = SIZE * 3 + 1;
const raw = Buffer.alloc(rowBytes * SIZE);
for (let y = 0; y < SIZE; y++) {
  raw[y * rowBytes] = 0; // filter: none
  for (let x = 0; x < SIZE; x++) {
    let rgb = [0, 0, 0];
    for (const s of shapes) {
      const cover = Math.max(0, Math.min(1, 0.5 - s.sdf(x + 0.5, y + 0.5)));
      if (cover > 0) rgb = rgb.map((c, i) => c + (s.color[i] - c) * cover);
    }
    const o = y * rowBytes + 1 + x * 3;
    raw[o] = Math.round(rgb[0]);
    raw[o + 1] = Math.round(rgb[1]);
    raw[o + 2] = Math.round(rgb[2]);
  }
}

function chunk(type, data) {
  const len = Buffer.alloc(4);
  len.writeUInt32BE(data.length);
  const body = Buffer.concat([Buffer.from(type, "ascii"), data]);
  const crc = Buffer.alloc(4);
  crc.writeUInt32BE(crc32(body) >>> 0);
  return Buffer.concat([len, body, crc]);
}

const ihdr = Buffer.alloc(13);
ihdr.writeUInt32BE(SIZE, 0);
ihdr.writeUInt32BE(SIZE, 4);
ihdr[8] = 8;  // bit depth
ihdr[9] = 2;  // colour type: RGB (no alpha, as App Store icons require)
const png = Buffer.concat([
  Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]),
  chunk("IHDR", ihdr),
  chunk("IDAT", deflateSync(raw, { level: 9 })),
  chunk("IEND", Buffer.alloc(0)),
]);
writeFileSync(OUT, png);
console.log(`Wrote ${OUT} (${png.length} bytes)`);
