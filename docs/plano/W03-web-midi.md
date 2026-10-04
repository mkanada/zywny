# W03 — Web MIDI (entrada e saída)

**Repo:** zywny · **Depende de:** W02, M03 · **Decisão necessária:** não

## Objetivo

Na Web (Chrome/Edge), o seletor de dispositivos, o monitor (M01), a saída
MIDI (M03) e o treino (T02-T04) funcionam com teclado USB, pelo Web MIDI.

## Ler antes (só isto)

- `lib/midi/` (M01, M03) e suas notas de execução.
- Este README (Fatos: Web).

## Contexto que você precisa

- `flutter_midi_command` 1.3.0 declara suporte Web via Web MIDI ("use HTTPS
  and a browser with Web MIDI enabled (for example Chrome/Edge)"). Primeiro
  **teste o plugin**; só escreva `js_interop` direto sobre
  `navigator.requestMIDIAccess()` se o plugin falhar em algo necessário
  (registre o quê).
- Requisitos: contexto seguro (HTTPS ou `localhost` — `flutter run -d chrome`
  serve em localhost, ok), permissão do usuário (o navegador pergunta na
  primeira chamada; peça **em resposta a um clique**, não no carregamento).
  `sysex: false`.
- Suporte: Chrome, Edge, Opera, Samsung Internet; Firefox só com
  site-permission add-on; **Safari/iOS não têm**. Detecte
  (`navigator.requestMIDIAccess` ausente) e mostre mensagem explicando e
  sugerindo Chrome/Edge — o resto do app (partitura, som) continua.
- **Saída com timestamp**: Web MIDI aceita `output.send(data, timestamp)`
  com `timestamp` em ms do `performance.now()`. Se o plugin expuser isso, o
  `MidiOutSoundEngine` na Web pode agendar de verdade (sem o despacho por
  `Timer` de M03): implemente como otimização só se for simples; senão
  mantenha o despacho de M03 e registre o jitter.
- Carimbo de entrada: `MIDIMessageEvent.timeStamp` está na mesma base do
  `performance.now()` (e do `AudioContext` via `getOutputTimestamp()` —
  útil em W04). Registre o que o plugin entrega em `event.timestamp` na Web.
- Hot-plug: `MIDIAccess.onstatechange` — confirme que chega como
  `onMidiSetupChanged`.
- Linux + Chrome: Web MIDI enxerga as portas ALSA (VMPK serve para teste).

## O que fazer

1. Habilitar a camada MIDI na Web (fábricas de M01/M03), mensagens de
   navegador sem suporte.
2. Testar entrada, monitor (se W04 pronto) e saída.

## Fora de escopo

- Som do sintetizador na Web (W04). BLE na Web (não suportado).

## Critérios de aceite

1. **(manual, Chrome no Linux)** VMPK/teclado: monitor mostra as notas;
   modo espera (T02) funciona com o destaque (sem som do app, se W04 não
   estiver pronto — com saída MIDI de M03 para um sintetizador externo, se
   houver).
2. **(manual)** Firefox sem add-on e (se disponível) Safari: mensagem clara,
   app não quebra.
3. Unidade/base do timestamp de entrada na Web registrada.
4. `flutter build web --release` e `just analyze` limpos.

## Notas de execução

### Notas de execução (2026-10-04)

**O que o plugin faz (lido em `flutter_midi_command_web` 1.3.0)**
- Funcionou sem `js_interop` próprio: lista, conecta, recebe e envia pelo
  Web MIDI; `onMidiSetupChanged` chega do `MIDIAccess.onstatechange` (com
  atraso de 250 ms para juntar eventos).
- Três problemas, nenhum exigiu trocar o plugin:
  1. **Pede `requestMIDIAccess(sysex: true)`** (fixo no código) — a pergunta
     mais assustadora do Chrome. Correção: um shim de 4 linhas em
     `web/index.html` que reescreve as opções para `sysex: false` antes de o
     Flutter carregar.
  2. **Pede o acesso na primeira chamada** (`devices`, e até só assinar
     `onMidiSetupChanged`), isto é, ao abrir a biblioteca — e é isso que
     gerava as três exceções "Error" sem texto da inicialização (W02): sem o
     acesso, o `unawaited(refresh())` do gerenciador estourava. Correção em
     `MidiDeviceManager` (ver abaixo).
  3. Sem Web MIDI lança `UnsupportedError` do `initialize`; com acesso
     recusado, uma exceção do navegador.
- **Carimbo de entrada**: `event.timestamp` chega como
  `MIDIMessageEvent.timeStamp.toInt()` — milissegundos inteiros na base do
  `performance.now()` (truncado: perde a fração). O app continua ignorando-o
  e carimbando com o relógio do motor de áudio (M01), então nada muda.
- **Saída com timestamp**: o plugin aceita (`sendData(..., timestamp:)` →
  `output.send(data, ms)`), mas **não foi usado**: exigiria que o
  `MidiOutSoundEngine` trabalhasse na base do `performance.now()` e a
  otimização não era simples. Fica o despacho por `Timer` de M03; medido no
  navegador, as notas de um acorde saem no mesmo instante (mesmo
  `performance.now()` a 0,1 ms).

**O que foi feito**
- `lib/midi/web_midi_access*.dart` (import condicional): `webMidiSupported`
  (`navigator.requestMIDIAccess` existe?) e `webMidiGranted()` (Permissions
  API, `{name: 'midi', sysex: false}`; chamada direta porque `package:web`
  não traz a Permissions API).
- `MidiDeviceManager` ganhou `unavailable` (`MidiUnavailable`: `unsupported`,
  `notAsked`, `denied`). Na Web, na abertura: sem suporte → `unsupported`;
  com permissão já dada → lista e conecta como no nativo; senão `notAsked` e
  **não toca no plugin** (a pergunta só abre quando o usuário aperta "Ativar
  o MIDI" no seletor). Erros do plugin viram `unsupported`/`denied` em vez
  de exceção solta; "Tentar de novo" repete. Nativo inalterado.
- `showMidiDevicePicker`: texto e botão por motivo (`midiUnavailableText`):
  Chrome/Edge sugerido no `unsupported`; no `denied` o cadeado do Chrome e o
  aviso de que o Firefox só libera com um complemento.
- `test/midi_device_manager_web_test.dart` (5 testes): não toca no plugin
  antes do clique, permissão já dada, sem suporte, `UnsupportedError`,
  recusa seguida de nova tentativa.

**Critérios**
1. (manual) Feito no **Chromium headless com um `navigator.requestMIDIAccess`
   falso** (`tool/web_smoke/`), não com o VMPK: o teclado falso aparece e
   conecta, uma nota injetada toca no monitor (W04), o modo espera (T02)
   avança com notas (pendente azul, certas verdes, extras como fantasma) e a
   saída MIDI recebe as notas do Play (21 no primeiro trecho do hino 1).
   ✔ (falta um teclado/VMPK de verdade no Chrome)
2. (manual) Navegador sem `requestMIDIAccess` (simulado): mensagem clara,
   o resto do app segue. **Firefox 156 de verdade** (WebDriver BiDi): o app
   abre e desenha; o Firefox tem a função, então o botão "Ativar o MIDI"
   chama `requestMIDIAccess`, que fica pendente até o usuário responder ao
   pedido de instalar o complemento (se recusar, cai em `denied`). Safari/iOS
   não testados. ✔ (parcial)
3. Base do timestamp registrada acima. ✔
4. `flutter build web --release` e `flutter analyze` limpos; `flutter test`:
   294 passam, 2 ignorados. ✔
