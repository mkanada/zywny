# B00 — Bibliotecas instaláveis (especificação da fase B)

**Repo:** zywny · Especificação; quem executa um passo B lê este arquivo
inteiro e o README.

## A ideia

Hoje o app traz os 600 hinos embutidos (`assets/hinos/`). Na fase B o app
passa a vir **vazio** e as músicas chegam em **bibliotecas instaláveis**:
um arquivo `.zywny` que a pessoa abre pelo seletor de arquivos. As duas
primeiras bibliotecas:

- **Hinos** — o hinário de hoje, gerado do Hymn_Grabber. Uso **privado**
  (as partituras têm direitos de terceiros): o arquivo passa de mão em mão,
  o app nunca diz de onde baixar e nada dele entra no git.
- **Clássicos** — cerca de 50 peças didáticas de piano solo em domínio
  público, do **OpenScore** (CC0): Anna Magdalena, Burgmüller, Czerny,
  Clementi, Schumann (Álbum para a Juventude)…

Uma biblioteca fica **em uso** por vez; a tela de músicas mostra só ela. A
troca é nas configurações gerais.

## Decisões (todas do usuário, 2026-10-04)

| Id | Decisão |
| --- | --- |
| D-BIB-DIST | Pacote de hinos é de uso privado: sem link de download no app, fora do git |
| D-BIB-VAZIO | O app novo vem sem nenhuma biblioteca; a primeira tela pede para instalar |
| D-BIB-ORIGEM | Só por arquivo (seletor do aparelho). Baixar por URL fica fora da fase |
| D-BIB-WEB | Linux, Android **e Web** nesta fase (Windows segue a fase X02 quando vier) |
| D-BIB-FONTE | Clássicos do OpenScore (CC0) — **redecidida em 2026-10-04**: o OpenScore não tem coleção de piano (ver B09); a fonte passou a ser o GitHub `musetrainer/library` (escolha do usuário) |
| D-BIB-REPERT | Piano didático, ~50 peças na primeira versão |
| D-BIB-DIFIC | Dificuldade dos clássicos pelo mesmo `classificar-dificuldade.py` do Hymn_Grabber |
| D-BIB-UMA | Uma biblioteca em uso por vez, trocada nas configurações gerais |
| D-BIB-REMOVER | Remover apaga as partituras e **guarda o progresso**; reinstalar recupera |
| D-BIB-ATUALIZAR | Pacote com `id` já instalado: **pergunta antes**, mostrando as duas versões (também quando a nova é mais antiga) |
| D-BIB-MIGRAR | O progresso de hoje (trilha, melhor nota, ajustes por hino) migra para a biblioteca de hinos |
| D-BIB-TERMO | O manifesto define como chamar cada música ("hino", "peça") |
| D-BIB-EXT | Extensão `.zywny` (um zip) |
| D-BIB-NOVA | Ao instalar, a biblioteca nova passa a ser a em uso |
| D-BIB-CIFRA | O `.zywny` vai **cifrado e assinado** (2026-10-04, usuário): a chave **privada** gera (assina) o pacote e só ela; a **pública** fica sob controle do usuário, fora do git, e entra no build. Nenhuma chave vai ao repositório remoto |

## O envelope: cifra e assinatura (D-BIB-CIFRA)

O arquivo `.zywny` **não é** um zip puro: é um envelope em volta do zip.

```
"ZYWN" | versão(1) | sal(32) | nonce(12) | cifra+tag | assinatura(64)
```

- **Assinatura:** Ed25519 sobre tudo antes dela (cabeçalho + cifra). Só a
  chave privada assina; o app só instala o que a chave pública dele confere.
  É o que impede pacote forjado.
- **Cifra:** AES-256-GCM do zip, `aad` = cabeçalho; a chave de conteúdo é
  `HKDF-SHA256(ikm = chave pública, salt = sal, info = "zywny-library-v1")`.
  Quem tem só o arquivo não lê as partituras; quem tem a chave pública (o
  app, o usuário) lê. Sal e nonce novos a cada geração.
- **Limite honesto:** como o app embute a chave pública para abrir o pacote,
  um atacante decidido que extraia a chave do binário também decifra. A cifra
  protege contra o arquivo solto; a assinatura, contra pacote forjado.
- **Chaves:** `keys/biblioteca.private.b64` e `keys/biblioteca.public.b64`
  (base64 de 32 bytes), `/keys/` no `.gitignore`. Gerar:
  `tool/library_crypto.py gen` (não sobrescreve). **Perder a privada** impede
  gerar pacotes que os apps já instalados aceitem — guarde cópia fora do
  repositório. A pública entra no app por
  `--dart-define=ZYWNY_LIBRARY_KEY=<base64>` (as receitas do `justfile` já
  leem de `keys/`); sem ela o app compila, mas recusa instalar.
- Código: `lib/library/library_envelope.dart` (Dart; `seal` só para testes),
  `tool/library_crypto.py` (gerador). O formato do envelope tem versão
  própria (byte 5); o `formato` do manifesto continua sendo o do zip.
- O app guarda o pacote **como veio** (envelope), então o arquivo também fica
  cifrado em disco/IndexedDB.

## O formato `.zywny` (versão 1)

O zip de dentro do envelope (deflate ou store) tem:

