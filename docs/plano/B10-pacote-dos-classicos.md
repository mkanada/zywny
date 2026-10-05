# B10 — Pacote dos clássicos

**Repo:** zywny · **Depende de:** B02, B09 · **Decisão necessária:** não

## Objetivo

`dist/classicos.zywny`, com dificuldade calculada, conferido no app.

## Ler antes (só isto)

- [B00](B00-bibliotecas-instalaveis.md), B02 (o gerador), B09 (a lista).
- `Hymn_Grabber/scripts/classificar-dificuldade.py` (cabeçalho).

## Contexto que você precisa

- O classificador (D-BIB-DIFIC) dá o nível pela **posição da peça no
  acervo** (quintil): com ~50 peças, nível 1–5 é relativo aos clássicos,
  não comparável com o nível de um hino. Ele também pula compassos de
  introdução copiada (`1i`, `2i`), coisa só dos hinos — conferir que não
  atrapalha.
- Manifesto: `id: "classicos"`, `nome: "Clássicos para piano"`,
  `numerada: false`, termo "peça"/f, `creditos` com OpenScore/CC0 e os
  compositores.

## O que fazer

1. Rodar o classificador sobre a pasta do B09 (adaptar, se preciso, com
   uma opção em vez de mudar o comportamento dos hinos).
2. `tool/build_classics.py` (ou receita `just pacote-classicos`) chamando o
   gerador do B02; `o` = número de catálogo.
3. Separar umas 5 peças curtas num pacote pequeno para `test/fixtures/`
   (usado pelo B08).
4. Conferir no app: abrir todas, a trilha cortar sem erro (o J01 tem a
   medição em lote dos hinos — repetir para os clássicos).

## Critérios de aceite

1. Pacote gerado; níveis distribuídos e conferidos à mão em 5 peças
   (parecem certos para um professor?).
2. Todas as peças renderizam e têm trilha (ou a razão de não ter, nas
   notas).
3. **(manual)** Instalar no celular e treinar uma.

## Notas de execução

**Adiado (2026-10-04).** Depende do B09, que ficou parado sem fonte (ver lá).
Nada foi feito. Dois efeitos: (1) o gerador (`tool/build_library.py`, B02) e o
app já aceitam uma biblioteca não numerada com termo "peça"/f e `o` de
catálogo, e os testes de widget cobrem isso com pacotes sintéticos
(`library_vocabulary_test.dart`) — só falta o conteúdo; (2) o passo 3 (pacote
pequeno em `test/fixtures/`) deixou de existir: o B08 não usa fixture
versionado (ver lá).

**Feito (2026-10-04).** `tool/build_classics.py` (`just pacote-classicos`) gera
`dist/classicos.zywny`: 43 peças, 0,9 MB, manifesto `classicos` /
"Clássicos para piano", não numerada, termo "peça"/f, `o` = catálogo (BWV,
Op., K.…; vazio em Satie, Joplin e Rimski), créditos com o musetrainer/library
(não OpenScore: a fonte mudou no B09). Títulos e compositores vêm da tabela
do script, não do XML.

Dificuldade: o `classificar-dificuldade.py` do Hymn_Grabber importado como
módulo (`medir` + `classificar`), sem mudar nada lá; os 43 formam o acervo do
quintil. A introdução copiada (`1i`) não aparece nos clássicos, então não
atrapalha. Níveis distribuídos 9/9/8/9/8.

Conferência à mão (aceite 1) — **o classificador erra com peça rápida de
ritmo uniforme**: ele foi pesado para hinos (síncopa e variedade pesam mais
que velocidade; salto cromático conta zero).
- Minueto em Sol: nível 1 — certo.
- Maple Leaf Rag: nível 5 — plausível (saltos e extensão).
- Prelúdio Op. 28 nº 4: nível 4 — alto para um professor (lento; pesa a
  densidade dos acordes), aceitável.
- Sonata K. 545, 1º mov.: nível 1 — baixo (escalas rápidas).
- O Voo do Besouro: nível 1 — **errado**: velocidade 9,3 ataques/s, 81 % de
  semicolcheias, mas ritmo 36 e saltos 0.
Também suspeitos: Tocata e Fuga (3) e 5ª Sinfonia (4) parecem baixos. Ajuste
pendente de decisão do usuário: pesos próprios para os clássicos (opção no
classificador) ou nível corrigido à mão em poucas peças.

Aceite 2: já coberto no B09 (`render.tsv`: as 43 renderizam e têm trilha).
Aceite 3 (manual, celular): pendente.

