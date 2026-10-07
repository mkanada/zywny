# R12 — Workspace na raiz e mockup fora do app

**Repo:** zywny · **Depende de:** — · **Decisão necessária:** sim, item 4
abaixo (o que fazer com `lesson_debug_main.dart`)

## Objetivo

Achado 10 da revisão, e o primeiro passo da divisão em pacotes: a raiz
vira um pub workspace, e o mockup sai do pacote do app para
`apps/zywny_mockup`, com os próprios assets. Os PNG do mockup deixam de
entrar no APK e no build Web.

## Ler antes (só isto)

- [Revisão](../revisao/2026-10-06-qualidade-e-divisao.md): achado 10 e
  "Divisão em pacotes".

## Contexto que você precisa

- Pub workspaces existem desde o Dart 3.6 / Flutter 3.27; aqui o SDK é
  `^3.13.3` e o Flutter local é 3.47.4. A raiz declara `workspace: [...]`;
  cada membro declara `resolution: workspace`; há um `pubspec.lock` só, na
  raiz.
- O mockup: `lib/main_mockup.dart`, `lib/mockup/` (6 arquivos) e
  `assets/mockup/partitura_padrao.png`/`partitura_grande.png` (120 KB,
  `pubspec.yaml` L118–L128). `lib/mockup/` importa `ui/theme.dart`,
  `ui/widgets.dart` e `practice/hand.dart` do app.
- Quem cita o mockup: `justfile` L52–L74 (`run-mockup`,
  `build-mockup-apk`, `install-mockup-apk`, `build-mockup-linux`,
  `mockup-images`), `tool/build_mockup_images.sh` (grava em
  `assets/mockup`), `docs/telas/INDICE.md` L8 e L56, `docs/plano/U18` L133.
- `lib/lesson_debug_main.dart` é a "entrada provisória" do I05 (ver
  `docs/plano/I05-leitor-de-licao.md` L157): abre uma lição solta, sem a
  biblioteca. Importa áudio, curso, configurações e tema. O modo rascunho
  do I12 pode tê-la tornado desnecessária.
- `score_bridge/` é um git subtree do `verovio_flutter_bridge`: torná-lo
  membro do workspace exige `resolution: workspace` no `pubspec.yaml` dele,
  o que diverge do repositório de origem. **Não** entra neste passo.
- **Não medido:** se um membro do workspace pode depender do pacote da
  raiz (`zywny: {path: ../..}`). Medir primeiro, com um `flutter pub get`.
  Se não der, a saída é extrair `ui/theme.dart`, `ui/widgets.dart` e
  `practice/hand.dart` para um `packages/zywny_ui` e anotar aqui.

## O que fazer

1. `pubspec.yaml` da raiz: `workspace: [apps/zywny_mockup]`.
2. `apps/zywny_mockup/`: `pubspec.yaml` (`resolution: workspace`, depende
   de `zywny` por path), `lib/main.dart` (o `main_mockup.dart`),
   `lib/mockup/…`, `assets/partitura_*.png`, e o `linux/`/`android/` que o
   `flutter create --platforms=linux,android .` gerar.
3. Tirar os assets do mockup do `pubspec.yaml` do app; ajustar os alvos do
   `justfile`, o `tool/build_mockup_images.sh` e os docs citados.
4. **Pergunte ao usuário** antes de mexer em `lesson_debug_main.dart`:
   apagar (se o modo rascunho do I12 já cobre o uso) ou mover para
   `apps/zywny_lesson_debug/`.
5. A regra do R01 "ninguém importa `mockup/**`" sai do teste de camadas
   (a pasta não existe mais).

## Fora de escopo

Os pacotes de verdade (R13–R17). `score_bridge` no workspace.

## Critérios de aceite

1. `ls lib/*.dart` mostra só `main.dart` (ou também `lesson_debug_main.dart`,
   se o usuário decidir mantê-lo).
2. `flutter pub get` na raiz resolve os dois pacotes; `just analyze` e
   `just test` limpos.
3. `just run-mockup` abre o mockup como antes **(manual)**.
4. O APK de release do app não contém `partitura_padrao.png` (`unzip -l`).

## Notas de execução


Feito em 2026-10-07.

- **Medido:** um membro do workspace pode depender do pacote da raiz por
  path (`zywny: {path: ../..}`); o `flutter pub get` na raiz resolve os
  dois. O `packages/zywny_ui` não foi preciso.
- Raiz: `workspace: [apps/zywny_mockup]` no `pubspec.yaml` (com um
  comentário sobre o `score_bridge` ficar de fora); os dois PNG saíram dos
  assets do app.
- `apps/zywny_mockup/`: `pubspec.yaml` (`resolution: workspace`, depende de
  `zywny` por path), `lib/main.dart` (era `lib/main_mockup.dart`),
  `lib/mockup/` (os 6 arquivos, com `package:zywny/ui/…` e
  `package:zywny/practice/hand.dart`), `assets/partitura_*.png` (movidos com
  `git mv`), `android/` e `linux/` do `flutter create --platforms=linux,android`
  (o `test/` de exemplo apagado), `README.md`. O mockup agora é outro app
  (`com.example.zywny_mockup`): antes o APK do mockup tinha o mesmo id do
  app e o substituía no celular. `minSdk` 26 como o app (os plugins dele vêm
  junto por `package:zywny`).
- `justfile`: os alvos do mockup rodam dentro de `apps/zywny_mockup`
  (sem `-t`); `tool/build_mockup_images.sh` grava em
  `apps/zywny_mockup/assets`; `docs/telas/INDICE.md`, a nota do U18, o
  comentário de `lib/practice/hand.dart` e o I05 atualizados.
- **Decisão do usuário (item 4):** `lib/lesson_debug_main.dart` apagado — o
  rascunho do I12 (`just curso <pasta>`) cobre o uso.
- Teste de camadas: `_entradasDoApp` só com `main.dart`; a regra de
  `mockup/` saiu (fica a de `app/`).
- Aceite: `ls lib/*.dart` só mostra `main.dart`; `flutter pub get` resolve;
  `just analyze` limpo (o analisador da raiz cobre `apps/` também).
  **`just run-mockup` (manual) não conferido:** nesta máquina o build Linux
  — do app e do mockup igualmente — para no CMake do `audioplayers_linux`
  (`gstreamer-1.0` pede `libunwind.pc`, e o `libunwind-dev` não está
  instalado; há o `libunwind-18-dev`). Não é deste passo.
- Critério 4: `just build-apk` refeito — `unzip -l` do
  `app-arm64-v8a-release.apk` não tem nenhum `partitura_*.png` (o de antes
  tinha os dois). O APK do mockup (`flutter build apk --release` em
  `apps/zywny_mockup`) compila e leva os dois em
  `flutter_assets/assets/`.
