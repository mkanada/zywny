# Q01 — Medir o Verovio transpondo

**Repo:** zywny (medição; código no bridge só se algo quebrar) · **Depende
de:** — · **Decisão necessária:** não (D-TRP-\* decididas no Q00)

## Objetivo

Confirmar, com números, que a opção `transpose` do fork gera um `.vsb`
inteiro e coerente na altura **escrita**, para que os passos seguintes
confiem nele sem conferir de novo.

## Ler antes (só isto)

- [Q00](Q00-transpor-sem-acidentes.md): "As três alturas", "Como escolher a
  transposição", "Onde a transposição acontece".
- README, "Fork do Verovio" (tabela do mapa do código).

## Contexto que você precisa

- A opção: `verovio/src/options.cpp` L1685 (`m_transpose`), aplicada em
  `Toolkit::LoadData` (`src/toolkit.cpp` L872) por `Doc::TransposeDoc`
  (`src/doc.cpp` L1656). Sintaxe do intervalo
  (`Transposer::IsValidIntervalName`, `src/transposition.cpp` L2051):
  `(-|\+?)([Pp]|M|m|[aA]+|[dD]+)([1-9][0-9]*)` — `-m3`, `P4`, `-A4`, `d5`,
  `A1`.
- O doc expandido das repetições (`Toolkit::SetMidiDoc`, L288) é importado do
  MEI do doc **já transposto** (`MEIInput::Import(GetMEI())`), sem passar de
  novo por `LoadData`. Por isso não deve transpor duas vezes — mas confira.
- Hinos em MusicXML: `/home/mauricio/IdeaProjects/Hymn_Grabber/musicxml/`
  (584 arquivos). CLI: `verovio/tools/verovio -r verovio/data` no bridge.
- **Já medido (2026-10-04, CLI, hino `013`, 3♭, `--transpose=-m3`)**: MIDI
  com as mesmas 561 notas, todas 3 semitons abaixo (63→60, 70→67…); a
  armadura passou de 24 `keyAccid` para 0; acidentes **visíveis** continuaram
  7 (5 bequadros viraram sustenidos, 2 bemóis viraram bequadros). Os
  elementos `accid` totais subiram de 136 para 245, mas os novos são
  gestuais (sem glifo). Falta medir o caminho do app (`.vsb`).

## O que fazer

1. Script de medição em `tool/` (Python, como os outros) que, para uma
   amostra de hinos de **cada armadura presente** no catálogo (de −7 a +7,
   o que existir), gera o `.vsb` original e o transposto pelo intervalo da
   tabela do Q00 (CLI `-t vsb --transpose=…`), e compara:
   - `notes.json`: mesmo número de notas, mesmos ids, `pitch` = original + k
     em **todas**;
   - `timemap`: mesmos `tstamp`, mesmos ids em `on`/`off`;
   - cena: armadura inicial vazia; contagem de acidentes visíveis antes e
     depois; nenhum dobrado sustenido/bemol (ou quantos);
   - repetições: num hino com ritornelo (ver `corpus/repeticoes` no bridge),
     ids `-rend<N>` iguais e pitch deslocado **uma vez só**;
   - `alternates` (se o hino tiver): mesmos ids.
2. Mudança de armadura no meio: listar os hinos com mais de uma armadura e
   a armadura que sobra depois de transpor. Dizer se dá para ler isso do
   `.vsb` (para o aviso "a partir do compasso N…" do Q00) e a que custo.
3. Tempo de render no app (Linux, `renderScoreToVsb`) com e sem transposição,
   em 3 hinos; diferença esperada desprezível.
4. Determinismo: renderizar o original duas vezes e comparar os bytes (o
   critério 6 da fase depende disso). Se não for determinístico, dizer o que
   muda e trocar o critério por "mesmos `notes.json`/timemap".
5. Faixa: a nota mais grave e a mais aguda do catálogo depois de transpor,
   para cada direção — quantos hinos sairiam de A0–C8 (esperado: nenhum) e
   de um teclado de 61 teclas (C2–C7).

## Fora de escopo

Mudar o app (Q03 em diante). Mexer no fork — só se um critério falhar; nesse
caso, o conserto vai para o plano do bridge (prefixo G) e este passo anota.

## Critérios de aceite

1. Tabela por armadura nas notas de execução: hinos testados, notas, todas
   deslocadas por k, ids iguais, acidentes visíveis antes/depois.
2. Repetição sem transposição dupla, com o hino citado.
3. Tempos medidos e resposta sobre determinismo.
4. Lista dos hinos com mudança de armadura e a decisão sobre o aviso.

## Notas de execução

(vazio)