```
manifest.json
indice.json
partituras/<id>.musicxml.gz
```

`manifest.json`:

```json
{
  "formato": 1,
  "id": "hinos",
  "nome": "Hinário",
  "versao": "2026.10.04",
  "termo": { "singular": "hino", "plural": "hinos", "genero": "m" },
  "numerada": true,
  "creditos": "Texto livre: origem, licença, quem montou.",
  "idioma": "pt-BR"
}
```

- `formato`: inteiro. O app recusa formato maior que o que conhece, com
  mensagem ("esta biblioteca pede uma versão mais nova do zywny").
- `id`: `[a-z0-9-]{1,40}`. É a chave de tudo que o app guarda (progresso,
  ajustes, trilha) — **nunca muda** entre versões do mesmo pacote.
- `versao`: texto livre, comparado só para mostrar ("2026.10.04 → 2026.11.02");
  o app não decide sozinho qual é mais nova (D-BIB-ATUALIZAR).
- `termo.genero` (`m`/`f`): concordância nos textos ("Nenhum hino
  encontrado" / "Nenhuma peça encontrada", "ESTE HINO" / "ESTA PEÇA").
- `numerada`: se `true`, toda peça tem `n` e a ordem/rótulo "Número" existe;
  se `false`, somem.

`indice.json`: a lista de hoje (ver `Hymn.fromJson`, `lib/library/hymn.dart`),
com um campo novo obrigatório:

| Campo | Tipo | Hoje | Novo |
| --- | --- | --- | --- |
| `id` | texto `[A-Za-z0-9._-]{1,60}` | — | **obrigatório**; nome do arquivo em `partituras/`; nos hinos, `"001"` |
| `n` | int | obrigatório | só se `numerada` |
| `t`, `c`, `k`, `ck`, `q` | texto | obrigatórios | iguais |
| `l`, `o`, `nv`, `d`, `a` | | opcionais | iguais |

O `o` (título original) serve nos clássicos para o número de catálogo
("BWV Anh. 114", "Op. 100 nº 2").

## Onde o app guarda

- Pacote inteiro, como veio (bytes do envelope), um por `id`:
  - Linux/Android/Windows: `getApplicationSupportDirectory()/bibliotecas/<id>.zywny`
    (como o `SoundFontStore` guarda o `.sf2`).
  - Web: IndexedDB (banco `zywny`, store `bibliotecas`, chave = `id`). O
    `shared_preferences` da Web é localStorage (~5 MB) e o pacote de hinos
    tem ~3,1 MB — não serve.
- Ao abrir, o app lê o pacote em uso para a memória (`archive`), decodifica
  o índice e descompacta uma partitura só quando ela é aberta.
- `shared_preferences`: `library_active` (o `id` em uso) e
  `library_installed` (lista de `{id, nome, versao, termo}` para as
  configurações não precisarem abrir cada pacote).

## Chaves do que é guardado por música

Hoje tudo é pelo número do hino. Passa a ser por biblioteca + peça:

| Hoje | Depois |
| --- | --- |
| `hymn_progress` (mapa número → `{t, s}`) | `lib_progress_<lib>` (mapa id → `{t, s}`) |
| `hymn_settings_<n>` | `piece_settings_<lib>_<id>` |
| `trail_<n>` | `trail_<lib>_<id>` |

Remover a biblioteca **não** apaga essas chaves (D-BIB-REMOVER).

**Migração** (D-BIB-MIGRAR): na primeira vez que uma biblioteca com
`id == "hinos"` é instalada e existem chaves antigas, o app copia
`hymn_progress`/`hymn_settings_<n>`/`trail_<n>` para as chaves novas (o `id`
da peça é o número com três dígitos) e apaga as antigas. Uma vez só; uma
marca `library_migrated_v1` impede repetir.

## Telas

- **Sem biblioteca** (primeiro uso, ou depois de remover a última): no lugar
  da lista, um cartão "Instale uma biblioteca de músicas" com o botão
  **Abrir arquivo…** e uma linha explicando o que é o `.zywny`. Nenhuma
  menção a onde baixar (D-BIB-DIST).
- **Configurações gerais → Bibliotecas**: a lista das instaladas (nome,
  versão, quantas músicas), a em uso marcada; tocar numa troca a em uso;
  menu de cada uma com **Remover**; botão **Instalar outra…**.
- **Instalar**: valida → se o `id` já existe, diálogo "Substituir *Hinário*
  2026.10.04 por 2026.11.02?" → grava → vira a em uso (D-BIB-NOVA) → aviso
  "*Clássicos* instalada (48 peças)".
- Erros de instalação em português e específicos: não é zip, falta
  `manifest.json`, formato novo demais, índice com peça sem partitura, `id`
  inválido, etc. Nada é gravado se a validação falhar.

## O que não muda

- A partitura, o treino, a trilha e o decorar recebem bytes de MusicXML
  como hoje (`OpenedHymn.scoreXml`); a fase B só troca de onde eles vêm.
- O `MyApp.loadCatalog` continua injetável para os testes.

## Passos

B01 → B02 e B03 (paralelos) → B04 → B05 → B06 → B07 → B08. B09 → B10 podem
correr em paralelo a partir do B02. Ver a tabela no README.
