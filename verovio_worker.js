// W02: renders a score to the single-JSON `.vsb` (`-t vsb-json`) inside a Web
// Worker, with the Verovio wasm toolkit that `tool/build_verovio_web.sh`
// copies to web/verovio/ (not versioned). Talks to the toolkit through
// Module.cwrap — the npm VerovioToolkit wrapper doesn't expose
// renderToBridgeJson.
//
// In:  { id, bytes: Uint8Array, options: <JSON string of Verovio options> }
// Out: { id, ok: true, json } | { id, ok: false, error }
importScripts('verovio/verovio-toolkit-hum.js');

const Module = verovio.module;

const ready = new Promise((resolve) => {
  Module.onRuntimeInitialized = () => resolve();
});

let fns = null;
function toolkitFns() {
  if (fns) return fns;
  fns = {
    ctor: Module.cwrap('vrvToolkit_constructor', 'number', []),
    destructor: Module.cwrap('vrvToolkit_destructor', null, ['number']),
    setOptions: Module.cwrap('vrvToolkit_setOptions', 'number', ['number', 'string']),
    loadZipDataBuffer: Module.cwrap('vrvToolkit_loadZipDataBuffer', 'number', ['number', 'number', 'number']),
    loadData: Module.cwrap('vrvToolkit_loadData', 'number', ['number', 'string']),
    renderToBridgeJson: Module.cwrap('vrvToolkit_renderToBridgeJson', 'string', ['number']),
    getLog: Module.cwrap('vrvToolkit_getLog', 'string', ['number']),
  };
  return fns;
}

function render(bytes, optionsJson) {
  const f = toolkitFns();
  const tk = f.ctor();
  try {
    // outputTo must be set BEFORE loading: the bridge's layout defaults (no
    // header, footer or instrument labels) only apply while the output
    // format is already vsb-json, and they affect cast-off. Page size too.
    const options = Object.assign(JSON.parse(optionsJson), { outputTo: 'vsb-json' });
    if (!f.setOptions(tk, JSON.stringify(options))) {
      throw new Error('Verovio rejected the options: ' + f.getLog(tk));
    }
    // Compressed MusicXML (.mxl) is a zip ("PK"); anything else is text.
    const isZip = bytes.length > 1 && bytes[0] === 0x50 && bytes[1] === 0x4b;
    let ok;
    if (isZip) {
      const ptr = Module._malloc(bytes.length);
      Module.HEAPU8.set(bytes, ptr);
      ok = f.loadZipDataBuffer(tk, ptr, bytes.length);
      Module._free(ptr);
    } else {
      ok = f.loadData(tk, new TextDecoder('utf-8').decode(bytes));
    }
    if (!ok) throw new Error('Verovio could not load the score: ' + f.getLog(tk));
    const json = f.renderToBridgeJson(tk);
    if (!json) throw new Error('Verovio could not render: ' + f.getLog(tk));
    return json;
  } finally {
    f.destructor(tk);
  }
}

self.onmessage = async (ev) => {
  const { id, bytes, options } = ev.data;
  try {
    await ready;
    self.postMessage({ id, ok: true, json: render(bytes, options) });
  } catch (e) {
    self.postMessage({ id, ok: false, error: String((e && e.message) || e) });
  }
};
