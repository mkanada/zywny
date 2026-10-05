// Teste de fumaça da versão Web (W03/W04) no Chromium headless:
//   just pacote-hinos && just web-smoke   (ou: flutter build web --release com
//   a chave de keys/ && node tool/web_smoke/smoke.mjs)
// O app não traz música (fase B): o teste instala dist/hinos.zywny pelo seletor
// de arquivos de verdade (o diálogo é interceptado e o arquivo, entregue pelo
// CDP) e confere que a biblioteca fica no IndexedDB depois de recarregar.
// Sobe um servidor para build/web, injeta um teclado Web MIDI falso e confere:
// permissão só no clique (sysex falso), conexão, som do Play, silêncio ao parar,
// monitor MIDI e saída MIDI. Sai com código 1 se algo falhar. Prints em /tmp
// (SHOTS_DIR muda).
import { spawn } from 'node:child_process';
import fs from 'node:fs';
import { launch, fakeMidiScript, sleep, semantics } from './cdp.mjs';

const root = new URL('../../build/web', import.meta.url).pathname;
const pack = new URL('../../dist/hinos.zywny', import.meta.url).pathname;
if (!fs.existsSync(pack)) {
  console.log('FALHA sem dist/hinos.zywny (rode `just pacote-hinos`)');
  process.exit(1);
}
const port = 8099;
const server = spawn('python3', ['-m', 'http.server', String(port), '-d', root], { stdio: 'ignore' });
await sleep(800);

let failed = 0;
const check = (ok, what, extra = '') => {
  console.log(`${ok ? 'ok  ' : 'FALHA'} ${what} ${extra}`);
  if (!ok) failed++;
};

