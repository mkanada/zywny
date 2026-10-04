# zywny — tarefas do projeto (https://just.systems)
#
#   just            lista as receitas
#   just setup      libverovio.so + assets + pub get
#   just run        roda no Linux, sem Impeller
#
# Por que sem Impeller: o backend do Flutter no Linux não resolve o MSAA,
# então tudo que é vetorial sai serrilhado — flutter/flutter#191171,
# corrigido no master por flutter/flutter#191379 (23/08/2026), ainda fora
# do stable 3.47.4. Numa partitura, que é só path fino, o efeito é
# grosseiro. Quando o fix chegar ao stable, comparar com
# `just run-impeller` e apagar a flag daqui.

linux_bundle := "build/linux/x64/release/bundle/zywny"

# Chave pública das bibliotecas (D-BIB-CIFRA), lida de keys/ — fora do git —
# e embutida no app. Sem o arquivo, o app compila mas não instala biblioteca.
lib_key := "--dart-define=ZYWNY_LIBRARY_KEY=$(cat keys/biblioteca.public.b64 2>/dev/null)"

# Lista as receitas disponíveis.
default:
    @just --list

# Roda no Linux sem Impeller. Flags extras passam: `just run --release`.
run *ARGS:
    flutter run -d linux --no-enable-impeller {{lib_key}} {{ARGS}}

# Roda com Impeller (padrão do Flutter) — para reconferir #191171.
run-impeller *ARGS:
    flutter run -d linux {{lib_key}} {{ARGS}}

# Roda no Linux com o modo de debug do app (ScoreHomePage.debugMode: guarda
# o .vsb renderizado no diretório corrente, com data/hora no nome).
# `flutter run --debug` NÃO repassa isso para `main(args)` — é um flag do
# próprio `flutter run` (build mode, já é o padrão). Por isso precisa do
# --dart-entrypoint-args para chegar no Dart.
run-debug *ARGS:
    flutter run -d linux --no-enable-impeller {{lib_key}} --dart-entrypoint-args=--debug {{ARGS}}

# Build de release do bundle Linux.
build-release:
    flutter build linux --release {{lib_key}}

# O `flutter run` passa a flag pelo ambiente (FLUTTER_ENGINE_SWITCHES +
# FLUTTER_ENGINE_SWITCH_N), não por argv, então lançar o binário direto
# pede o mesmo par.
#
# Compila e roda o bundle de release sem Impeller.
run-release: build-release
    FLUTTER_ENGINE_SWITCHES=1 FLUTTER_ENGINE_SWITCH_1=enable-impeller=false ./{{linux_bundle}}

# Mockup de interface (lib/mockup/): telas sem o Verovio ligado no app,
# imagens de partitura pré-renderizadas em assets/mockup/. Entrada própria
# (lib/main_mockup.dart) — não mexe no banco de testes do motor acima.

# Roda o mockup no Linux, sem Impeller.
run-mockup *ARGS:
    flutter run -d linux --no-enable-impeller -t lib/main_mockup.dart {{ARGS}}

# APK de release do mockup (arm64 só, para instalar direto no celular).
build-mockup-apk:
    flutter build apk --release -t lib/main_mockup.dart --target-platform android-arm64

# Instala o APK de release do mockup no aparelho conectado (via adb).
install-mockup-apk: build-mockup-apk
    flutter install --release -t lib/main_mockup.dart -d android

# Bundle de release do mockup para Linux.
build-mockup-linux:
    flutter build linux --release -t lib/main_mockup.dart

# Regenera assets/mockup/partitura_*.png (verovio CLI + Chrome headless).
mockup-images:
    tool/build_mockup_images.sh

# Preparação completa a partir de um clone limpo.
setup: native assets
    flutter pub get

# Compila a libverovio.so do verovio_flutter_bridge (não versionada).
native:
    tool/build_verovio_linux.sh

