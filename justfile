# zywny — tarefas do projeto (https://just.systems)
#
#   just            lista as receitas
#   just setup      submódulo + libverovio.so + assets + pub get
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

# Preparação completa a partir de um clone limpo.
setup: submodules native assets
    flutter pub get

# Traz/atualiza third_party/verovio_flutter_bridge.
submodules:
    git submodule update --init --recursive

# Compila a libverovio.so do submódulo (não versionada).
native:
    tool/build_verovio_linux.sh

# Gera assets/verovio_data.zip a partir de verovio/data (não versionado).
assets:
    tool/build_verovio_assets.sh

# Refaz .so e assets depois que o submódulo andar.
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
