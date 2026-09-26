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

# Lista as receitas disponíveis.
default:
    @just --list

# Roda no Linux sem Impeller. Flags extras passam: `just run --release`.
run *ARGS:
    flutter run -d linux --no-enable-impeller {{ARGS}}

# Roda com Impeller (padrão do Flutter) — para reconferir #191171.
run-impeller *ARGS:
    flutter run -d linux {{ARGS}}

# Build de release do bundle Linux.
build-release:
    flutter build linux --release

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

# Compila a libzywny_audio.so nativa (native/zywny_audio/, K02; não
# versionada).
native-audio:
    tool/build_audio_linux.sh

# Refaz .so e assets depois que o verovio_flutter_bridge mudar.
rebuild-deps: native assets

# Testes Dart (headless — não passam pelo Impeller).
test:
    flutter test

# Análise estática.
analyze:
    flutter analyze

# Atualiza o grafo de contexto do graft/ (ver AGENTS.md).
graft:
    graft build
