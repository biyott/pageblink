// PageBlink PDF recovery: page image preprocessing, off the UI thread.
//
// In:  {id, bgra: ArrayBuffer (transferred), w, h}   BGRA8888 as PDFium renders it
// Out: {id, ok: true, bmp: ArrayBuffer (transferred), w, h, regions, multi, skew}
//      {id, ok: false, error}
//
// Recipe (design 032 section 3.4): grayscale, tilt correction only when the
// estimated tilt is >= 1 degree, background flattening, optional column split.
// No binarization, no upscaling (both measured worse).
'use strict';

const MIN_SKEW_DEG = 1;

self.onmessage = (e) => {
  const { id, bgra, w, h } = e.data;
  try {
    reply(run(id, new Uint8Array(bgra), w, h));
  } catch (err) {
    reply({ id, ok: false, error: String((err && err.message) || err) });
  }
};

function reply(msg) {
  self.postMessage(msg, msg.bmp ? [msg.bmp] : []);
}

function run(id, bgra, w, h) {
  if (bgra.length < w * h * 4) throw new Error('short pixel buffer');
  let g = new Uint8Array(w * h);
  for (let i = 0, j = 0; j < g.length; i += 4, j++) {
    g[j] = (0.299 * bgra[i + 2] + 0.587 * bgra[i + 1] + 0.114 * bgra[i]) | 0;
  }
  const skew = estimateSkew(g, w, h);
  if (Math.abs(skew) >= MIN_SKEW_DEG) g = rotate(g, w, h, skew);
  flatten(g, w, h);
  const found = findRegions(g, w, h);
  return {
    id,
    ok: true,
    bmp: encodeBmp(g, w, h),
    w,
    h,
    regions: found.regions,
    multi: found.multi,
    skew,
  };
}

// ---- helpers -------------------------------------------------------------

/** Area-average downscale of a gray image to width tw. */
function shrink(g, w, h, tw) {
  const f = w / tw;
  const th = Math.max(1, Math.round(h / f));
  const out = new Uint8Array(tw * th);
  for (let y = 0; y < th; y++) {
    const y0 = Math.floor(y * f), y1 = Math.min(h, Math.max(y0 + 1, Math.floor((y + 1) * f)));
    for (let x = 0; x < tw; x++) {
      const x0 = Math.floor(x * f), x1 = Math.min(w, Math.max(x0 + 1, Math.floor((x + 1) * f)));
      let s = 0;
      for (let yy = y0; yy < y1; yy++) {
        const row = yy * w;
        for (let xx = x0; xx < x1; xx++) s += g[row + xx];
      }
      out[y * tw + x] = (s / ((y1 - y0) * (x1 - x0))) | 0;
    }
  }
  return { g: out, w: tw, h: th, f };
}

function box3(g, w, h) {
  const out = new Uint8Array(w * h).fill(255);
  for (let y = 1; y < h - 1; y++) {
    for (let x = 1; x < w - 1; x++) {
      let s = 0;
      for (let dy = -1; dy <= 1; dy++) for (let dx = -1; dx <= 1; dx++) s += g[(y + dy) * w + x + dx];
      out[y * w + x] = (s / 9) | 0;
    }
  }
  return out;
}

function otsu(g) {
  const hist = new Array(256).fill(0);
  for (let i = 0; i < g.length; i++) hist[g[i]]++;
  const n = g.length;
  let sum = 0;
  for (let i = 0; i < 256; i++) sum += i * hist[i];
  let sb = 0, wb = 0, mx = 0, th = 127;
  for (let t = 0; t < 256; t++) {
    wb += hist[t];
    if (!wb) continue;
    const wf = n - wb;
    if (!wf) break;
    sb += t * hist[t];
    const mb = sb / wb, mf = (sum - sb) / wf;
    const v = wb * wf * (mb - mf) * (mb - mf);
    if (v > mx) { mx = v; th = t; }
  }
  return th;
}

// ---- tilt ------------------------------------------------------------------

