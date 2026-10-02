# U10 — Aproveitar a tela: imersivo, centro, dois sistemas

**Repo:** zywny · **Depende de:** U01 · **Decisão necessária:** D-SISTEMAS
(só para a parte 3)

## Objetivo

A tela da partitura no celular não desperdiça altura: a barra de status
some, o sistema não fica colado no topo com um terço vazio embaixo e — se a
medição e você aprovarem — cabem dois sistemas por página. Achado A10;
sugestão A10.

## Ler antes (só isto)

- [U00](U00-ux-do-celular.md) e a sugestão **A10**.
- Telas `11`, `21` e `30` (um sistema de 4 compassos; faixa branca no topo;
  terço de baixo vazio) e `16` ("TAMANHO DA NOTAÇÃO 12.0", no topo do
  controle).
- `lib/main.dart`: `initState` L382-L408 (a trava de paisagem, L400-L407),
  `dispose` L514-L538, `_fittedPage`/`_pageWidth`/`_pageHeight` L360-L380,
  `_onBoxSize` L545-L579, `_buildPhoneBody` L2073-L2147 (o `SafeArea`), o
  controle "TAMANHO DA NOTAÇÃO" em `_buildOptionsDrawer` (L2235-L2244).
- `lib/library/library_screen.dart`: `_lockPortrait` L131-L137.
- `lib/layout_options.dart`: `unit` L102, `adjustPageHeight` L152,
  `justifyVertically` L256, `kAppDefaults` L377, `kPhoneUnit` L403,
  `initialLayoutValues` L407-L412.
- `score_bridge/lib/src/score_view.dart`: `_fit` L918-L926 e `_centered`
  L928-L933.
- `test/vsb_render_test.dart` (como renderizar um hino num teste, com a
  `libverovio.so` do Linux) e `test/trail_stats_manual_test.dart` (o molde
  de um teste **manual** que mede os 600 hinos).

## Contexto que você precisa

- Em paisagem, o Android mantém a barra de status no topo (~24 dp); a tela
  tem `SafeArea`, então a área do Flutter começa abaixo dela. São ~6% dos
  411 dp de altura.
- A página é gravada para a caixa (`_fittedPage`, 1 px de aparelho = 1
  unidade): no emulador, 2054×912. O Verovio preenche de cima para baixo;
  com `unit` 12 cabe **um** sistema e sobra o terço de baixo.
- `_centered` centraliza a **página** na caixa. Como a página tem o tamanho
  da caixa, isso não centraliza o sistema. Com `adjustPageHeight` a página
  encolhe até o conteúdo — aí o `Center` centraliza de verdade. Verifique
  antes: (a) a paginação continua sendo decidida por `pageHeight`; (b) a
  haste de virada e o `_fit` continuam certos com páginas de alturas
  diferentes entre si.
- Mudar a altura da caixa regrava o hino (`_onBoxSize`, folga de 2%). O
  modo imersivo muda a caixa **uma vez**, ao entrar na tela — tem de ser
  pedido antes da primeira gravura (no `initState`, junto da trava de
  paisagem), não depois.
- `kPhoneUnit` = 12 é o topo do controle da gaveta (4,5–12): o aluno só
  consegue diminuir.
- **D-SISTEMAS** só se decide com números. Não mude `kPhoneUnit` sem a
  resposta.

## O que fazer

### Parte 1 — modo imersivo (sem decisão)

1. No `initState` da tela da partitura, em celular:
   `SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky)`. Ao
   sair (`dispose`) e em `_lockPortrait` da biblioteca, voltar a
   `SystemUiMode.edgeToEdge` (ou ao que a biblioteca usa hoje — confira).
2. Conferir no emulador que a primeira gravura já sai para a caixa maior
   (um `_renderAndShow` só no log).

### Parte 2 — centralizar (sem decisão)

3. Experimentar `adjustPageHeight: true` como padrão **do celular**
   (`initialLayoutValues(phone: true)`); conferir os pontos (a) e (b) do
   contexto com os hinos 1, 5 e um com casas (ver J08). Se quebrar a
   virada, a alternativa é centralizar na pintura (deslocar a página pela
   metade da sobra, medindo a altura ocupada pela cena) — registre o que
   escolheu e por quê.

