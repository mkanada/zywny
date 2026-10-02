# U19 — Refazer as telas e conferir os achados

**Repo:** zywny · **Depende de:** todos os U executados · **Decisão
necessária:** nenhuma

## Objetivo

Fechar a fase: as fotos de `docs/telas/celular/` voltam a ser o retrato do
app, e cada achado do estudo é conferido contra a foto nova — resolvido,
resolvido em parte, ou ainda aberto.

## Ler antes (só isto)

- [U00](U00-ux-do-celular.md), a tabela "Achado → passo".
- `docs/ux/estudo-ux-celular.md` (inteiro — este é o passo que o lê todo).
- `docs/telas/celular/README.md`.
- `integration_test/telas_celular_test.dart` e
  `test_driver/telas_celular.dart`.
- As "Notas de execução" dos passos U concluídos.

## Contexto que você precisa

- `just telas` grava em `docs/telas/celular/` por padrão (`TELAS_DIR` muda
  o destino). Arquivos de nomes antigos **não** são apagados sozinhos: se
  um passo renomeou uma foto (o U03 troca `12-trilha-pede-teclado` por
  `12-ouvindo-o-trecho`), apague a antiga à mão.
- O roteiro tem duas passagens (primeiro uso; histórico + teclado falso) e
  numera as fotos de 01 a 46. Fotos novas entram no fim de cada passagem ou
  entre duas existentes com sufixo (`12b-…`) — **não renumere** as
  existentes: o estudo e as sugestões citam os números.
- As fotos são do emulador `Medium_Phone_2` (1080×2400), em profile, sem
  barra de status nem teclado virtual. Use o mesmo aparelho para as fotos
  serem comparáveis.
- O que as fotos mostram dos hinos é uma página do hino 5 (música de
  Beethoven) e a lista de títulos. O `.gitignore` mantém as partituras fora
  do repositório; não troque o hino do roteiro por outro sem perguntar.

## O que fazer

1. Rodar `just telas` no estado final. O roteiro tem de passar inteiro.
2. Olhar as 46 (ou mais) fotos, uma a uma.
3. Atualizar `docs/telas/celular/README.md` (nomes, descrições, o que as
   fotos não mostram).
4. Em `docs/ux/estudo-ux-celular.md`, acrescentar no fim a seção **"Depois
   da fase U"**: uma tabela achado → situação (resolvido / em parte /
   aberto), a foto que mostra, e uma linha do que mudou. Não reescreva os
   achados: o estudo é o registro de como estava.
5. Listar o que apareceu de novo nas fotos (problema que a fase criou ou
   revelou) — vira insumo para a próxima rodada, não é corrigido aqui.
6. Marcar a fase na tabela do `README.md` e no `U00`.

## Fora de escopo

- Corrigir o que a conferência achar (abre passo novo).
- Teste com alunos.
- Fotos de outros tamanhos de tela (um aparelho de 360 dp de altura seria o
  próximo a acrescentar — anote se fizer falta).

## Critérios de aceite

1. `just telas` passa; `docs/telas/celular/` não tem foto órfã (todo PNG
   está no README e vice-versa).
2. A seção "Depois da fase U" cobre os 25 achados altos e médios, cada um
   com a foto que o demonstra.
3. Nenhum achado **alto** está "aberto" sem uma linha explicando por quê
   (decisão sua pendente, ou passo não executado).
4. `just analyze` e `just test` limpos.

## Notas de execução

- `just telas` rodou três vezes. A 1ª falhou nas duas passagens por causa do
  próprio roteiro (a gaveta da trilha não oferece mais "Repetir um trecho",
  U11; o selo virou `PhoneScorePill`, U05): o roteiro foi corrigido. A 2ª
  passou e a conferência das fotos achou um defeito do U13 — a barra de
  progresso aparecia vazia (fatias com altura 0) —, corrigido com teste; a 3ª
  refez as fotos já com a barra certa.
- Foto nova: `12-ouvindo-o-trecho`; a antiga `12-trilha-pede-teclado` foi
  apagada. Nomes `08-…mudar-o-padrao` e `44-…calibrar-latencia` guardam o
  rótulo antigo (não renumerei nem renomeei).
- Conferência: seção "Depois da fase U" em `docs/ux/estudo-ux-celular.md`,
  com os 25 achados e a lista do que apareceu de novo. Só examinei com os olhos
  as fotos 02, 06, 11, 14, 19, 27, 30, 31, 32, 37, 39 e 42; as demais ficam
  como "pelos testes" na tabela.
- Achados altos ainda abertos: **A6** (decisão D-VIRADA = como está) e, em parte,
  A8 (primeira nota verde com a etapa parada) e A4 (traço do trecho irregular).