/** Degrees to rotate (clockwise positive) to level the text; 0 when unsure. */
function estimateSkew(gray, w, h, maxDeg = 4, step = 0.25) {
  const s = shrink(gray, w, h, Math.min(700, w));
  const g2 = box3(s.g, s.w, s.h);
  const t = otsu(g2);
  const pts = [];
  for (let y = 0; y < s.h; y++) for (let x = 0; x < s.w; x++) if (g2[y * s.w + x] < t * 0.9) pts.push(x, y);
  if (pts.length < 400) return 0; // blank or nearly blank page: nothing to level
  const rows = s.h * 2;
  // Try small angles first so that a tie keeps the page as it is.
  const angles = [];
  for (let a = -maxDeg; a <= maxDeg + 1e-9; a += step) angles.push(Math.round(a * 100) / 100);
  angles.sort((p, q) => Math.abs(p) - Math.abs(q));
  let best = 0, bv = -1;
  for (const a of angles) {
    const r = (a * Math.PI) / 180, cs = Math.cos(r), sn = Math.sin(r);
    const hist = new Float64Array(rows);
    for (let i = 0; i < pts.length; i += 2) {
      const yy = Math.round(-pts[i] * sn + pts[i + 1] * cs + s.h / 2);
      if (yy >= 0 && yy < rows) hist[yy]++;
    }
    let m = 0;
    for (const v of hist) m += v;
    m /= rows;
    let v2 = 0;
    for (const v of hist) v2 += (v - m) * (v - m);
    if (v2 > bv * 1.0000001) { bv = v2; best = a; }
  }
  return -best;
}

/** Rotates by deg degrees (clockwise positive) about the center; new area is white. */
function rotate(g, w, h, deg) {
  const r = (deg * Math.PI) / 180, cs = Math.cos(r), sn = Math.sin(r);
  const cx = w / 2, cy = h / 2;
  const out = new Uint8Array(w * h);
  for (let y = 0; y < h; y++) {
    const dy = y + 0.5 - cy;
    for (let x = 0; x < w; x++) {
      const dx = x + 0.5 - cx;
      // inverse map: destination -> source
      const sx = cs * dx + sn * dy + cx - 0.5;
      const sy = -sn * dx + cs * dy + cy - 0.5;
      if (sx < 0 || sy < 0 || sx > w - 1 || sy > h - 1) { out[y * w + x] = 255; continue; }
      const x0 = sx | 0, y0 = sy | 0, x1 = Math.min(w - 1, x0 + 1), y1 = Math.min(h - 1, y0 + 1);
      const fx = sx - x0, fy = sy - y0;
      const a = g[y0 * w + x0], b = g[y0 * w + x1], c = g[y1 * w + x0], d = g[y1 * w + x1];
      out[y * w + x] = (a * (1 - fx) * (1 - fy) + b * fx * (1 - fy) + c * (1 - fx) * fy + d * fx * fy + 0.5) | 0;
    }
  }
  return out;
}

// ---- background flattening ---------------------------------------------------

/** Divides by a local background estimate (block max filter + box blur), in place. */
function flatten(g, w, h) {
  const f = 8, R = 3;
  const sw = Math.ceil(w / f), sh = Math.ceil(h / f);
  const bgs = new Float32Array(sw * sh);
  for (let by = 0; by < sh; by++) {
    for (let bx = 0; bx < sw; bx++) {
      let mx = 0;
      for (let y = by * f; y < Math.min(h, by * f + f); y++) {
        for (let x = bx * f; x < Math.min(w, bx * f + f); x++) {
          const v = g[y * w + x];
          if (v > mx) mx = v;
        }
      }
      bgs[by * sw + bx] = mx;
    }
  }
  const tmp = new Float32Array(sw * sh), tmp2 = new Float32Array(sw * sh);
  for (let by = 0; by < sh; by++) {
    for (let bx = 0; bx < sw; bx++) {
      let s = 0, c = 0;
      for (let dx = -R; dx <= R; dx++) {
        const xx = bx + dx;
        if (xx >= 0 && xx < sw) { s += bgs[by * sw + xx]; c++; }
      }
      tmp[by * sw + bx] = s / c;
    }
  }
  for (let by = 0; by < sh; by++) {
    for (let bx = 0; bx < sw; bx++) {
      let s = 0, c = 0;
      for (let dy = -R; dy <= R; dy++) {
        const yy = by + dy;
        if (yy >= 0 && yy < sh) { s += tmp[yy * sw + bx]; c++; }
      }
      tmp2[by * sw + bx] = s / c;
    }
  }
  for (let y = 0; y < h; y++) {
    const by = Math.min(sh - 1, (y / f) | 0);
    for (let x = 0; x < w; x++) {
      const bx = Math.min(sw - 1, (x / f) | 0);
      const b = Math.max(60, tmp2[by * sw + bx]);
      g[y * w + x] = Math.min(255, (g[y * w + x] * 255) / b);
    }
  }
}

