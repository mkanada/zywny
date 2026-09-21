# zywny

App Flutter de e-learning musical: abre uma partitura (MEI/MusicXML), gera a
cena no formato `.vsb` (*Verovio Score Bridge*) em runtime via FFI e a desenha
com `CustomPaint`.

Os dois pacotes que fazem isso vivem no projeto
[`/home/mauricio/rust_projects/verovio_flutter_bridge`](https://github.com/mkanada/verovio_flutter_bridge):

- **`verovio`** (`verovio/bindings/dart`) — bindings FFI do fork do Verovio que
  exporta `.vsb` (`renderToBridgeFile`).
- **`score_bridge`** — parser do `.vsb` e `ScenePainter`, que desenha a página
  com paridade visual contra o SVG do próprio Verovio.

## Build

Com [`just`](https://just.systems) (`just` sozinho lista as receitas):

```sh
just setup   # submódulo + libverovio.so + assets/verovio_data.zip + pub get
just run     # flutter run -d linux --no-enable-impeller
```

Ou na mão:

```sh
tool/build_verovio_linux.sh               # compila e strippa a libverovio.so
tool/build_verovio_assets.sh              # gera assets/verovio_data.zip
flutter pub get
flutter run -d linux --no-enable-impeller
```

O `--no-enable-impeller` não é preferência: o backend Impeller no Linux não
resolve o MSAA e serrilha todo o vetorial — [flutter#191171][aa], corrigido no
master por [flutter#191379][aafix] (23/08/2026), ainda fora do stable 3.47.4.
Numa partitura, que é path fino, o resultado é grosseiro. Quando o fix descer
para o stable, comparar com `just run-impeller` e largar a flag.

[aa]: https://github.com/flutter/flutter/issues/191171
[aafix]: https://github.com/flutter/flutter/pull/191379

Os dois artefatos gerados pelos scripts não são versionados:

- `/home/mauricio/rust_projects/verovio_flutter_bridge/verovio/bindings/dart/libverovio.so` —
  `linux/CMakeLists.txt` a instala em `lib/` do bundle (RPATH `$ORIGIN/lib`);
  em `flutter run` ela é achada na árvore do projeto (`lib/native_paths.dart`,
  ou `VEROVIO_LIBRARY_PATH`).
- `assets/verovio_data.zip` — as fontes de gravação (`verovio/data`) num zip
  único, extraído na primeira execução por `lib/verovio_resources.dart`. Zip
  porque o bundler de assets do Flutter não recursa em diretórios.

Rode os dois scripts de novo sempre que o submódulo andar.
