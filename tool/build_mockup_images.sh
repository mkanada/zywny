#!/usr/bin/env bash
# Gera assets/mockup/partitura_*.png a partir do corpus do
# verovio_flutter_bridge, para as telas-mockup em lib/mockup/ (interface de
# estudo, sem o motor Verovio ligado no app — ver docs/plano e o artefato
# "zywny — interface de estudo").
#
# Usa a CLI do fork (verovio/tools/verovio, já compilada) para gerar SVG e o
# Chrome headless para rasterizar em PNG (não há rsvg-convert/inkscape na
# máquina). Não versionado: regenerável a qualquer momento.
set -euo pipefail

proj_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
bridge_dir="/home/mauricio/rust_projects/verovio_flutter_bridge"
verovio_bin="$bridge_dir/verovio/tools/verovio"
data_dir="$bridge_dir/verovio/data"
input_mei="$bridge_dir/corpus/mei/Grieg_Little_bird_Op43_No4.mei"
chrome_bin="${CHROME_BIN:-/home/mauricio/bin/google-chrome}"
out_dir="$proj_dir/assets/mockup"

[[ -x "$verovio_bin" ]] || { echo "ERROR: $verovio_bin não existe — compile o fork (cd $bridge_dir/verovio/tools && cmake ../cmake && make -j4)" >&2; exit 1; }
[[ -x "$chrome_bin" ]] || { echo "ERROR: Chrome não encontrado em $chrome_bin (defina CHROME_BIN)" >&2; exit 1; }

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
mkdir -p "$out_dir"

# Tela padrão (Estudo/Treino/Painel): duas linhas de pauta dupla, tamanho normal.
"$verovio_bin" -r "$data_dir" -s 100 --page-width 2200 --page-height 1100 \
  --header none --footer none --no-instrument-labels --breaks auto \
  -p 1 -o "$work/padrao.svg" "$input_mei" >/dev/null

# Tela "tamanho grande": escala maior, uma linha só (para ler da estante).
"$verovio_bin" -r "$data_dir" -s 150 --page-width 2200 --page-height 830 \
  --header none --footer none --no-instrument-labels --breaks auto \
  -p 1 -o "$work/grande.svg" "$input_mei" >/dev/null

render_png() {
  local svg="$1" png="$2" w="$3" h="$4"
  # O Chrome headless (snap) só escreve fora de $HOME em alguns setups; usar
  # um diretório em $HOME evita ERR_FILE_NOT_FOUND silencioso.
  "$chrome_bin" --headless --disable-gpu --no-sandbox --hide-scrollbars \
    --window-size="${w},${h}" --default-background-color=00000000 \
    --screenshot="$png" "file://$svg" >/dev/null 2>&1
}

render_png "$work/padrao.svg" "$work/padrao_full.png" 2200 1100
render_png "$work/grande.svg" "$work/grande_full.png" 3300 1245

convert "$work/padrao_full.png" -trim +repage -bordercolor white -border 16 \
  "$out_dir/partitura_padrao.png"
convert "$work/grande_full.png" -trim +repage -crop 1232x614+0+0 +repage \
  -bordercolor white -border 16 "$out_dir/partitura_grande.png"

echo "Gerado $out_dir/partitura_padrao.png e partitura_grande.png"
