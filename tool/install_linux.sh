#!/usr/bin/env bash
# Instala o zywny para o usuário (sem sudo) e o registra como o app que abre
# arquivos `.zywny`: clique duplo no gerenciador de arquivos, "Abrir com…".
#
#   tool/install_linux.sh            copia o bundle de release e registra
#   tool/install_linux.sh --remover  tira tudo (os dados do app ficam)
#
# Antes: `just build-release` (ou `just instalar-linux`, que faz as duas coisas).
# Tudo vai para ~/.local (ou $XDG_DATA_HOME): o app em share/zywny, o `.desktop`
# em share/applications, o tipo MIME em share/mime, o ícone em share/icons.
set -euo pipefail

root=$(cd "$(dirname "$0")/.." && pwd)
bundle="$root/build/linux/x64/release/bundle"
data=${XDG_DATA_HOME:-$HOME/.local/share}
app="$data/zywny"
desktop="$data/applications/com.example.zywny.desktop"
mime="$data/mime/packages/zywny.xml"
icons=("$data"/icons/hicolor/{192x192,512x512}/apps/zywny.png)

refresh() {
  # Cada um é opcional: sem eles o sistema relê na próxima sessão.
  command -v update-mime-database >/dev/null && update-mime-database "$data/mime" || true
  command -v update-desktop-database >/dev/null && update-desktop-database "$data/applications" || true
  command -v gtk-update-icon-cache >/dev/null && gtk-update-icon-cache -q -t "$data/icons/hicolor" 2>/dev/null || true
}

if [[ ${1:-} == --remover ]]; then
  rm -rf "$app"
  rm -f "$desktop" "$mime" "${icons[@]}"
  # Se o zywny era o padrão, o sistema esquece sozinho quando o .desktop some.
  refresh
  echo "zywny removido de $data (os dados do app ficam em $data/com.example.zywny)."
  exit 0
fi

[[ -x $bundle/zywny ]] || { echo "Sem bundle em $bundle: rode 'just build-release' antes." >&2; exit 1; }

mkdir -p "$app" "$(dirname "$desktop")" "$(dirname "$mime")"
# --delete: uma versão nova não deixa para trás arquivo da antiga.
rsync -a --delete "$bundle/" "$app/"

sed "s|@EXEC@|$app/zywny|g" "$root/linux/packaging/com.example.zywny.desktop" >"$desktop"
cp "$root/linux/packaging/zywny-mime.xml" "$mime"
for size in 192 512; do
  mkdir -p "$data/icons/hicolor/${size}x${size}/apps"
  cp "$root/web/icons/Icon-$size.png" "$data/icons/hicolor/${size}x${size}/apps/zywny.png"
done

refresh
# O padrão para o tipo: sem isso, o gerenciador pergunta qual app usar na
# primeira vez (e outros apps que abrem "application/octet-stream" não ganham).
command -v xdg-mime >/dev/null && xdg-mime default com.example.zywny.desktop application/x-zywny || true

echo "zywny instalado em $app"
echo "Arquivos .zywny agora abrem nele: $(xdg-mime query default application/x-zywny 2>/dev/null || echo '?')"
