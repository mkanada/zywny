# U14 — Biblioteca: ordenar e buscar

**Repo:** zywny · **Depende de:** — · **Decisão necessária:** D-ORDEM (só
para a seta)

## Objetivo

A seta da ordenação aponta para a ordem que a lista realmente tem, e a
busca mostra por que cada hino apareceu. Achados C3 e C4; sugestões C3 e
C4.

## Ler antes (só isto)

- [U00](U00-ux-do-celular.md) e as sugestões **C3** e **C4**.
- Telas `02`, `05`, `28` (as setas), `03` ("santo" traz "Cristo — Jader D.
  Santos") e `04` (sem resultado).
- `lib/library/library_sort.dart` (132 linhas, inteiro): `SortKey`,
  `defaultAscendingFor` L15-L21, `SortState.toggled` L41-L43, `arrowFor`
  L47-L50, `sortedHymns`, `filterHymns` L99-L110.
- `lib/library/hymn.dart` (114 linhas): `Hymn` (`title`, `composer`,
  `lyricist`, `originalTitle`, `titleKey`, `composerKey`, `searchKey`),
  `foldForSearch` L104-L114.
- `lib/library/library_screen.dart`: `_searchField` L313-L338, `_sortChips`
  L414-L446, `_list` L448-L478, `_HymnRow` L481-L594, `_SortChip`
  L596-L631.
- `tool/build_hymn_assets.py`: `fold` L61 e a linha que monta `q` (L136):
  número, título, título original, compositor e letrista, nessa ordem.
- `test/library_test.dart`: grupos `busca` L64-L86 e `ordenação` L87-L200,
  e o teste de widget "busca filtra e os chips reordenam" L250.

## Contexto que você precisa

- **Seta.** `arrowFor` devolve "↓" quando a direção é a **padrão** da
  chave e "↑" quando é a invertida — regra copiada do artboard. Como o
  padrão de "Número" é crescente e o de "Pontuação" é decrescente, "↓"
  aparece nas duas com ordens opostas. **D-ORDEM, recomendação:** a seta
  mostra a ordem real — "↑" crescente, "↓" decrescente. A direção inicial
  de cada chave não muda. Alternativa: manter o artboard.
- **Fila de pastilhas.** Seis pastilhas numa `ListView` horizontal; em
  411 dp cabem quatro, e "Pontuação" e "Compositor" ficam fora da tela, com
  um pedaço de borda como única pista.
- **Busca.** `filterHymns` exige que todas as palavras apareçam em
  `searchKey` (número + título + título original + compositor + letrista,
  sem acento) e devolve na ordem da lista ordenada. A linha do hino só
  mostra título e compositor: quando o casamento é no letrista ou no título
  original, o aluno não vê o motivo.
- `searchKey` é texto dobrado (sem acento, minúsculo). Para negritar no
  título exibido é preciso achar o trecho no texto **original**:
  `foldForSearch` troca um caractere por um e transforma pontuação em
  espaço, então os índices não batem direto — dobre caractere a
  caractere guardando o índice de origem.
- A busca por dígitos (número do hino, pelo começo) tem regra própria e
  continua igual.
- O U13 mexe na segunda linha do `_HymnRow`. Se ele já foi feito, o "campo
  que casou" substitui o compositor na segunda linha enquanto houver busca;
  se não foi, substitui o texto de hoje.

## O que fazer

1. **Seta** (se D-ORDEM aprovar): `arrowFor` passa a devolver "↑" para
   `ascending` e "↓" para descendente. Atualizar os testes que esperam o
   desenho antigo.
2. **Fila**: um esmaecido na borda direita enquanto houver pastilhas fora
   da tela (`ShaderMask` ou um `DecoratedBox` com gradiente por cima); some
   ao rolar até o fim.
3. **Ordem dos resultados** em `filterHymns`: primeiro os que casam todas
   as palavras no **título**; depois os demais; dentro de cada grupo, a
   ordem atual. (A busca por dígitos não muda.)
4. **Por que casou**: função pura `hymnMatch(hymn, query)` → em que campo
   casou (`title`, `originalTitle`, `composer`, `lyricist`) e os intervalos
   a negritar no texto original. `_HymnRow` recebe o resultado:
   - negrito nos trechos casados do título e do compositor;
   - casou só no letrista ou no título original → a segunda linha mostra
     "letra: Reginald Heber" ou "original: Holy, Holy, Holy", com o
     negrito.
5. **Sem resultado**: "Nenhum hino com “chopin”." e um botão "Limpar a
   busca" (o campo precisa de um `TextEditingController` para isso; aproveite
   para pôr o "×" de limpar no próprio campo quando há texto).
6. Testes em `test/library_test.dart`: ordem título-primeiro; `hymnMatch`
   com acento ("Abraão" × "abraao"), com pontuação ("Santo, Santo") e com
   casamento só no letrista; a seta.

## Fora de escopo

- Filtros (por nível, "em andamento").
- Busca aproximada (erro de digitação).
- Tirar ou acrescentar critérios de ordenação.

## Critérios de aceite

1. Teste: "santo" devolve primeiro os hinos com "santo" no título; "Cristo
   — Jader D. Santos" vem depois deles.
2. Teste: `hymnMatch` devolve os intervalos certos em "Ao Deus de Abraão
   Louvai" para "abraao".
3. Teste de widget: busca que casa só no letrista mostra "letra: …" na
   segunda linha.
4. Teste de widget: sem resultado, "Limpar a busca" esvazia o campo e a
   lista volta.
5. Teste (se D-ORDEM): "Número" crescente mostra "↑"; "Pontuação"
   decrescente mostra "↓".
6. `just telas`: telas 03, 04, 05 e 28 refeitas conferem. O roteiro usa
   `find.textContaining('Dificuldade')` etc. — continua valendo.
7. `just analyze` e `just test` limpos.
