# B06 — Bibliotecas nas configurações gerais

**Repo:** zywny · **Depende de:** B05 · **Decisão necessária:** não

## Objetivo

Uma seção **Bibliotecas** nas configurações gerais: ver as instaladas,
escolher a em uso, instalar outra, remover.

## Ler antes (só isto)

- [B00](B00-bibliotecas-instalaveis.md) "Telas".
- `lib/settings/general_settings_panel.dart`, o U17 (vocabulário das
  configurações) e o U18 (visual).

## O que fazer

1. Seção nova no topo das configurações gerais: uma linha por biblioteca
   (nome, versão, "600 hinos"), a em uso marcada; tocar numa troca a em uso
   e a biblioteca recarrega ao fechar o painel.
2. Menu da linha: **Remover…** com confirmação que diz que o progresso fica
   guardado (D-BIB-REMOVER). Remover a última leva ao cartão do B05.
3. Botão **Instalar outra…** chama o fluxo do B05.
4. Créditos do pacote (`creditos`) visíveis num "Sobre esta biblioteca".

## Critérios de aceite

1. Testes de widget: trocar, remover (a em uso e outra), instalar.
2. **(manual)** com hinos e clássicos instalados, trocar ida e volta: a
   lista, a ordem e o progresso de cada uma ficam certos; remover e
   reinstalar os hinos recupera a trilha.
3. `just telas` atualizado.

## Notas de execução

**Concluído em código (2026-10-04); falta o aceite manual 2–3.** `just
analyze` e `just test` limpos (11 testes novos em
`test/library_settings_test.dart`, passando pela `LibraryScreen` de verdade).

- `lib/settings/libraries_section.dart` (`LibrariesSection`): uma linha por
  biblioteca (nome, "em uso · " na ativa, "versão X · N termo-plural"),
  tocar numa troca a em uso; menu da linha com **Sobre esta biblioteca**
  (versão, quantidade e `creditos` do manifesto) e **Remover…** (confirmação
  diz que o progresso e os ajustes ficam, D-BIB-REMOVER); **Instalar outra…**
  chama o `installLibraryFromFile` do B05 (substituir pergunta, nova vira a em
  uso). Sem nenhuma: "Nenhuma biblioteca instalada.".
- Aparece **só nas configurações abertas pela biblioteca**
  (`GeneralSettingsScreen(libraryStore: …)` → `GeneralSettingsPanel(libraries:
  …)`, no topo); com uma partitura aberta o painel não mostra a seção.
- `InstalledLibrary` ganhou `credits` (guardado em `library_installed`, para
  "Sobre" não reabrir o pacote).
- A lista **recarrega ao fechar o painel** se a biblioteca em uso (ou a versão
  dela) mudou — por troca, substituição, instalação ou remoção; sem mudança,
  não recarrega (teste). Remover a última leva ao cartão do B05.
- **Pendente (manual):** (2) com hinos e clássicos de verdade, trocar ida e
  volta e remover/reinstalar os hinos para ver a trilha voltar — precisa do
  `clássicos.zywny` (B10) e de uma janela/aparelho; (3) `just telas`
  (aparelho).
