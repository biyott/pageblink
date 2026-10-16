// PageBlink PDF recovery: the page-side API that lib/features/documents/
// pdf_recovery/ calls. Loaded on demand (never for ordinary text PDFs); it
// pulls in pdf.js (form values) and Tesseract.js (OCR) only when asked.
//
// Everything is self-hosted under this folder; nothing is fetched from a CDN
// and nothing leaves the browser. Results cross to Dart as JSON strings.
//
//   PageBlinkRecovery.loadForms()                     -> Promise<void>
//   PageBlinkRecovery.readForms(bytes, pageNumbers)   -> Promise<string>
//   PageBlinkRecovery.loadOcr(onProgress)             -> Promise<string>
//   PageBlinkRecovery.ocrPage(bgra, width, height)    -> Promise<string>
//   PageBlinkRecovery.abort() / dispose()
(function () {
  'use strict';
  if (window.PageBlinkRecovery) return;

  const BASE = new URL('.', document.currentScript.src).href;
  const TESS = BASE + 'vendor/tesseract-7.0.0/';
  const PDFJS = BASE + 'vendor/pdfjs-6.4.299/';
  const LANG = BASE + 'vendor/tessdata_fast-4.1.0';
  // Per-page ceiling: a stuck recognition cannot be cancelled except by
  // terminating its worker, so a page that takes this long is given up.
  const PAGE_TIMEOUT_MS = 120000;
  // Downloading and starting the engine (about 7 MB) must finish within this.
  const LOAD_TIMEOUT_MS = 180000;
  // Smallest WebAssembly module that uses a SIMD instruction.
  const SIMD_PROBE = new Uint8Array([
    0, 97, 115, 109, 1, 0, 0, 0, 1, 5, 1, 96, 0, 1, 123, 3, 2, 1, 0, 10, 10, 1, 8, 0, 65, 0, 253, 15, 253, 98, 11,
  ]);

  async function retry(fn, tries = 3) {
    let last;
    for (let i = 0; i < tries; i++) {
      try {
        return await fn();
      } catch (e) {
        last = e;
        if (i < tries - 1) await new Promise((r) => setTimeout(r, 400 * (i + 1) ** 2));
      }
    }
    throw last;
  }

  function loadScript(url) {
    return retry(
      () =>
        new Promise((resolve, reject) => {
          const el = document.createElement('script');
          el.src = url;
          el.onload = () => resolve();
          el.onerror = () => {
            el.remove();
            reject(new Error('script load failed: ' + url));
          };
          document.head.appendChild(el);
        }),
    );
  }

  // ---- form values (pdf.js) ---------------------------------------------------

  let pdfjsPromise = null;
  function loadPdfjs() {
    if (!pdfjsPromise) {
      pdfjsPromise = retry(async () => {
        const lib = await import(PDFJS + 'pdf.min.mjs');
        lib.GlobalWorkerOptions.workerSrc = PDFJS + 'pdf.worker.min.mjs';
        return lib;
      }).catch((e) => {
        pdfjsPromise = null;
        throw e;
      });
    }
    return pdfjsPromise;
  }

  const text = (v) => String(v).replace(/\r\n?/g, '\n').trim();

  /** Values of the text and choice fields of the given pages. */
  async function readForms(bytes, pageNumbers) {
    const lib = await loadPdfjs();
    // pdf.js takes ownership of the buffer it is given: give it a copy.
    const task = lib.getDocument({
      data: bytes.slice(),
      isEvalSupported: false,
      enableXfa: false,
      verbosity: 0,
    });
    const doc = await task.promise;
    const out = [];
    try {
      for (const n of pageNumbers) {
        if (n < 1 || n > doc.numPages) continue;
        try {
          const page = await doc.getPage(n);
          const values = [];
          for (const a of await page.getAnnotations()) {
            if (a.subtype !== 'Widget' || a.password) continue;
            if (a.fieldType !== 'Tx' && a.fieldType !== 'Ch') continue;
            const v = Array.isArray(a.fieldValue) ? a.fieldValue.map(text).join(', ') : a.fieldValue;
            if (v != null && text(v)) values.push(text(v));
          }
          page.cleanup();
          out.push({ page: n, values });
        } catch (e) {
          out.push({ page: n, values: [], error: String((e && e.message) || e) });
        }
      }
    } finally {
      await task.destroy();
    }
    return JSON.stringify(out);
  }

  // ---- OCR (Tesseract.js + preprocessing worker) -----------------------------------

  let tess = null; // Tesseract.js worker
  let prep = null; // preprocessing worker
  let loading = null;
  let aborter = null; // rejects the page in flight when abort() is called
  let statedDpi = null; // the resolution last given to Tesseract
  let nextId = 1;
  const waiting = new Map(); // preprocessing requests by id

  function startPrep() {
    const w = new Worker(BASE + 'prep_worker.js');
    w.onmessage = (e) => {
      const p = waiting.get(e.data.id);
      if (!p) return;
      waiting.delete(e.data.id);
      if (e.data.ok) p.resolve(e.data);
      else p.reject(new Error(e.data.error));
    };
    w.onerror = (e) => {
      for (const p of waiting.values()) p.reject(new Error(e.message || 'prep worker failed'));
      waiting.clear();
    };
    return w;
  }

  function prepRun(bgra, w, h) {
    const id = nextId++;
    return new Promise((resolve, reject) => {
      waiting.set(id, { resolve, reject });
      // A copy: the caller's buffer stays valid, the copy moves to the worker.
      const buf = bgra.buffer.slice(bgra.byteOffset, bgra.byteOffset + w * h * 4);
      prep.postMessage({ id, bgra: buf, w, h }, [buf]);
    });
  }

  function killWorkers(reason) {
    if (tess) tess.terminate().catch(() => {});
    if (prep) prep.terminate();
    tess = null;
    prep = null;
    loading = null;
    statedDpi = null;
    for (const p of waiting.values()) p.reject(new Error(reason));
    waiting.clear();
    if (aborter) {
      aborter(new Error(reason));
      aborter = null;
    }
  }

  /** Starts the OCR engine (downloads it on first use). Safe to call again. */
  function loadOcr(onProgress) {
    if (tess && prep) return Promise.resolve(JSON.stringify({ ready: true }));
    if (loading) return loading;
    const report = typeof onProgress === 'function' ? onProgress : () => {};
    let best = 0;
    const logger = (m) => {
      let f = best;
      if (m.status === 'loading tesseract core') f = 0.45 * m.progress;
      else if (m.status === 'loading language traineddata') f = 0.45 + 0.45 * m.progress;
      else if (m.status === 'initializing api' || m.status === 'initializing tesseract') f = 0.9 + 0.1 * m.progress;
      if (f > best) {
        best = f;
        report(f);
      }
    };
    loading = (async () => {
      await retry(() => (window.Tesseract ? Promise.resolve() : loadScript(TESS + 'tesseract.min.js')));
      const simd = WebAssembly.validate(SIMD_PROBE);
      // Tesseract.js only rejects createWorker() when its core fails to load; a
      // missing language file is thrown inside its message handler and the
      // promise never settles. errorHandler turns that into a rejection, and
      // the Worker is caught as it is created (synchronously) so a failed
      // start can be shut down.
      let fail;
      const failed = new Promise((_, reject) => (fail = reject));
      const NativeWorker = window.Worker;
      let spawned = null;
      window.Worker = class extends NativeWorker {
        constructor(...args) {
          super(...args);
          spawned = this;
        }
      };
      let creating;
      try {
        creating = window.Tesseract.createWorker(
          ['kor', 'eng'],
          1, // LSTM only
          {
            workerPath: TESS + 'worker.min.js',
            corePath: TESS + (simd ? 'tesseract-core-simd-lstm.wasm.js' : 'tesseract-core-lstm.wasm.js'),
            langPath: LANG,
            gzip: true,
            cacheMethod: 'write',
            cachePath: 'pageblink-tessdata-fast-4.1.0',
            logger,
            errorHandler: (e) => fail(new Error(String(e))),
          },
          {},
        );
      } finally {
        window.Worker = NativeWorker;
      }
      let timer;
      const timeout = new Promise((_, reject) => {
        timer = setTimeout(() => reject(new Error('timeout loading the OCR engine')), LOAD_TIMEOUT_MS);
      });
      try {
        const worker = await Promise.race([creating, failed, timeout]);
        await worker.setParameters({ tessedit_pageseg_mode: '4' }); // single column
        tess = worker;
      } catch (e) {
        if (spawned) spawned.terminate();
        throw e;
      } finally {
        clearTimeout(timer);
      }
      prep = startPrep();
      report(1);
      return JSON.stringify({ ready: true, core: simd ? 'simd' : 'plain' });
    })().catch((e) => {
      loading = null;
      throw e;
    });
    return loading;
  }

  /**
   * Recognizes one rendered page (BGRA8888) drawn at dpi dots per inch of paper.
   * Resolves to a JSON string.
   */
  async function ocrPage(bgra, w, h, dpi) {
    if (!tess || !prep) throw new Error('OCR engine is not loaded');
    const abort = new Promise((_, reject) => (aborter = reject));
    let timer;
    const timeout = new Promise((_, reject) => {
      timer = setTimeout(() => {
        killWorkers('timeout');
        reject(new Error('timeout'));
      }, PAGE_TIMEOUT_MS);
    });
    try {
      return await Promise.race([work(bgra, w, h, dpi), abort, timeout]);
    } finally {
      clearTimeout(timer);
      aborter = null;
    }
  }

  async function work(bgra, w, h, dpi) {
    const t0 = performance.now();
    // The image carries no resolution; without it Tesseract guesses (and guesses
    // badly on poor scans). Stating the real one is measurably better.
    const want = String(Math.min(600, Math.max(70, Math.round(dpi) || 150)));
    if (statedDpi !== want) {
      await tess.setParameters({ user_defined_dpi: want });
      statedDpi = want;
    }
    const p = await prepRun(bgra, w, h);
    const t1 = performance.now();
    const image = new Uint8Array(p.bmp);
    const lines = [];
    for (let r = 0; r < p.regions.length; r++) {
      const [x0, y0, x1, y1] = p.regions[r];
      const opts = p.multi ? { rectangle: { left: x0, top: y0, width: x1 - x0, height: y1 - y0 } } : {};
      const res = await tess.recognize(image, opts, { text: true, blocks: true });
      for (const b of res.data.blocks || []) {
        for (const para of b.paragraphs) {
          for (const l of para.lines) {
            lines.push({
              r,
              b: [l.bbox.x0, l.bbox.y0, l.bbox.x1, l.bbox.y1],
              c: Math.round(l.confidence),
              w: l.words.map((wd) => ({
                t: wd.text,
                b: [wd.bbox.x0, wd.bbox.y0, wd.bbox.x1, wd.bbox.y1],
                c: Math.round(wd.confidence),
              })),
            });
          }
        }
      }
    }
    return JSON.stringify({
      lines,
      regions: p.regions.length,
      multi: p.multi,
      skew: Math.round(p.skew * 100) / 100,
      w: p.w,
      h: p.h,
      prepMs: Math.round(t1 - t0),
      ocrMs: Math.round(performance.now() - t1),
    });
  }

  window.PageBlinkRecovery = {
    version: 1,
    loadForms: () => loadPdfjs().then(() => undefined),
    readForms,
    loadOcr,
    ocrPage,
    abort: () => killWorkers('aborted'),
    dispose: () => killWorkers('disposed'),
  };
})();
