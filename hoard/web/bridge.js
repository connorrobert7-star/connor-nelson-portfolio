// Hoard's in-page backend: the real Python engine (backend/core/engine.py) running
// under Pyodide, so the browser demo plays exactly like the desktop game.
// Godot calls window.hoard.handle(method, path, queryJson, bodyJson, callback).
// The save is the SQLite database itself, kept in this browser's IndexedDB.
(() => {
  // Artifacts only serve web file types, so big binaries ship gzipped under .wasm
  // names (see tools/build_web.py). Map the runtime's requests onto those files.
  const FILES = window.HOARD_FILES || {};
  const realFetch = window.fetch.bind(window);
  window.fetch = (input, init) => {
    const url = String(input instanceof Request ? input.url : input).split("?")[0];
    for (const [suffix, spec] of Object.entries(FILES)) {
      if (!url.endsWith(suffix)) continue;
      const clean = { ...(init || {}) };
      delete clean.integrity; // the bytes on the wire are gzipped
      return realFetch(spec.file, clean).then((res) => {
        if (!res.ok || !spec.gz) return res;
        const body = res.body.pipeThrough(new DecompressionStream("gzip"));
        return new Response(body, { status: 200, headers: { "Content-Type": spec.type || "application/octet-stream" } });
      });
    }
    return realFetch(input, init);
  };

  const DB_NAME = "hoard";
  const STORE = "saves";
  const KEY = "main";

  function idb() {
    return new Promise((resolve, reject) => {
      const req = indexedDB.open(DB_NAME, 1);
      req.onupgradeneeded = () => req.result.createObjectStore(STORE);
      req.onsuccess = () => resolve(req.result);
      req.onerror = () => reject(req.error);
    });
  }

  async function loadSave() {
    try {
      const db = await idb();
      return await new Promise((resolve) => {
        const req = db.transaction(STORE).objectStore(STORE).get(KEY);
        req.onsuccess = () => resolve(req.result || null);
        req.onerror = () => resolve(null);
      });
    } catch (e) {
      return null; // private window or storage blocked: play without a save
    }
  }

  async function writeSave(bytes) {
    try {
      const db = await idb();
      db.transaction(STORE, "readwrite").objectStore(STORE).put(bytes, KEY);
    } catch (e) {
      /* storage blocked; the run continues unsaved */
    }
  }

  async function clearSave() {
    try {
      const db = await idb();
      await new Promise((resolve) => {
        const tx = db.transaction(STORE, "readwrite");
        tx.objectStore(STORE).delete(KEY);
        tx.oncomplete = resolve;
        tx.onerror = resolve;
      });
    } catch (e) {
      /* nothing to clear */
    }
  }

  let ready = null;
  let savedChanges = -1;

  async function boot(onStatus) {
    onStatus("Waking the village engine...");
    const py = await loadPyodide({
      indexURL: "./py/",
      stdLibURL: "./py/python_stdlib.zip",
      lockFileURL: "./py/pyodide-lock.json",
      fullStdLib: false,
    });
    await py.loadPackage("sqlite3");
    onStatus("Reading the village's books...");
    const bundle = await (await fetch("hoard-py.json")).json();
    for (const [path, text] of Object.entries(bundle)) {
      const full = "/hoard/" + path;
      const dir = full.slice(0, full.lastIndexOf("/"));
      py.FS.mkdirTree(dir);
      py.FS.writeFile(full, text);
    }
    const saved = await loadSave();
    py.globals.set("SAVE", saved);
    py.runPython(`
import sys
sys.path.insert(0, "/hoard")
from backend.core.engine import Engine
engine = Engine(":memory:")
if SAVE is not None:
    engine.import_db(bytes(SAVE.to_py()))
del SAVE
`);
    return py;
  }

  window.hoard = {
    start(onStatus = () => {}) {
      if (!ready) ready = boot(onStatus);
      return ready;
    },
    async reset() {
      await clearSave();
    },
    handle(method, path, queryJson, bodyJson, callback) {
      this.start()
        .then(async (py) => {
          const out = py.globals.get("engine").handle_json(method, path, queryJson, bodyJson);
          callback(out);
          const changes = py.runPython("engine.conn.total_changes");
          if (changes !== savedChanges) {
            savedChanges = changes;
            await writeSave(py.runPython("engine.export_db()").toJs());
          }
        })
        .catch((e) => callback(JSON.stringify({ status: 500, body: { detail: "Engine error: " + e } })));
    },
  };
})();
