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