const b = await launch(9334);
try {
  await b.send('Emulation.setDeviceMetricsOverride', { width: 1000, height: 640, deviceScaleFactor: 1, mobile: false });
  await b.send('Page.addScriptToEvaluateOnNewDocument', { source: fakeMidiScript({ perm: 'prompt' }) });
  await b.send('Page.navigate', { url: `http://127.0.0.1:${port}/` });
  await sleep(8000);

  const find = async (re) => {
    const n = (await semantics(b)).find((n) => re.test(n.label));
    if (!n) throw new Error('sem nó na tela: ' + re + '\n  há: ' + (await semantics(b)).map((n) => n.label).join(' | '));
    return n;
  };
  const tap = async (re, wait = 1000) => { const n = await find(re); await b.click(n.x, n.y); await sleep(wait); };
  // O cartão do curso gera vários nós com o mesmo rótulo (semânticas
  // aninhadas); o primeiro pode ser um recorte escondido e o maior, um
  // texto morto. Prefere botão, depois o maior.
  const tapBig = async (re, wait = 1000) => {
    const all = (await semantics(b)).filter((n) => re.test(n.label));
    if (!all.length) throw new Error('sem nó na tela: ' + re);
    const tappable = all.filter((n) => n.role === 'button' || n.role === 'link');
    const pool = tappable.length ? tappable : all;
    const n = pool.reduce((a, c) => (c.w > a.w ? c : a));
    await b.click(n.x, n.y);
    await sleep(wait);
  };
  const peak = (ms = 400) => b.evalJs(`(async()=>{const m=await import('/audio/zywny_audio.js');let p=0;const t=performance.now();while(performance.now()-t<${ms}){p=Math.max(p,m.peak());await new Promise(r=>setTimeout(r,25));}return p})()`);
  const log = async () => JSON.parse(await b.evalJs('JSON.stringify(window.__log)'));

  check((await b.evalJs('window.__reqOptions.length')) === 0, 'MIDI: nenhuma pergunta de permissão na abertura');

  // Sem biblioteca: o cartão ensina a instalar; o seletor entrega o pacote.
  const waitEvent = async (method, ms = 10000) => {
    for (let t = 0; t < ms; t += 100) {
      const i = b.events.findIndex((e) => e.method === method);
      if (i >= 0) return b.events.splice(i, 1)[0];
      await sleep(100);
    }
    throw new Error('sem evento ' + method);
  };
  await b.send('DOM.enable');
  await b.send('Page.setInterceptFileChooserDialog', { enabled: true });
  await find(/Instale uma biblioteca/);
  check(true, 'biblioteca: sem pacote, o cartão de instalar aparece');

  // I13: o curso inicial embutido abre sem biblioteca.
  await find(/Comece pelo curso inicial/);
  check(true, 'cursos: cartão inicial aparece sem biblioteca');
  await tap(/Começar/, 2500);
  await find(/O teclado/);
  check(true, 'cursos: lição 1 abre pelo cartão');
  await b.shot('smoke-curso-licao');
  // Volta à biblioteca recarregando (o "Voltar ao curso" tem vários nós de
  // semântica e o clique pode cair no escondido).
  await b.send('Page.navigate', { url: `http://127.0.0.1:${port}/` });
  await sleep(6000);
  await find(/Instale uma biblioteca/);
  check(true, 'cursos: voltou à biblioteca');

  await tap(/Abrir arquivo/, 100);
  const chooser = await waitEvent('Page.fileChooserOpened');
  await b.send('DOM.setFileInputFiles', { files: [pack], backendNodeId: chooser.params.backendNodeId });
  await sleep(6000); // assinatura + decifrar + gravar no IndexedDB
  await find(/Hinário instalada \(600 hinos\)|600 hinos/);
  check(true, 'biblioteca: instalou pelo seletor e a lista dos 600 hinos apareceu');

  // Recarregar a página: o pacote continua no IndexedDB.
  await b.send('Page.reload');
  await sleep(8000);
  await find(/600 hinos/);
  check(true, 'biblioteca: depois de recarregar, os hinos continuam lá (IndexedDB)');
  await b.send('Page.setInterceptFileChooserDialog', { enabled: false });
  // I13: com biblioteca, a linha "Cursos" leva à lista e ao curso.
  await tap(/Cursos ·/, 2000);
  await find(/Primeiros passos ao piano/);
  check(true, 'cursos: lista abre pela linha Cursos');
  // A lista reconstrói ao carregar o progresso do disco: espera assentar
  // para o clique não cair em coordenada velha.
  await sleep(3000);
  await tapBig(/Primeiros passos ao piano/, 2000);
  await find(/Apresentação/);
  check(true, 'cursos: tela do curso abre');
  await b.shot('smoke-curso');
  // De volta à biblioteca para o resto da fumaça (o IndexedDB mantém).
  await b.send('Page.navigate', { url: `http://127.0.0.1:${port}/` });
  await sleep(8000);
  await find(/600 hinos/);
  await tap(/Conectar teclado MIDI/);
  await tap(/Ativar o MIDI/);
  check((await b.evalJs('window.__reqOptions[0]')) === '{"sysex":false}', 'MIDI: pedido sem sysex');
  check((await log()).includes('open input Fake Piano'), 'MIDI: teclado conectado');
  await tap(/^Fechar$/);

  // Abre o hino 1 pelo título (as coordenadas fixas quebraram com os
  // cartões novos da biblioteca: "Cursos" e "Comece por aqui").
  await tapBig(/Santo, Santo, Santo!/, 9000);
  await tap(/Treino livre/, 1500);
  await tap(/Tocar \(destacar/, 100);
  const playing = await peak(2000); // pega o ataque de alguma nota, não o decaimento
  check(playing > 0.003, 'som: Play toca', `(pico ${playing.toFixed(4)})`);
  await tap(/^Parar$/, 100);
  await sleep(1500);
  const after = await peak(500);
  check(after < 0.0005, 'som: Parar silencia, sem nota presa', `(pico ${after.toFixed(5)})`);

  await tap(/Ligar monitor MIDI/);
  await b.evalJs('window.__fire(0x90, 60, 100)');
  const monitor = await peak(400);
  check(monitor > 0.003, 'monitor: nota do teclado soa no app', `(pico ${monitor.toFixed(4)})`);
  await b.evalJs('window.__fire(0x80, 60, 0)');
  await sleep(1500);

  await tap(/Saída de som/);
  await tap(/^Teclado MIDI$/);
  await tap(/Tocar \(destacar/, 2000);
  const sent = (await log()).filter((l) => l.startsWith('send [144,')).length;
  check(sent > 0, 'saída MIDI: o Play chega ao teclado', `(${sent} notas)`);
  await b.shot('smoke-final');
} catch (e) {
  console.log('FALHA', e.message);
  failed++;
} finally {
  b.close();
  server.kill();
}
process.exit(failed ? 1 : 0);
