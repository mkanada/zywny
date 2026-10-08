# U20 — "Sobre o Zywny" e o tutorial de primeiro uso

**Repo:** zywny · **Depende de:** U16 (primeiro uso), U17 (vocabulário) ·
**Decisão necessária:** nenhuma (as escolhas abaixo foram minhas; o usuário
pode revisar)

## Objetivo

Duas coisas pedidas pelo usuário em 2026-10-08:

1. Uma tela **"Sobre o Zywny"**: de onde vem o nome e o que o aplicativo quer
   ser.
2. O **tutorial inicial** que alguns aplicativos têm: um passeio que escurece
   a tela, recorta cada botão principal e explica o que ele faz.

O U16 deixou "tutorial passo a passo" fora de escopo de propósito (era só o
cartão "Comece por aqui"); este passo o faz.

## O que existe

| Peça | Onde |
| --- | --- |
| Motor do passeio: passos, película com recorte, cartão que escolhe o lado com espaço, remedição a cada 250 ms, teclas Esc e setas | `lib/tutorial/tour.dart` |
| "Já vi", por passeio e com versão | `lib/tutorial/tour_store.dart` (`tutorial_seen_library`, `tutorial_seen_score`) |
| Texto e alvos do passeio da biblioteca | `lib/tutorial/library_tour.dart` |
| Texto e alvos do passeio da partitura | `lib/tutorial/score_tour.dart` |
| A tela "Sobre o Zywny" | `lib/about/about_screen.dart` |
| O soundfont na página de licenças | `lib/about/licenses.dart` |
| Cores, tipos e o Z da marca (antes privados da abertura) | `lib/ui/brand.dart` |
| Seção **Ajuda** das configurações: "Rever o tutorial" e "Sobre o Zywny" | `lib/app/general_settings_panel.dart` |

## Como funciona

- **Biblioteca.** Na primeira abertura, com a lista e os cursos já na tela, o
  passeio começa sozinho — `LibraryScreen.tourDelay` espera a abertura
  (splash) sair, 2,4 s no app (zero nos testes). Os passos que o app tem
  agora: boas-vindas, Cursos, Músicas (instalar, só sem biblioteca), Busca,
  Por onde começar, Ordem, A lista, Teclado MIDI, Configurações, despedida.
  Passo cujo botão não está na tela é pulado; o contador ("3 de 8") só conta
  os que aparecem. Vale nas duas arrumações da biblioteca (retrato e duas
  colunas, no celular deitado).
- **Partitura.** Na primeira música aberta, só no layout de celular
  (`largura < kPhoneLayoutMaxWidth`): a janela larga do desktop é o banco de
  testes, com outros botões, e não tem passeio. Passos: A partitura, Voltar,
  A trilha (só no modo trilha), Som, Treinar (com o botão do ouvido, se
  houver), Reiniciar e compasso, Andamento e mão, Mais opções, despedida.
- **Visto.** Terminar, pular, Esc ou o "voltar" do aparelho contam como
  visto. `TourId.version` sobe quando o passeio muda tanto que vale mostrar de
  novo.
- **Rever.** Configurações → Ajuda → "Rever o tutorial" fecha as
  configurações e mostra o passeio da tela onde se estava. Na janela larga do
  desktop o item da partitura não aparece.
- **Sem registro (`tourStore == null`)** não há passeio: é o padrão dos
  testes, que não precisam saber dele.

## Escolhas minhas (não perguntadas)

- O **"Sobre" mora nas configurações**, não no cabeçalho da biblioteca (que
  em 360 dp já tem a engrenagem e o teclado).
- **Dois passeios**, um por tela, e o da partitura só na primeira música. Um
  passeio único cobrindo as duas telas obrigaria a abrir uma música à força.
- **O passeio aparece também para quem já usa o app**, uma vez, na primeira
  abertura depois de instalar esta versão.
- **Sem autoria no "Sobre"** (nome de quem fez, site, contato): o usuário
  decide se quer.
- **O texto do nome** diz "a partir de 1816" e não fixa o fim das aulas: as
  fontes divergem (1819, 1821 ou 1822). Fontes: Wikipédia (Wojciech Żywny),
  Instituto Nacional Fryderyk Chopin (nifc.pl), Polska Biblioteka Muzyczna.
  "Segundo se conta" cobre o episódio de Żywny reconhecer que não tinha mais o
  que ensinar. A pronúncia "JÍV-ni" é aproximada.
- **Os objetivos** só falam do que o app faz hoje. "Decorar" (fase L) e "letra
  no telão" (fase O) estão pendentes e ficaram de fora.
- **Licença do soundfont.** O TimGM6mb é GPL-2 e viaja no APK, mas o aviso de
  copyright não aparecia em lugar nenhum do app. `lib/about/licenses.dart` o
  registra e o `.copyright` entrou nos assets. Não registrei as licenças dos
  componentes nativos (Verovio, rustysynth, SpessaSynth): vale revisar.

## Testes

- `test/tour_test.dart` — o motor: ordem, voltar, pular, Esc, setas, passo
  sem alvo, alvo que se mexe, onde o cartão fica (inclusive celular deitado e
  texto grande).
- `test/tour_store_test.dart` — o "já vi" e a versão.
- `test/library_tour_test.dart` — a biblioteca de ponta a ponta (com e sem
  biblioteca, com cursos, duas colunas, 360 dp, "Rever" pelas configurações) e
  o retângulo recortado em cada passo.
- `test/score_tour_test.dart` — a partitura: cada recorte cerca o botão
  certo e o cartão nunca o cobre; visto, pular, desktop, "Rever".
- `test/about_screen_test.dart` — o texto, a versão, as licenças, três
  tamanhos de tela com fonte grande.
- `tool/web_smoke/smoke.mjs` — no navegador de verdade: o passeio abre
  sozinho, "Pular" fecha, fica no `localStorage` e não volta ao recarregar.
- `test/camadas_test.dart` pegou um import proibido (a "Sobre" importava
  `app/splash_screen.dart`); por isso as cores e o Z foram para `ui/brand.dart`.

## Pendente (manual, no aparelho)

1. Ler o texto do "Sobre" e o dos dois passeios, e aprovar ou devolver
   correções.
2. No celular de verdade, em paisagem, passar pelo passeio da partitura com o
   teclado ligado e sem ele (o texto de "Treinar" muda de sentido).
3. Conferir o passo "A trilha" numa música com trilha: nos testes e no Web ele
   aparece, mas não houve um aparelho.
4. `just telas`: as fotos do "Sobre" e dos passeios não entraram no roteiro de
   `integration_test/telas_celular_test.dart` (precisa de emulador); entram
   quando o aceite for feito.

## Fora de escopo

- Passeio pelas telas de curso, lição e exercício (cada lição já explica o
  que pede).
- Passeio no desktop largo.
- Dicas contextuais que aparecem depois (só o passeio de primeiro uso).
- Traduzir o texto (o app inteiro é em português).
