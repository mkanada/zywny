// Harness CDP (Chromium headless, Node >= 22): abre o build/web, injeta um Web
// MIDI falso e deixa dirigir o app. Usado por smoke.mjs.
import { spawn } from 'node:child_process';
import fs from 'node:fs';

export const SHOTS = process.env.SHOTS_DIR ?? '/tmp/';

export function fakeMidiScript({ perm = 'prompt', support = true, deny = false }) {
  return `(() => {
  window.__log = [];
  window.__reqOptions = [];
  if (!${support}) { delete Navigator.prototype.requestMIDIAccess; return; }
  const mk = (type, id, name) => ({ id, name, manufacturer: 'Fake', type, version: '1', state: 'connected',
    connection: 'closed', onmidimessage: null, onstatechange: null,
    open() { this.connection = 'open'; window.__log.push('open ' + type + ' ' + name); return Promise.resolve(this); },
    close() { this.connection = 'closed'; return Promise.resolve(this); },
    send(data, ts) { window.__log.push('send ' + JSON.stringify(Array.from(data)) + ' ts=' + ts + ' now=' + performance.now().toFixed(1)); },
    addEventListener() {}, removeEventListener() {} });
  const input = mk('input', 'in-1', 'Fake Piano');
  const output = mk('output', 'out-1', 'Fake Piano');
  const access = { inputs: new Map([[input.id, input]]), outputs: new Map([[output.id, output]]),
    onstatechange: null, sysexEnabled: false };
  window.__fakeAccess = access;
  window.__fire = (a, b, c) => {
    const ev = new Event('midimessage'); ev.data = new Uint8Array([a, b, c]);
    Object.defineProperty(ev, 'timeStamp', { value: performance.now() });
    window.__log.push('fire ' + [a,b,c] + ' now=' + performance.now().toFixed(1));
    if (input.onmidimessage) input.onmidimessage(ev);
  };
  window.__perm = ${JSON.stringify(perm)};
  navigator.requestMIDIAccess = async function (o) {
    window.__reqOptions.push(JSON.stringify(o));
    if (${deny}) throw new DOMException('denied', 'SecurityError');
    window.__perm = 'granted';
    return access;
  };
  Object.defineProperty(navigator, 'permissions', { value: { query: async (d) => {
    window.__log.push('perm.query ' + JSON.stringify(d)); return { state: window.__perm }; } }, configurable: true });
})();`;
}

export async function launch(port = 9333) {
  const prof = fs.mkdtempSync('/tmp/zy-prof-');
  const proc = spawn('chromium-browser', ['--headless=new', `--remote-debugging-port=${port}`,
    '--window-size=1100,800', `--user-data-dir=${prof}`, '--no-first-run', '--autoplay-policy=no-user-gesture-required', '--disable-gpu-sandbox',
    '--enable-unsafe-swiftshader', 'about:blank'], { stdio: 'ignore' });
  for (let i = 0; i < 50; i++) {
    try { const r = await fetch(`http://127.0.0.1:${port}/json/version`); if (r.ok) break; } catch {}
    await new Promise(r => setTimeout(r, 200));
  }
  const targets = await (await fetch(`http://127.0.0.1:${port}/json`)).json();
  const page = targets.find(t => t.type === 'page');
  const ws = new WebSocket(page.webSocketDebuggerUrl);
  await new Promise(r => ws.addEventListener('open', r));
  let id = 0; const waiting = new Map(); const events = [];
  ws.addEventListener('message', m => {
    const msg = JSON.parse(m.data);
    if (msg.id && waiting.has(msg.id)) { waiting.get(msg.id)(msg); waiting.delete(msg.id); }
    else events.push(msg);
  });
  const send = (method, params = {}) => new Promise((res, rej) => {
    const i = ++id; waiting.set(i, m => m.error ? rej(new Error(JSON.stringify(m.error))) : res(m.result));
    ws.send(JSON.stringify({ id: i, method, params }));
  });
  const evalJs = async (expr) => {
    const r = await send('Runtime.evaluate', { expression: expr, awaitPromise: true, returnByValue: true });
    if (r.exceptionDetails) throw new Error(JSON.stringify(r.exceptionDetails));
    return r.result.value;
  };
  const shot = async (name) => {
    const r = await send('Page.captureScreenshot', { format: 'png' });
    fs.writeFileSync(SHOTS + name + '.png', Buffer.from(r.data, 'base64'));
  };
  const click = async (x, y) => {
    for (const type of ['mouseMoved', 'mousePressed', 'mouseReleased'])
      await send('Input.dispatchMouseEvent', { type, x, y, button: 'left', clickCount: 1, buttons: type === 'mousePressed' ? 1 : 0 });
  };
  await send('Page.enable'); await send('Runtime.enable');
  const close = () => { try { ws.close(); } catch {} proc.kill(); };
  return { send, evalJs, shot, click, events, close };
}

export const sleep = (ms) => new Promise(r => setTimeout(r, ms));

// Liga a semântica do Flutter e devolve os nós com rótulo: {label, x, y} (centro).
export async function semantics(b) {
  await b.evalJs(`(() => { const p = document.querySelector('flt-semantics-placeholder'); if (p) p.click(); })()`);
  await new Promise(r => setTimeout(r, 800));
  return JSON.parse(await b.evalJs(`JSON.stringify([...document.querySelectorAll('flt-semantics')]
    .map(e => { const r = e.getBoundingClientRect(); return { label: e.getAttribute('aria-label') || e.textContent.slice(0,40), role: e.getAttribute('role'), x: Math.round(r.x + r.width/2), y: Math.round(r.y + r.height/2), w: Math.round(r.width) }; })
    .filter(n => n.label && n.w > 0))`));
}
