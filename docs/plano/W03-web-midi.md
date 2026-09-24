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

(preencher)
