# U04 — Som ligado por padrão e indicador

**Repo:** zywny · **Depende de:** U01 · **Decisão necessária:** D-SOM

## Objetivo

O primeiro play de uma instalação nova soa. O estado do som está sempre à
vista na tela da partitura e muda com um toque. Achado A2; sugestão A2.

## Ler antes (só isto)

- [U00](U00-ux-do-celular.md) e a sugestão **A2**.
- Telas `07` (o interruptor "Som do app", desligado) e `23` (tocando, mudo,
  sem nada na tela que avise).
- `lib/settings/app_settings.dart`: `_soundOn` L49, `soundOn` L82-L87,
  `load` L164 em diante (a leitura de `_kSoundOn`, L182).
- `lib/main.dart`: `_soundOn`/`_soundSetting`/`_autoSoundDone` (L280-L290,
  com o comentário), `_onSettingsChanged` L413-L443 (o trecho do som,
  L434-L440), `_toggleSound` L1450-L1475, `_userToggleSound` L1479-L1483,
  `_restoreSound` L1488-L1506, `_togglePlay` L1015-L1047 e
  `_startSilentCountIn` L1053-L1101 (o play mudo), `_engineButtonIcon`
  L1332-L1338, `_buildPhoneTitleBar` L1966-L1987.
- `lib/settings/general_settings_panel.dart` L144-L153.
- `test/settings_test.dart`.

## Contexto que você precisa

- `AppSettings._soundOn` nasce `false`. O play do treino livre, mudo,
  destaca as notas e faz a contagem na tela; nada soa (nem os cliques, se o
  motor ainda não abriu).
- **D-SOM, recomendação:** nascer `true`. Quem **gravou** `false` continua
  com `false`: o padrão só vale quando a chave `sound_on` não existe. O
  `load` precisa distinguir "ausente" de "false" — confira como ele trata o
  `null` de `getBool`.
- Ligar por padrão não acrescenta espera: `_restoreSound` já abre o motor
  do app ao entrar no hino mesmo com o som desligado (L1494-L1500).
- No celular o interruptor só existe em ⋯ → Configurações gerais. No layout
  largo há um botão de som próprio, que usa `_userToggleSound` e
  `_engineButtonIcon` (mostra progresso enquanto o `.sf2` carrega) — é o
  comportamento a copiar.
- Etapa da trilha e treino com teclado **forçam** o som (`_soundOn = true`
  em L862 e L1239) sem mexer na preferência. O indicador mostra o estado
  **de agora** (`_soundOn`), e o toque do aluno muda a preferência
  (`_userToggleSound`).
- Saída no teclado MIDI (`SoundOutput.midiKeyboard`) sem teclado conectado:
  `_restoreSound` fica quieto (L1501-L1504) e o play sai mudo. O indicador
  deve dizer por quê.
- Com a etapa rodando, desligar o som encerra o treino (`_toggleSound`
  chama `_endPractice`): nesse momento o botão fica desabilitado.

## O que fazer

1. `AppSettings`: padrão `true`, respeitando o valor gravado. Teste em
   `test/settings_test.dart`: sem chave → ligado; chave `false` → desligado.
2. Botão de som na barra do título do celular (`PhoneTitleBar.trailing`,
   antes dos selos): `Icons.volume_up` / `Icons.volume_off`, tooltip "Som
   ligado" / "Som desligado", toque = `_userToggleSound`. Enquanto o `.sf2`
   carrega, o indicador de progresso de `_engineButtonIcon`.
3. Saída no teclado sem teclado: ícone `Icons.volume_off` com tooltip "Som
   no teclado: nenhum conectado"; toque abre `showMidiDevicePicker`.
4. Desabilitado enquanto `_practice != null`.
5. Subtítulo do interruptor nas configurações: sem mudança de texto aqui (o
   U17 troca os rótulos).
6. Roteiro das telas: conferir que nada dependia do som desligado (o
   emulador roda com `-no-audio`; o motor abre do mesmo jeito).

## Fora de escopo

- Controle de volume.
- O botão "ouvir o trecho" (U03).
- O layout largo (já tem o botão).

## Critérios de aceite

1. Teste: `AppSettings` sem preferência gravada → `soundOn == true`; com
   `sound_on = false` gravado → `false`.
2. Teste de widget: `PhoneTitleBar` com o botão de som nos dois estados;
   tocar chama o retorno.
3. `just telas`: as telas da partitura mostram o alto-falante; a 23
   (tocando) com ele ligado.
4. **(manual, com som)** Instalação limpa: abrir um hino, treino livre,
   play → soa. Tocar no alto-falante → emudece na hora e a preferência
   fica (reabrir o hino abre mudo).
5. **(manual)** Saída = Teclado MIDI, sem teclado: o ícone explica e leva
   ao seletor.
6. `just analyze` e `just test` limpos.
