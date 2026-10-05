# I13 — Conferência da fase I

**Repo:** zywny · **Depende de:** I01–I12 · **Decisão necessária:** não

## Objetivo

Fechar a fase como se fecha uma fase de tela: fotos novas, fumaça na Web,
o curso inicial feito no celular por uma pessoa, e a **regra 5 do I00**:
uma lição escrita por alguém de fora, só com a especificação e o modo
rascunho.

## Ler antes (só isto)

- [I00](I00-licoes-e-curso-inicial.md) inteiro.
- [U00](U00-ux-do-celular.md) "Como conferir uma mudança de tela"
  (`just telas`).
- `integration_test/telas_celular_test.dart` (o roteiro das fotos; `_wait`
  L126) e `tool/web_smoke/smoke.mjs` (a fumaça da Web).

## O que fazer

1. **`just telas`** — o roteiro ganha as telas da fase I, sem biblioteca
   instalada e com ela: cartão "Comece pelo curso inicial" (tela vazia);
   item "Cursos" na biblioteca; lista de cursos; tela do curso com uma
   lição feita, uma aberta e uma bloqueada; a lição 2 (retrato, rolada até a
   partitura e até o cartão do exercício); a tela de um exercício
   `play-notes` (paisagem) antes e depois da rodada (com o teclado falso do
   roteiro); um `name-note`; um `choice`; "Conecte o teclado". Fotos em
   `docs/telas/celular/` com os nomes no padrão das outras.
2. **Achados** — percorra as fotos com os princípios do U00 (legível no
   celular deitado, nada cobrindo a pauta, botões alcançáveis) e anote o
   que destoar das telas da biblioteca e do treino. Correção pequena: faça.
   Grande: vira passo novo (I14…) no I00.
3. **`just web-smoke`** — a fumaça abre o curso inicial, a lição 1 e um
   exercício de botões (sem MIDI no headless; o Web MIDI falso do W04, se
   der, para um `play-notes`).
4. **(manual, aparelho)** o curso inicial inteiro no celular com o
   teclado MIDI (I10 critério 5, se ainda não feito), anotando tempo por
   lição e onde travou.
5. **(manual, usuário) — a lição de fora (regra 5).** O usuário (ou alguém
   que ele chamar) escreve uma lição curta **sem olhar o código**: só
   `docs/licoes/formato-v1.md`, um editor de texto e o modo rascunho (I12)
   no desktop ou na Web. Sugestão de tema: "Mão esquerda: Dó, Fá e Sol na
   clave de fá", com um `play-notes`, um `choice` e um `play-score` curto.
   Cada tropeço (mensagem obscura, regra não escrita, exemplo que faltou)
   vira correção na especificação ou no validador, listada nas notas.
6. **Fechamento** — marque os passos no I00 e no `README.md`, atualize a
   memória do projeto e o mapa do código do README com `lib/course/`.

## Critérios de aceite

1. Fotos novas em `docs/telas/celular/` e a lista de achados nas notas.
2. `just web-smoke` verde.
3. Curso inicial feito no celular (registro do tempo e dos tropeços).
4. A lição de fora roda no rascunho sem ajuda, depois das correções; os
   tropeços e as correções, nas notas.
5. `just analyze` e `just test` limpos.

## Notas de execução

(vazio)
