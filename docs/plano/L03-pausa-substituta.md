# L03 — `score_bridge`: pausa substituta colorida

**Repo:** zywny (`score_bridge/`) · **Depende de:** L02, G09 do bridge ·
**Decisão necessária:** nenhuma

## Objetivo

Desenhar, no lugar de cada coluna escondida, **uma pausa** com a figura
certa, numa cor que o chamador controla — e que pisca com o veredito.

## De onde vêm os dados e a regra

Glifos, figura da nota e posição da pausa são do **formato**. O trabalho no
fork (glifos de pausa sempre no dicionário, `dur`/`dots` no
`pitchpos.json`), a regra normativa (§11 da especificação, regras 4–7), a
prova contra o Verovio e os vetores de teste estão no plano do bridge
(`/home/mauricio/rust_projects/verovio_flutter_bridge/docs/plano/`, passos
G07–G09). Este passo é a **porta Dart**. Se G09 ainda não está `concluído`
lá, pare.

## Ler antes (só isto)

- [L00](L00-trilha-do-decorar.md): "O que some", "Durante a passagem".
- No bridge: `docs/nota-para-zywny-sumico.md` (G09) e a §11 de
  `docs/formato/especificacao-v1.md`, regras 4–7, mais a §2.8 (`dur`,
  `dots`).
- `score_bridge/lib/src/ghost.dart` L28-L114 (`GhostGlyph`, `GhostNote`) e
  L116-L172 (índice por página).
- `score_bridge/lib/src/ghost_layer.dart` inteiro (268 linhas):
  `GhostController`, `GhostPainter` — a camada por cima da página é o
  modelo a copiar.
- `score_bridge/lib/src/model.dart` L279-L312 (`StaffGeometry`) e o modelo
  de `pitchpos.json`.
- `score_bridge/test/fixtures/sumico/` (vetores e `.vsb`, copiados em G09).

## Contexto que você precisa

- **Antes de tudo: bibliotecas novas.** O `.vsb` é gerado no aparelho;
  sem refazer a `libverovio` (`just native` no Linux **e**
  `build_android_so.sh` no bridge) os glifos de pausa e o `dur` não
  existem. `.vsb` sem eles (lib antiga): a coluna some sem pausa, sem
  exceção.
- **Figura**: `dur` e `dots` da nota mais curta da coluna, lidos do
  `pitchpos.json`. Não deduza do timemap. Quiáltera usa a figura escrita.
- **Glifo**: `E4E3` (semibreve) a `E4E9` (semifusa); ponto `E1E7`. Estão
  sempre em `VsbDocument.glyphs` (reservados).
- **Posição**: a da regra 6 da §11 — x da cabeça mais à esquerda da
  coluna; `loc` da linha do meio, +2 para a semibreve; escala `gs` da
  pauta; pontos pela conta da §11.
- **Uma pausa por (pauta de desenho, instante)**, mesmo com duas vozes na
  coluna.
- **Cor.** A camada tem uma cor de repouso (parâmetro; o app passa
  `kMemoRestColor`) e aceita um "piscar" por coluna (cor, ataque,
  sustentação, soltura), nos moldes de `ScoreController.highlight`. Cor e
  piscar são do host: não estão na §11.
- A camada vive dentro da página, como a das fantasmas: é recortada na
  virada por haste e acompanha zoom e pan.

## O que fazer

1. Parser/modelo: `dur` e `dots` no evento de `pitchpos.json` (ausentes →
   `null`/`0`).
2. `score_bridge/lib/src/stand_in.dart`: `StandInRest {page, staffId,
   glyphs, x, y}` e `VsbDocument.standInFor(List<String> noteIds)` — a
   pausa de uma coluna (`null` se não der para calcular).
3. `score_bridge/lib/src/stand_in_layer.dart`: `StandInController`
   (`setColumns(Map<chave, List<String> noteIds>)`, `remove(chave)`,
   `flash(chave, cor, …)`, `clear()`) e o painter; parâmetro novo em
   `ScorePageView`/`ScoreView`, `null` por padrão (custo zero, como
   `ghosts`).
4. Exportar em `score_bridge/lib/score_bridge.dart`.
5. Testes em `score_bridge/test/`.

## Fora de escopo

- Qualquer mudança no fork ou na especificação (G08a–G08c, no bridge).
- Decidir quais colunas somem (L01) e quando piscar ou revelar (L05).
- Pausas por voz; pausa em pauta que não tem 5 linhas (devolva `null`).

## Critérios de aceite

1. Teste: os casos de `fixtures/sumico/vetores.json` — glifo, x, y, escala
   e pontos de cada pausa, tolerância de 0,5 unidade de viewBox.
2. Teste: `pitchpos.json` com e sem `dur`/`dots` é lido sem erro; os
   testes da nota fantasma continuam verdes com as fixtures novas.
3. Teste: coluna com duas vozes de figuras diferentes → uma pausa, com a
   figura da mais curta.
4. Teste de pintura: `flash` muda a cor da pausa e volta à de repouso;
   `remove` apaga só aquela.
5. Teste: `.vsb` antigo (fixture sem os glifos ou sem `dur`) →
   `standInFor` devolve `null` e nada quebra.
6. **(manual)** `just native` feito; hino 1 com metade das colunas
   escondidas: as pausas não colidem com as notas visíveis vizinhas nem
   com a letra. Anote os casos feios (semicolcheias coladas, por exemplo)
   com captura de tela — é retorno para o bridge.
7. **(manual, Android)** A lib nova está no APK: a mesma tela no celular
   mostra as pausas.
8. `cd score_bridge && flutter test`, `just analyze` e `just test` limpos.

## Notas de execução

_(preencher ao executar)_