### Parte 3 — medir dois sistemas (para D-SISTEMAS)

4. Teste **manual** (`test/layout_phone_manual_test.dart`, no molde do
   `trail_stats_manual_test.dart`): para `unit` em {12, 11, 10, 9, 8} e
   página 2054×912 (e 1775×780, um aparelho de 360 dp de altura), nos
   hinos 1, 5, 100, 300 e 457: páginas, compassos por página (mín/média),
   e a altura do pentagrama em dp (da cena) — o número que diz se ainda se
   lê do banco do piano.
5. Escrever a tabela nas notas de execução e **parar para a decisão**.
6. Se aprovado: `kPhoneUnit` novo; hinos que já têm `unit` gravado em
   `HymnSettings` não mudam.

## Fora de escopo

- Rolagem contínua no celular.
- Esconder a barra de navegação por gestos além do que o imersivo faz.
- O layout largo.

## Critérios de aceite

1. `just telas`: as telas em paisagem não têm a faixa branca de ~24 dp no
   topo; a biblioteca (retrato) continua com a barra de status.
2. Log de uma abertura de hino no emulador: um `_renderAndShow` só.
3. `just telas`: na tela 11 o sistema está centralizado na vertical (ou o
   motivo de não estar, nas notas).
4. A virada de página continua certa (telas 23 e 41; e os testes de
   `score_bridge`).
5. Tabela da parte 3 nas notas de execução, com a recomendação.
6. `just analyze` e `just test` limpos; o roteiro das telas passa.

## Notas de execução

- **Parte 1 (imersivo):** feita. `SystemUiMode.immersiveSticky` no
  `initState` da tela da partitura (só celular), `edgeToEdge` no `dispose`
  e em `_lockPortrait` da biblioteca. O critério 2 (um `_renderAndShow` só
  no log) e a foto sem a faixa branca **não foram conferidos** no emulador.
- **Parte 3 (medição):** `test/layout_phone_manual_test.dart`
  (`LAYOUT_PHONE=1 flutter test test/layout_phone_manual_test.dart`; com
  `ADJUST=1` repete com `adjustPageHeight`). Hinos 1, 5, 100, 300 e 457;
  pentagrama em dp = 8 × `StaffGeometry.unit` × `widthPx/viewBox.width` ÷ dpr
  (2,625):

  | página | unit | compassos/pág (mín) | compassos/pág (média) | pentagrama (dp) |
  | --- | --- | --- | --- | --- |
  | 2054×912 | 12 | 1 | 4,2 | 36,6 |
  | 2054×912 | 11 | 3 | 4,7 | 33,5 |
  | 2054×912 | 10 | 1 | 4,7 | 30,5 |
  | 2054×912 | 9 | 1 | 5,1 | 27,4 |
  | 2054×912 | 8 | 1 | 5,5 | 24,4 |
  | 1775×780 | 12 | 2 | 3,8 | 36,6 |
  | 1775×780 | 11 | 2 | 4,1 | 33,5 |
  | 1775×780 | 10 | 1 | 4,1 | 30,5 |
  | 1775×780 | 9 | 1 | 4,5 | 27,4 |
  | 1775×780 | 8 | 1 | 4,7 | 24,4 |

  Todo hino fica com **um** sistema por página em todos os `unit` medidos;
  só uma página do hino 457 (unit 8) teve dois. Um sistema ocupa ~60 px por
  unidade de `unit`: dois sistemas em 912 px pedem `unit` ≈ 6 (pentagrama
  ~18 dp).
- **D-SISTEMAS decidida pelo usuário: não.** `kPhoneUnit` continua 12.
- **Parte 2 (centralizar): sem mudança, por decisão do usuário.** Com
  `adjustPageHeight` a paginação não muda (mesmas páginas e compassos por
  página), mas as páginas saem com alturas diferentes (hino 1, unit 12:
  701–826 de 912 px) e o sistema subiria e desceria até ~24 dp a cada
  virada. `ScenePage.contentHeight` não serve para um deslocamento fixo: sem
  o ajuste ele vale a altura da página. A alternativa registrada: deslocar
  pela altura do maior sistema do hino (medir o `bbox` do nó `system`).