# Gera assets/verovio_data.zip a partir de verovio/data (não versionado).
assets:
    tool/build_verovio_assets.sh

# Guarde cópia da privada fora do repositório: sem ela, nenhum app instalado
# aceita pacote novo.
# Gera o par de chaves das bibliotecas em keys/ (fora do git; não sobrescreve).
chaves:
    tool/library_crypto.py gen

# Uso privado, fora do git; rode de novo quando o extrator de lá mudar.
# Gera dist/hinos.zywny do Hymn_Grabber, cifrado e assinado com keys/ (`just chaves`).
pacote-hinos *ARGS:
    tool/build_hymn_assets.py {{ARGS}}

# APK de release (arm64 só, para instalar direto no celular). Rode antes
# `just native-android native-audio-android assets`, ao menos uma vez.
build-apk:
    flutter build apk --release {{lib_key}} --target-platform android-arm64

# Compila a libzywny_audio.so nativa (native/zywny_audio/, K02; não
# versionada).
native-audio:
    tool/build_audio_linux.sh

# Compila a libverovio.so para Android (arm64-v8a + x86_64, X01) e instala
# em android/app/src/main/jniLibs/<abi>/ (não versionado).
native-android:
    tool/build_verovio_android.sh

# Compila a libzywny_audio.so para Android (arm64-v8a + x86_64, K05) e
# instala em android/app/src/main/jniLibs/<abi>/ (não versionado).
native-audio-android:
    tool/build_audio_android.sh

# Roda o app de verdade (não o mockup) no Android — emulador ou aparelho
# conectado. Rode `just native-android` antes, ao menos uma vez.
run-android *ARGS:
    flutter run -d android {{lib_key}} {{ARGS}}

# Refotografa as telas do celular em docs/telas/celular/ — roda o app de
# verdade num emulador ou aparelho Android já ligado (o mesmo preparo do
# `build-apk`) e percorre o roteiro de integration_test/telas_celular_test.dart.
# Em profile: sem a faixa "DEBUG" e com o desempenho de uma versão final.
# Emulador sem janela e sem gravar nada no AVD:
#   emulator -avd Medium_Phone_2 -read-only -no-window -no-audio
# O app não traz música: ponha `dist/hinos.zywny` no aparelho (`adb push`) e passe
# `--dart-define=ZYWNY_TEST_LIBRARY=<caminho no aparelho>` em ARGS.
telas *ARGS:
    flutter drive --profile --driver=test_driver/telas_celular.dart \
        --target=integration_test/telas_celular_test.dart -d android {{lib_key}} {{ARGS}}

# Gera web/audio/ (SpessaSynth empacotado com esbuild, W04; não versionado).
# Precisa de node/npm e rede na primeira vez.
web-audio:
    tool/build_audio_web.sh

# Compila a versão Web (release). Antes: `tool/build_verovio_web.sh` e
# `just web-audio`, ao menos uma vez.
build-web:
    flutter build web --release {{lib_key}}

# Teste de fumaça da Web no Chromium headless (W03/W04) — roda `build-web`.
web-smoke: build-web
    node tool/web_smoke/smoke.mjs

# Refaz .so e assets depois que o verovio_flutter_bridge mudar.
rebuild-deps: native assets

# Teclado MIDI falso no ALSA sequencer (sem hardware; M01). Sem argumentos
# toca uma escala em laço; `just fake-midi 60 64 67 --once`, `just fake-midi
# --list`; `just fake-midi --relay` repassa um VMPK ligado por aconnect.
# Monitorar: `aseqdump -p <cliente>:0` (o script imprime a porta).
fake-midi *ARGS:
    tool/fake_midi_keyboard.py {{ARGS}}

# Testes Dart (headless — não passam pelo Impeller).
test:
    flutter test

# Análise estática.
analyze:
    flutter analyze

# Atualiza o grafo de contexto do graft/ (ver AGENTS.md).
graft:
    graft build