// ---- column split (XY-cut) ------------------------------------------------------

/**
 * Finds column regions. A page is split only where a clear gutter separates
 * two text columns; everything else stays one region, so single-column pages,
 * tables and key-value layouts are recognized as before.
 * Returns {regions: [[x0, y0, x1, y1], ...] (full-size pixels), multi: bool}.
 */
function findRegions(gray, w, h) {
  const whole = { regions: [[0, 0, w, h]], multi: false };
  const s = shrink(gray, w, h, 620);
  const tw = s.w, th = s.h, f = 1 / s.f;
  const g2 = box3(s.g, tw, th);
  const RT = Math.max(3, Math.round(0.008 * tw));
  const t = otsu(g2);
  const ink = new Uint8Array(tw * th);
  for (let i = 0; i < ink.length; i++) ink[i] = g2[i] < t * 0.92 ? 1 : 0;
  { // drop table borders and rules: long thin runs
    const LH = Math.round(tw * 0.08), LV = Math.round(th * 0.04);
    const kill = new Uint8Array(tw * th);
    for (let y = 0; y < th; y++) {
      let run = 0;
      for (let x = 0; x <= tw; x++) {
        const d = x < tw && ink[y * tw + x];
        if (d) run++;
        else { if (run >= LH) for (let k = x - run; k < x; k++) kill[y * tw + k] = 1; run = 0; }
      }
    }
    for (let x = 0; x < tw; x++) {
      let run = 0;
      for (let y = 0; y <= th; y++) {
        const d = y < th && ink[y * tw + x];
        if (d) run++;
        else { if (run >= LV) for (let k = y - run; k < y; k++) kill[k * tw + x] = 1; run = 0; }
      }
    }
    for (let i = 0; i < ink.length; i++) if (kill[i]) ink[i] = 0;
  }
  // typical text-line height: median run of consecutive inked rows
  const runs = [];
  { let r = 0;
    for (let y = 0; y < th; y++) {
      let sum = 0;
      for (let x = 0; x < tw; x++) sum += ink[y * tw + x];
      if (sum > RT) r++;
      else { if (r >= 3) runs.push(r); r = 0; }
    }
    if (r >= 3) runs.push(r);
  }
  runs.sort((a, b) => a - b);
  const Lh = runs.length ? runs[Math.floor(runs.length / 2)] : 8;
  const gy = Math.max(5, Math.round(1.5 * Lh)), gx = Math.max(6, Math.round(tw * 0.012));
  let X0 = tw, Y0 = th, X1 = 0, Y1 = 0;
  for (let y = 0; y < th; y++) for (let x = 0; x < tw; x++) if (ink[y * tw + x]) {
    if (x < X0) X0 = x; if (x > X1) X1 = x; if (y < Y0) Y0 = y; if (y > Y1) Y1 = y;
  }
  if (X1 <= X0 || Y1 <= Y0) return whole;
  const rowInk = (y, a, b) => { let sum = 0; for (let x = a; x < b; x++) sum += ink[y * tw + x]; return sum; };
  // 1) horizontal bands, split on blank rows
  const bands = [];
  let start = Y0, blank = 0, last = Y0;
  for (let y = Y0; y <= Y1; y++) {
    if (rowInk(y, X0, X1 + 1) <= RT) blank++;
    else { if (blank >= gy) { bands.push([start, last]); start = y; } blank = 0; last = y; }
  }
  bands.push([start, last]);
  // 2) per band: a vertical gutter between two text columns?
  const out = [];
  for (const [by0, by1] of bands) {
    const bh = by1 - by0 + 1;
    let split = null;
    if (bh >= Lh * 4) {
      const col = new Int32Array(tw);
      let tot = 0;
      for (let y = by0; y <= by1; y++) for (let x = X0; x <= X1; x++) if (ink[y * tw + x]) { col[x]++; tot++; }
      const lo = Math.round(X0 + (X1 - X0) * 0.2), hi = Math.round(X0 + (X1 - X0) * 0.8);
      let best = null, run = 0;
      for (let x = lo; x <= hi + 1; x++) {
        if (x <= hi && col[x] <= Math.max(1, bh * 0.01)) run++;
        else { if (run >= gx && (!best || run > best[1])) best = [x - run, run]; run = 0; }
      }
      if (best) {
        let l = 0, r = 0;
        for (let x = X0; x < best[0]; x++) l += col[x];
        for (let x = best[0] + best[1]; x <= X1; x++) r += col[x];
        if (l > tot * 0.15 && r > tot * 0.15) {
          // each side must look like running text: lines that fill most of the width
          const fill = (a, b) => {
            const ext = [];
            let inL = false, mn = 1e9, mx = -1, rows = 0;
            for (let y = by0; y <= by1 + 1; y++) {
              let sum = 0, lo2 = 1e9, hi2 = -1;
              if (y <= by1) for (let x = a; x < b; x++) if (ink[y * tw + x]) { sum++; if (x < lo2) lo2 = x; if (x > hi2) hi2 = x; }
              if (sum > RT) { inL = true; rows++; if (lo2 < mn) mn = lo2; if (hi2 > mx) mx = hi2; }
              else if (inL) { if (rows >= 3) ext.push((mx - mn) / (b - a)); inL = false; mn = 1e9; mx = -1; rows = 0; }
            }
            ext.sort((p, q) => p - q);
            return { n: ext.length, med: ext.length ? ext[Math.floor(ext.length / 2)] : 0 };
          };
          const fl = fill(X0, best[0]), fr = fill(best[0] + best[1], X1 + 1);
          const wl = (best[0] - X0) / (X1 - X0);
          if (fl.n >= 3 && fr.n >= 3 && fl.med >= 0.55 && fr.med >= 0.5 && wl > 0.3 && wl < 0.7) split = best;
        }
      }
    }
    if (split) out.push({ b: [X0, by0, split[0], by1], col: 1 }, { b: [split[0] + split[1], by0, X1, by1], col: 2 });
    else out.push({ b: [X0, by0, X1, by1], col: 0 });
  }
  // 3) merge consecutive single-column bands
  const merged = [];
  for (const r of out) {
    const p = merged[merged.length - 1];
    if (p && p.col === 0 && r.col === 0) p.b[3] = r.b[3];
    else merged.push({ b: r.b.slice(), col: r.col });
  }
  const multi = merged.some((r) => r.col);
  if (!multi) return whole;
  const pad = Math.round(4 / f);
  const regions = merged.map((r) => [
    Math.max(0, Math.round(r.b[0] / f) - pad),
    Math.max(0, Math.round(r.b[1] / f) - pad),
    Math.min(w, Math.round((r.b[2] + 1) / f) + pad),
    Math.min(h, Math.round((r.b[3] + 1) / f) + pad),
  ]);
  return { regions, multi: true };
}

// ---- BMP (8-bit gray, uncompressed): the simplest image Tesseract decodes -------

function encodeBmp(g, w, h) {
  const rowBytes = (w + 3) & ~3;
  const dataOffset = 14 + 40 + 1024;
  const size = dataOffset + rowBytes * h;
  const buf = new ArrayBuffer(size);
  const v = new DataView(buf);
  const u = new Uint8Array(buf);
  u[0] = 0x42; u[1] = 0x4d;
  v.setUint32(2, size, true);
  v.setUint32(10, dataOffset, true);
  v.setUint32(14, 40, true);
  v.setInt32(18, w, true);
  v.setInt32(22, h, true); // positive: rows stored bottom-up
  v.setUint16(26, 1, true);
  v.setUint16(28, 8, true);
  v.setUint32(34, rowBytes * h, true);
  v.setUint32(46, 256, true);
  for (let i = 0; i < 256; i++) { const o = 54 + i * 4; u[o] = u[o + 1] = u[o + 2] = i; }
  for (let y = 0; y < h; y++) {
    u.set(g.subarray((h - 1 - y) * w, (h - y) * w), dataOffset + y * rowBytes);
  }
  return buf;
}
