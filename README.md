# zywny

App Flutter de e-learning musical: abre na biblioteca dos hinos que já traz
embutidos (`lib/library/`; o app não importa partitura), gera a cena do hino
escolhido no formato `.vsb` (*Verovio Score Bridge*) em runtime via FFI e a
desenha com `CustomPaint`.

Os dois pacotes que fazem isso vivem no projeto
[`/home/mauricio/rust_projects/verovio_flutter_bridge`](https://github.com/mkanada/verovio_flutter_bridge):

- **`verovio`** (`verovio/bindings/dart`) — bindings FFI do fork do Verovio que
  exporta `.vsb` (`renderToBridgeFile`).
- **`score_bridge`** — parser do `.vsb` e `ScenePainter`, que desenha a página
  com paridade visual contra o SVG do próprio Verovio.

## Configurações

Dois painéis, duas gavetas de dados — ambas em `SharedPreferencesAsync`, que
sobrevive a fechar o app e a instalar uma versão nova por cima:

- **Gerais** (`lib/settings/app_settings.dart`, painel
  `GeneralSettingsPanel`): som ligado, saída, instrumentos da partitura,
  metrônomo, tipo de treino e cores. Valem para todos os hinos; o
  painel abre pela engrenagem da biblioteca ou por "Configurações gerais" na
  partitura. Soundfont, monitor MIDI e latência já eram guardados à parte.
- **De cada hino** (`lib/settings/hymn_settings.dart`, painel `LayoutPanel`
  e a seção "Este hino" da gaveta): tamanho da notação e demais opções de
  layout, andamento e mão, numa chave `hymn_settings_<número>`. Só o que
  saiu do padrão é gravado, e a leitura descarta opção desconhecida ou valor
  fora da faixa — um JSON de outra versão do app nunca chega torto ao
  Verovio.

## Build

Com [`just`](https://just.systems) (`just` sozinho lista as receitas):

```sh
just setup   # libverovio.so + assets/verovio_data.zip + assets/hinos/ + pub get
just run     # flutter run -d linux --no-enable-impeller
```

Ou na mão:

```sh
tool/build_verovio_linux.sh               # compila e strippa a libverovio.so
tool/build_verovio_assets.sh              # gera assets/verovio_data.zip
tool/build_hymn_assets.py                 # gera assets/hinos/ (os hinos embutidos)
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

Os artefatos gerados pelos scripts não são versionados:

- `/home/mauricio/rust_projects/verovio_flutter_bridge/verovio/bindings/dart/libverovio.so` —
  `linux/CMakeLists.txt` a instala em `lib/` do bundle (RPATH `$ORIGIN/lib`);
  em `flutter run` ela é achada na árvore do projeto (`lib/native_paths.dart`,
  ou `VEROVIO_LIBRARY_PATH`).
- `assets/verovio_data.zip` — as fontes de gravação (`verovio/data`) num zip
  único, extraído na primeira execução por `lib/verovio_resources.dart`. Zip
  porque o bundler de assets do Flutter não recursa em diretórios.

- `assets/hinos/` — um `NNN.musicxml.gz` por hino e o `indice.json` (número,
  título, autores) que a biblioteca lista, gerados a partir de
  `/home/mauricio/IdeaProjects/Hymn_Grabber` (`musicxml/` e
  `musicxml_special/`). Fora do git também porque as partituras têm direitos
  de terceiros. Sem eles o app compila, mas a biblioteca abre vazia.

Rode os dois primeiros scripts de novo sempre que o submódulo andar, e o dos
hinos quando o extrator do Hymn_Grabber mudar.
