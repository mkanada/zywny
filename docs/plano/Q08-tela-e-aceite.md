# Q08 — Tela da transposição e aceite manual

**Repo:** zywny · **Depende de:** Q04, Q06, Q07 · **Decisão necessária:**
não (D-TRP-NOME decidida: "Transpor")

## Objetivo

A pessoa liga a transposição na gaveta, vê o selo na partitura, escolhe
outro tom se quiser, e o app passa no aceite com o teclado de verdade.

## Ler antes (só isto)

- [Q00](Q00-transpor-sem-acidentes.md): "Na tela", "Progresso separado por
  tom", "Critérios de aceite da fase".
- [U00](U00-ux-do-celular.md) (princípios e `just telas`), U11 (gaveta),
  U17 (vocabulário), U18 (visual).
- `lib/settings/general_settings_panel.dart` (para a chave geral).

## O que fazer

1. **Gaveta** (U11), item **"Transpor"**, só para música com `fifths`
   conhecido e diferente de 0 (com 0, o item mostra só "Escolher…"):
   - "Não (3♭)" — guarda `P1`;
   - "Sem acidentes" — subtítulo "teclado +3";
   - "Escolher…" — lista dos 12 tons (Q02 `toFifths`), cada linha com a
     armadura resultante e o TRANSPOSE ("Ré · 2♯ · teclado −1"); a original
     marcada "original".
   Trocar de tom com trilha começada pede a confirmação do Q04 ("Em Dó a
   trilha começa do zero. A do tom original fica guardada.").
2. **Selo na partitura** enquanto transposta: "Mi♭ → Dó · teclado +3"
   (ou "Mi♭ → Dó · o app toca no tom original" quando `appIsSound`). Tocar
   abre a conferência (Q06). No celular em paisagem, o selo cabe na barra
   sem tirar espaço da pauta (U10).
3. **Configurações gerais**: chave "Abrir as músicas já sem acidentes"
   (Q03), com subtítulo "Cada música pode voltar ao original na gaveta".
4. **Biblioteca**: na linha da música transposta, a armadura aparece como
   "3♭ → 0" (onde hoje aparece "3♭"). A ordenação por acidentes continua
   pela original.
5. **Tela da música / trilha**: "Também estudada: original, 3 de 8
   trechos" quando há progresso em outro tom (Q04).
6. `just telas`: telas novas da gaveta com "Transpor", da lista dos 12 tons,
   do selo e da folha de conferência.

## Aceite manual (com o teclado do usuário)

Linux, Android e Web, com o teclado MIDI do usuário:

1. Hino em Mi♭ (3♭): "Sem acidentes" → partitura em Dó; conferência pede
   +3; tocar Dó soa Mi♭; o app guarda o comportamento do teclado (anotar
   aqui: transpõe a saída? a entrada?).
2. Modo espera e tempo real passam tocando as teclas de Dó maior; "ouvir o
   trecho" soa em Mi♭, junto com o teclado.
3. Hino com sustenidos (2♯ ou 4♯): o mesmo, com TRANSPOSE negativo/positivo
   conforme a tabela.
4. Voltar a "Não": a trilha original reaparece; com o teclado ainda em +3,
   o detector avisa em até 6 notas erradas (se o teclado transpõe a saída
   MIDI; ajustar N se precisar) ou o lembrete de voltar a 0 aparece (se não
   transpõe).
5. Hino em 6♯ ou 6♭ (se existir no catálogo): trítono desce.

## Critérios de aceite

1. Testes de widget da gaveta (três escolhas, lista, confirmação), do selo e
   da chave geral.
2. `just telas` atualizado.
3. Aceite manual 1–5 registrado nas notas, com o modelo do teclado e o que
   ele faz com o TRANSPOSE no MIDI.

## Notas de execução

(vazio)
