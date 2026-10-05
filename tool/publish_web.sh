#!/usr/bin/env bash
# Publica a versão Web no GitHub Pages (https://mkanada.github.io/zywny/).
#
# Compila numa pasta limpa (build/web-pages, para não levar sobras do
# build/web) com `--base-href /zywny/`, ajusta a saída e troca o branch
# `gh-pages` do origin por um commit único com ela — force-push, para o
# histórico do repo não crescer 67 MB a cada publicação.
#
# `--so-montar` para antes do push (para testar a pasta localmente).
# Antes, ao menos uma vez: `tool/build_verovio_web.sh` e `just web-audio`.
# A chave pública vem de keys/ (D-BIB-CIFRA); sem ela o app publicado não
# instala biblioteca, então este script se recusa a seguir.
set -euo pipefail

cd "$(dirname "$0")/.."
out="$PWD/build/web-pages"
remote="$(git remote get-url origin)"

[ -s keys/biblioteca.public.b64 ] || { echo "falta keys/biblioteca.public.b64" >&2; exit 1; }
[ -f web/verovio/verovio-toolkit-hum.js ] || { echo "falta web/verovio/ (tool/build_verovio_web.sh)" >&2; exit 1; }
[ -f web/audio/zywny_audio.js ] || { echo "falta web/audio/ (just web-audio)" >&2; exit 1; }

rm -rf "$out"
# --no-web-resources-cdn: o CanvasKit sai daqui, não do gstatic, para o
# service worker poder guardá-lo (app instalado abre sem internet).
flutter build web --release --base-href /zywny/ --no-web-resources-cdn \
    --dart-define=ZYWNY_LIBRARY_KEY="$(cat keys/biblioteca.public.b64)" -o "$out"

# O zip de fontes do Verovio só serve ao nativo (o wasm já embute; W02).
rm -f "$out/assets/assets/verovio_data.zip"
# A soundfont é GPL-2: o aviso de copyright vai junto.
cp assets/soundfonts/TimGM6mb.copyright "$out/assets/assets/soundfonts/"
# Sem Jekyll: o Pages serve os arquivos como estão.
touch "$out/.nojekyll"
# PWA: preenche VERSION e PRECACHE do sw.js com o que este build tem.
python3 tool/web_precache.py "$out"

if [ "${1:-}" = "--so-montar" ]; then
    echo "montado em $out (sem publicar)"
    exit 0
fi

rev="$(git rev-parse --short HEAD)"
git diff --quiet HEAD -- lib web pubspec.yaml || rev="$rev + mudanças sem commit"
git -C "$out" init -q -b gh-pages
git -C "$out" add -A
git -C "$out" commit -q -m "Versão Web publicada (main $rev)"
git -C "$out" push -q --force "$remote" gh-pages:gh-pages
echo "publicado: main $rev → https://mkanada.github.io/zywny/ (o Pages leva ~1 min)"
