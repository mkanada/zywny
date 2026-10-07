# Q08 — Tela da transposição e aceite manual

**Repo:** zywny · **Depende de:** Q04, Q06, Q07 · **Decisão necessária:**
não (D-TRP-NOME decidida: "Transpor")

## Objetivo

A pessoa liga a transposição na gaveta, vê o selo na partitura, escolhe
outro tom se quiser, e o app passa no aceite com o teclado de verdade.

## Ler antes (só isto)

- [Q00](Q00-transpor-sem-acidentes.md): "Na tela", "Progresso separado por
  tom", "Critérios de aceite da fase".
- [U00](U00-ux-do-celular.md) (princípios e `just telas`), U11 (gaveta),
  U17 (vocabulário), U18 (visual).
- `lib/settings/general_settings_panel.dart` (para a chave geral).

## O que fazer

1. **Gaveta** (U11), item **"Transpor"**, só para música com `fifths`
   conhecido e diferente de 0 (com 0, o item mostra só "Escolher…"):
   - "Não (3♭)" — guarda `P1`;
   - "Sem acidentes" — subtítulo "teclado +3";
   - "Escolher…" — lista dos 12 tons (Q02 `toFifths`), cada linha com a
     armadura resultante e o TRANSPOSE ("Ré · 2♯ · teclado −1"); a original
     marcada "original".
   Trocar de tom com trilha começada pede a confirmação do Q04 ("Em Dó a
   trilha começa do zero. A do tom original fica guardada.").
2. **Selo na partitura** enquanto transposta: "Mi♭ → Dó · teclado +3"
   (ou "Mi♭ → Dó · o app toca no tom original" quando `appIsSound`). Tocar
   abre a conferência (Q06). No celular em paisagem, o selo cabe na barra
   sem tirar espaço da pauta (U10).
3. **Configurações gerais**: chave "Abrir as músicas já sem acidentes"
   (Q03), com subtítulo "Cada música pode voltar ao original na gaveta".
4. **Biblioteca**: na linha da música transposta, a armadura aparece como
   "3♭ → 0" (onde hoje aparece "3♭"). A ordenação por acidentes continua
   pela original.
5. **Tela da música / trilha**: "Também estudada: original, 3 de 8
   trechos" quando há progresso em outro tom (Q04).
6. `just telas`: telas novas da gaveta com "Transpor", da lista dos 12 tons,
   do selo e da folha de conferência.

## Aceite manual (com o teclado do usuário)

Linux, Android e Web, com o teclado MIDI do usuário:

1. Hino em Mi♭ (3♭): "Sem acidentes" → partitura em Dó; conferência pede
   +3; tocar Dó soa Mi♭; o app guarda o comportamento do teclado (anotar
   aqui: transpõe a saída? a entrada?).
2. Modo espera e tempo real passam tocando as teclas de Dó maior; "ouvir o
   trecho" soa em Mi♭, junto com o teclado.
3. Hino com sustenidos (2♯ ou 4♯): o mesmo, com TRANSPOSE negativo/positivo
   conforme a tabela.
4. Voltar a "Não": a trilha original reaparece; com o teclado ainda em +3,
   o detector avisa em até 6 notas erradas (se o teclado transpõe a saída
   MIDI; ajustar N se precisar) ou o lembrete de voltar a 0 aparece (se não
   transpõe).
5. Hino em 6♯ ou 6♭ (se existir no catálogo): trítono desce.

## Critérios de aceite

1. Testes de widget da gaveta (três escolhas, lista, confirmação), do selo e
   da chave geral.
2. `just telas` atualizado.
3. Aceite manual 1–5 registrado nas notas, com o modelo do teclado e o que
   ele faz com o TRANSPOSE no MIDI.

## Notas de execução

### Resultado (2026-10-06): código e testes feitos; aceite manual pendente

O aceite manual (1–5) precisa do teclado MIDI do usuário e **não foi feito**:
a tabela no fim destas notas está em branco para ele preencher. O passo só
fica **concluído** quando ela estiver preenchida.

Arquivos: `lib/music/tone_choices.dart` (novo: `keySignatureShort`,
`keySignatureTransposed`, `toneChoices`, `transposeSealText`,
`toneChangeMessage`), `lib/ui/transpose_widgets.dart` (novo: `TransposeSeal`,
`TransposeSection`, `showToneList`, `alsoStudiedText`), `lib/main.dart`,
`lib/settings/general_settings_panel.dart`, `lib/library/library_screen.dart`,
`lib/trail/trail_widgets.dart` (`TrailDrawer.alsoStudied`),
`integration_test/telas_celular_test.dart`. Teste novo:
`test/transpor_tela_test.dart` (26 casos).

**Decisões de execução**
- **`_stored.transpose` virou `_transposeChoice`** (campo mutável de
  `_ScoreHomePageState`), como o Q03 mandava; `_transposition` passou a ser
  `_transpositionFor(_transposeChoice)`, e a escolha é gravada na hora
  (`onPieceSettingsChanged`, que também leva `setTranspose` à biblioteca), sem o
  respiro de 400 ms do layout: é uma escolha, não um slider.
- **"Não" guarda `P1`** (`kTransposeNone`), como o plano manda, mesmo quando a
  chave geral está desligada. Se a escolha não muda a gravura (ex.: "Não" sem a
  chave geral), só guarda; não regrava.
- **A confirmação** usa `toneChangeStartsOver` (Q04) e o `confirmTrailReset`
  que já existia. O texto cita o tom de destino e o de origem: "Em Dó a trilha
  começa do zero. A do tom original fica guardada." — de um tom transposto para
  outro, "A de Dó fica guardada.".
- **A lista dos 12 tons** vai do Dó ao Si (ordem das notas), com o Fá♯ (6♯) no
  trítono, que desce. Uma música em 7♯ ou 6♭ troca o tom enarmônico da lista
  pelo dela, para a "original" sempre existir.
- **"Também estudada" diz "etapas", não "trechos"**: o que a trilha guarda é
  feito/total de etapas (`trailProgressText`), e "trecho" é só o corte em
  compassos. Aparece na gaveta de opções (sob "Transpor") e na gaveta da trilha
  (sob o progresso). Lido por `studiedTones` a cada trilha montada.
- **O selo** fica em `PhoneTitleBar.trailing` (celular) e nas ações da barra
  (desktop), até 230 px com reticências: a barra já existe, então a pauta não
  perde espaço em paisagem (U10). Mostra o tom **da gravura na tela**, não o
  pedido. Tocar abre a conferência (Q06); sem teclado ou com o monitor ligado
  não há o que conferir, e uma mensagem diz por quê.
- **Desktop**: ganhou o botão "Transpor" na barra (o mesmo item num diálogo),
  porque a gaveta é do celular e o aceite também roda no Linux.
- **Biblioteca**: a armadura da música transposta é "3♭ → 0"; as sem
  transposição seguem com "3 bemóis" (por extenso, como hoje — o plano dizia
  "3♭" para o que "hoje aparece", mas hoje é por extenso). A ordenação por
  acidentes continua pela original.
- **Item sem armadura conhecida** (`Piece.fifths == null`): não aparece. Um
  intervalo guardado em música sem armadura só nasce de código, não da tela.

**Critérios**
1. Testes de widget: gaveta (as três escolhas, só "Escolher…" com 0
   acidentes, nada sem armadura), lista dos 12 tons e o escolhido indo ao
   Verovio, confirmação (pergunta, cancelar não muda nada, "Trocar" muda; sem
   trilha começada não pergunta), selo (texto, toque, barra estreita), chave geral
   nas configurações (grava e regrava o hino) e a linha da biblioteca. ✔
2. `just telas` atualizado: telas 61–67. ✔
3. Aceite manual: **pendente** (tabela abaixo).

**`just telas`**: o roteiro ganhou a passagem "transpor (fase Q)" (telas 61–67, já em `docs/telas/celular/` e no `INDICE.md`). Rodei só essa passagem no emulador (`emulator-5554`, hino 005 em Fá, 1♭), com `TELAS_DIR` fora do repositório, para não regravar as 60 fotos de antes; o roteiro inteiro não foi rodado de novo.

### Aceite manual (a preencher com o teclado do usuário)

Teclado (marca e modelo): ____________________

| # | O que fazer | Linux | Android | Web |
| --- | --- | --- | --- | --- |
| 1 | Hino em Mi♭: "Sem acidentes"; conferência pede +3; Dó soa Mi♭. **O teclado transpõe a saída MIDI? e a entrada?** | | | |
| 2 | Modo espera e tempo real passam com as teclas de Dó maior; "ouvir o trecho" soa em Mi♭ junto com o teclado | | | |
| 3 | Hino com 2♯ ou 4♯: o mesmo, com o TRANSPOSE da tabela | | | |
| 4 | Voltar a "Não" com o teclado em +3: o detector avisa em até 6 notas erradas (se transpõe a saída) ou o lembrete de voltar a 0 aparece (se não) — ajustar N se precisar | | | |
| 5 | Hino em 6♯ ou 6♭ (se existir no catálogo; o catálogo de hinos vai de 5♭ a 4♯, então só uma biblioteca de clássicos): o trítono desce | | | |
