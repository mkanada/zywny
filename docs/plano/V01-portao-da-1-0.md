# V01 — Portão da 1.0: matriz de plataformas

**Repo:** zywny · **Depende de:** todos os passos anteriores ·
**Decisão necessária:** não

## Objetivo

Verificar, de ponta a ponta e em cada plataforma, que o usuário consegue
**treinar uma música no teclado MIDI**, e registrar o que falta. Não escreve
funcionalidade nova: só corrige bugs pequenos encontrados (bug grande vira
passo novo no README).

## Ler antes (só isto)

- Este README inteiro e as **Notas de execução** de todos os passos (são a
  fonte dos números que este portão confere).

## Contexto que você precisa

- Peças do roteiro: Gymnopédie (MusicXML, repetição), Maple Leaf Rag
  (MusicXML, 8 saltos, página alternativa), Scarlatti (MEI), Clair de Lune
  (8va), mais **uma peça de fora do corpus com 20+ páginas** (o
  usuário indica, ou baixe uma de domínio público do MuseScore/IMSLP em
  MusicXML e registre a origem).
- Roteiro por plataforma, na ordem de implementação (Linux, Android,
  Web/Chrome, Windows):
  1. Abrir a peça; tempo até a primeira página.
  2. Play com o sintetizador do app; sincronia som × destaque; pause/seek.
  3. Conectar teclado; monitor; saída MIDI para o teclado.
  4. Calibração.
  5. Modo espera mão direita, app toca a esquerda.
  6. Modo tempo real a 0,75×, resumo, loop nos piores compassos.
  7. Desconectar o teclado no meio; reconectar.
- Onde não houver hardware (ex.: aparelho Android real, Windows), o item fica
  **"não verificado"** com o motivo — não marque como aprovado.

## O que fazer

1. Rodar o roteiro e preencher a matriz abaixo.
2. `docs/relatorio-1.0.md` com a matriz, números (latências, tamanhos,
   tempos) e pendências priorizadas.

| Item | Linux | Android | Web | Windows |
| --- | --- | --- | --- | --- |
| Abrir peça / tempo | | | | |
| Play com som / sincronia | | | | |
| Entrada MIDI / monitor | | | | |
| Saída MIDI | | | | |
| Calibração (ms) | | | | |
| Modo espera | | | | |
| Tempo real + resumo | | | | |
| Loop / metrônomo | | | | |
| Reconexão | | | | |

## Critérios de aceite

1. Matriz preenchida (aprovado / falhou / não verificado + motivo).
2. `docs/relatorio-1.0.md` escrito.
3. `just analyze`, `just test`, `cargo test` (crate de áudio),
   `flutter test` do `score_bridge` limpos.

## Notas de execução

(preencher)
