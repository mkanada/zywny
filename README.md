# zywny

App Flutter de e-learning musical: não traz música nenhuma — as músicas
chegam em **bibliotecas** (`.zywny`, cifradas e assinadas) que se instalam por
arquivo (`lib/library/`) e uma delas fica em uso. Gera a cena da música
escolhida no formato `.vsb` (*Verovio Score Bridge*) em runtime via FFI e a
desenha com `CustomPaint`.

Os dois pacotes que fazem isso vêm do projeto
[`verovio_flutter_bridge`](https://github.com/mkanada/verovio_flutter_bridge):

- **`verovio`** (`verovio/bindings/dart`) — bindings FFI do fork do Verovio que
  exporta `.vsb` (`renderToBridgeFile`).
- **`score_bridge`** — parser do `.vsb` e `ScenePainter`, que desenha a página
  com paridade visual contra o SVG do próprio Verovio.

### Repositórios vizinhos

O `pubspec.yaml`, o `linux/CMakeLists.txt`, os scripts de `tool/` e os testes
procuram dois checkouts **ao lado** deste repositório (um symlink basta):

```
../verovio_flutter_bridge   # obrigatório: o pacote `verovio` e a libverovio.so
../Hymn_Grabber             # opcional: só para o pacote de hinos e testes manuais
```

Por exemplo: `ln -s ~/rust_projects/verovio_flutter_bridge ../verovio_flutter_bridge`.
Fora do `pubspec.yaml`, as variáveis `VEROVIO_BRIDGE` e `HYMN_GRABBER`
sobrescrevem esses caminhos.

## Configurações

Dois painéis, duas gavetas de dados — ambas em `SharedPreferencesAsync`, que
sobrevive a fechar o app e a instalar uma versão nova por cima:

- **Gerais** (`lib/settings/app_settings.dart`, painel
  `GeneralSettingsPanel`): som ligado, saída, instrumentos da partitura,
  metrônomo, tipo de treino e cores. Valem para todos os hinos; o
  painel abre pela engrenagem da biblioteca ou por "Configurações gerais" na
  partitura. Soundfont, monitor MIDI e latência já eram guardados à parte.
- **De cada música** (`lib/settings/piece_settings.dart`, painel
  `LayoutPanel` e a seção "Este hino"/"Esta peça" da gaveta): tamanho da notação e demais
  opções de layout, andamento e mão, numa chave
  `piece_settings_<biblioteca>_<id>`. Só o que
  saiu do padrão é gravado, e a leitura descarta opção desconhecida ou valor
  fora da faixa — um JSON de outra versão do app nunca chega torto ao
  Verovio.

## Build

Com [`just`](https://just.systems) (`just` sozinho lista as receitas):

```sh
just setup   # libverovio.so + assets/verovio_data.zip + pub get
just chaves  # par de chaves das bibliotecas em keys/ (uma vez; fora do git)
just pacote-hinos   # dist/hinos.zywny, do Hymn_Grabber (uso privado)
just run     # flutter run -d linux --no-enable-impeller
```

Ou na mão:

```sh
tool/build_verovio_linux.sh               # compila e strippa a libverovio.so
tool/build_verovio_assets.sh              # gera assets/verovio_data.zip
tool/library_crypto.py gen                # keys/: o par de chaves das bibliotecas
tool/build_hymn_assets.py                 # gera dist/hinos.zywny (cifrado e assinado)
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

- `../verovio_flutter_bridge/verovio/bindings/dart/libverovio.so` —
  `linux/CMakeLists.txt` a instala em `lib/` do bundle (RPATH `$ORIGIN/lib`);
  em `flutter run` ela é achada na árvore do projeto (`lib/native_paths.dart`,
  ou `VEROVIO_LIBRARY_PATH`).
- `assets/verovio_data.zip` — as fontes de gravação (`verovio/data`) num zip
  único, extraído na primeira execução por `lib/verovio_resources.dart`. Zip
  porque o bundler de assets do Flutter não recursa em diretórios.

- `keys/` — o par de chaves das bibliotecas (Ed25519). A **privada** gera
  (assina e cifra) os pacotes e só existe com quem os gera; a **pública** é
  embutida no app (`--dart-define=ZYWNY_LIBRARY_KEY`, que as receitas do
  `justfile` leem daqui). Fora do git e **nunca vão ao repositório remoto**;
  guarde cópia da privada — sem ela nenhum app instalado aceita pacote novo.
  Sem a pública o app compila, mas recusa instalar biblioteca.
- `dist/hinos.zywny` — a biblioteca de hinos (`just pacote-hinos`), gerada a
  partir de `../Hymn_Grabber` (`musicxml/` e
  `musicxml_special/`, mais a dificuldade de `musicxml/_dificuldade.csv`). Fora
  do git porque as partituras têm direitos de terceiros: o arquivo passa de mão
  em mão e o app nunca diz de onde baixar.

Rode os dois primeiros scripts de novo sempre que o submódulo andar, e
`just pacote-hinos` quando o extrator do Hymn_Grabber mudar.
