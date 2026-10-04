# B09 — Curadoria dos clássicos (OpenScore)

**Repo:** zywny · **Depende de:** — · **Decisão necessária:** sim, a lista
final (o usuário aprova)

## Objetivo

Uma lista de ~50 peças didáticas de piano solo, em domínio público, com
fonte CC0 do OpenScore, cobrindo do nível mais fácil ao intermediário.

## Contexto que você precisa

- Fonte decidida: **OpenScore** (D-BIB-FONTE). **Não verificado ainda**:
  em que formato o acervo de piano está disponível (os corpora no GitHub —
  Lieder, quartetos — vêm em MuseScore `.mscx`; as peças de piano podem
  estar só no musescore.com). Se precisar converter, o caminho é o
  MuseScore 4 em linha de comando (`mscore -o x.musicxml x.mscx`).
  Registrar o que achar.
- Repertório (D-BIB-REPERT): Caderno de Anna Magdalena Bach, Burgmüller
  Op. 100, Czerny (Op. 599/139), Clementi Sonatinas Op. 36, Schumann Op. 68,
  Kabalevsky não (direitos), Bartók Mikrokosmos não (direitos). Confirmar
  domínio público de cada **edição** (a licença do arquivo é CC0, mas
  conferir que a edição não traz dedilhado/texto de editor protegido).

## O que fazer

1. Levantar o que o OpenScore tem nesse repertório, formato e licença.
2. Propor ~50 peças numa tabela: título, compositor, catálogo, link,
   licença, observação. **Parar e pedir aprovação do usuário.**
3. Baixar as aprovadas para uma pasta fora do repo (ex.:
   `~/IdeaProjects/zywny_classicos/`), com um script reproduzível.

## Critérios de aceite

1. Tabela aprovada pelo usuário, registrada nas notas.
2. Script de download/conversão versionado em `tool/`.
3. Todas abrem no Verovio sem erro (o mesmo render do app, em lote).

## Notas de execução

**Premissa da fonte caiu (2026-10-04); o usuário adiou e, em seguida, indicou outra fonte: `musetrainer/library` (ver a proposta no fim).** Levantamento (passo 1): o OpenScore tem **três
coleções — Lieder, quartetos de cordas e obras orquestrais** — e no GitHub só
`OpenScore/Lieder` e `OpenScore/StringQuartets` (confirmado por `gh api
orgs/OpenScore/repos`); a página do projeto não cita coleção de piano nem
Anna Magdalena/Burgmüller. As peças de piano solo que existem no musescore.com
são partituras avulsas (às vezes de usuário comum, não da conta OpenScore), com
download por login e licença por arquivo — sem como baixar em lote nem garantir
CC0. Logo **D-BIB-FONTE (OpenScore) não se sustenta** para piano didático.
Alternativas apresentadas: o usuário fornece os MusicXML numa pasta (a mais
segura para licença); IMSLP peça a peça (anexos MusicXML com licença por
arquivo, cobertura incerta); Mutopia (acervo bom, mas LilyPond/MIDI, sem
conversão para MusicXML). Escolha: **adiar**. Quando retomar, decidir a fonte
de novo (D-BIB-FONTE reaberta) antes de montar a lista.

## Proposta de curadoria (2026-10-04) — aguardando aprovação do usuário

**Fonte (decisão do usuário):** [musetrainer/library](https://github.com/musetrainer/library), clone `9128876f61` (29/11/2024), 69 `.mxl`. Baixados e extraídos por `tool/fetch_classics.py` para `~/IdeaProjects/zywny_classicos/` (`xml/`, `metadados.tsv`).

**O que o levantamento achou (importa para a aprovação):**

- O repositório **não tem arquivo de licença** e nenhum metadado de licença por arquivo; só diz, no título, “Public Domain MusicXML files”. Os arquivos são **uploads de comunidade do MuseScore** (versões 0.9 a 4.0), **não** do OpenScore/CC0. Dos 69, só 3 declaram domínio público no próprio `<rights>` (Minueto BWV Anh. 114, Prelúdio Op. 28 nº 4, The Entertainer 1902); 1 traz “©” e 3 trazem selo de site.
- Quase todas as peças são **domínio público como composição** (Bach, Beethoven, Chopin…), mas cada arquivo é uma **transcrição/arranjo de terceiros**, cujos direitos não dá para verificar. Para uso privado o risco é baixo; para distribuir o pacote a outros, fica a dúvida. A lista abaixo já tira o que é claramente protegido ou duvidoso.
- O acervo é de **clássicos populares**, não do repertório didático do D-BIB-REPERT: **não há Burgmüller, Czerny, Clementi nem Álbum para a Juventude**. Há várias peças avançadas (Campanella, Balada, Tocata e Fuga).
- **Técnico (aceite 3):** as 69 abrem no Verovio sem erro e têm trilha (`test/classics_batch_manual_test.dart`, resultado em `render.tsv`). Duas esquisitices: `G_Minor_Bach` (2 partes, pautas 1,2,3) e a Balada (2 partes, pauta 4), fora da lista ou marcadas.
- Título/compositor faltam em 22 arquivos (vêm só do nome do arquivo); na montagem do pacote os títulos serão os da tabela, não os do XML.

### Incluir — grupo A: composição em domínio público, edição sem marca de direitos (34)

| Peça | Compositor | Compassos | Etapas | Arquivo | Observação |
| --- | --- | --- | --- | --- | --- |
| Minueto em Sol (BWV Anh. 114) | Bach/Petzold | 32 | 99 | `Bach_Minuet_in_G_Major_BWV_Anh._114.mxl` | declara “Public Domain (PianoXML typeset)” |
| Prelúdio nº 1 em Dó (BWV 846) | Bach | 34 | 111 | `Prelude_I_in_C_major_BWV_846_-_Well_Tempered_Clavier_First_Book.mxl` |  |
| Prelúdio nº 2 em Dó menor (BWV 847) | Bach | 38 | 123 | `Prelude_No._2_BWV_847_in_C_Minor.mxl` |  |
| Cânone em Ré (fácil) | Pachelbel | 49 | 147 | `Canon_in_D_easy.mxl` | versão simplificada |
| Cânone em Ré | Pachelbel | 102 | 315 | `Canon_in_D.mxl` |  |
| Für Elise (fácil) | Beethoven | 22 | 75 | `Fur_Elise_Easy_Piano.mxl` | versão simplificada |
| Für Elise (iniciante) | Beethoven | 24 | 63 | `Fur_Elise_-_Beethoven_-_for_beginner_piano.mxl` | versão simplificada |
| Für Elise | Beethoven | 106 | 315 | `Fur_Elise.mxl` |  |
| Ode à Alegria (variação fácil) | Beethoven | 17 | 51 | `Ode_to_Joy_Easy_variation.mxl` | versão simplificada |
| Gymnopédie nº 1 | Satie (m. 1925) | 78 | 243 | `Gymnopdie_No._1__Satie.mxl` |  |
| Gnossienne nº 1 | Satie (m. 1925) | 11 | 39 | `Gnossienne_No._1.mxl` |  |
| Prelúdio Op. 28 nº 4 | Chopin | 26 | 75 | `Prlude_No._4_in_E_Minor_Op._28_-_Frdric_Chopin.mxl` | declara “Public Domain” |
| Noturno Op. 9 nº 2 | Chopin | 38 | 111 | `Chopin_-_Nocturne_Op_9_No_2_E_Flat_Major.mxl` |  |
| Noturno Op. 9 nº 1 | Chopin | 86 | 255 | `Chopin_-_Nocturne_Op._9_No._1.mxl` |  |
| Valsa em Lá menor (B. 150) | Chopin | 57 | 171 | `Waltz_in_A_MinorChopin.mxl` | título/compositor só no nome do arquivo |
| Valsa Op. 64 nº 2 | Chopin | 194 | 579 | `Waltz_Opus_64_No._2_in_C_Minor.mxl` |  |
| Noturno em Dó# menor (póstumo) | Chopin | 65 | 183 | `Nocturne_in_C_sharp_Minor.mxl` |  |
| Arabesque nº 1 | Debussy (m. 1918) | 107 | 327 | `Arabesque_L._66_No._1_in_E_Major.mxl` |  |
| Clair de Lune | Debussy (m. 1918) | 72 | 219 | `Clair_de_Lune__Debussy.mxl` |  |
| Liebestraum nº 3 | Liszt | 88 | 267 | `Liebestraum_No._3_in_A_Major.mxl` |  |
| Sonata ao Luar, 1º mov. | Beethoven | 69 | 207 | `Sonate_No._14_Moonlight_1st_Movement.mxl` |  |
| Sonata Patética, 2º mov. | Beethoven | 73 | 219 | `Sonate_No._8_Pathetique_2nd_Movement.mxl` |  |
| Sonata K. 545, 1º mov. | Mozart | 73 | 219 | `Sonata_No._16_1st_Movement_K._545.mxl` |  |
| Rondo alla Turca (K. 331) | Mozart | 137 | 387 | `Piano_Sonata_No._11_K._331_3rd_Movement_Rondo_alla_Turca.mxl` |  |
| Dança Húngara nº 5 | Brahms | 102 | 315 | `Hungarian_Dance_No_5_in_G_Minor.mxl` |  |
| The Entertainer | Joplin (1902) | 92 | 267 | `The_Entertainer_-_Scott_Joplin_-_1902.mxl` | declara “Public Domain” |
| Maple Leaf Rag | Joplin (1899) | 85 | 243 | `Maple_Leaf_Rag_Scott_Joplin.mxl` |  |
| Sonata ao Luar, 3º mov. | Beethoven | 201 | 603 | `moonlight_sonata_3rd_movement.mxl` | avançada |
| Tocata e Fuga em Ré menor | Bach | 143 | 435 | `Bach_Toccata_and_Fugue_in_D_Minor_Piano_solo.mxl` | avançada; transcrição para piano |
| O Voo do Besouro | Rimski-Kórsakov | 101 | 303 | `Flight_of_the_Bumblebee.mxl` | avançada; transcrição |
| La Campanella | Liszt | 150 | 447 | `La_Campanella_-_Grandes_Etudes_de_Paganini_No._3_-_Franz_Liszt.mxl` | avançada |
| Balada nº 1 Op. 23 | Chopin | 262 | 699 | `Chopin_-_Ballade_no._1_in_G_minor_Op._23.mxl` | avançada; arquivo com 2 partes e pauta 4 |
| 12 Variações “Ah vous dirai-je, maman” (K. 265) | Mozart | 325 | 975 | `12_Variations_of_Twinkle_Twinkle_Little_Star.mxl` | 325 compassos; 26 saltos de repetição |
| 5ª Sinfonia, 1º mov. (piano solo) | Beethoven | 504 | 1515 | `Beethoven_Symphony_No._5_1st_movement_Piano_solo.mxl` | redução para piano; 504 compassos |

### Incluir se você aceitar — grupo B: composição em domínio público, mas o arquivo é redução/arranjo de autor desconhecido ou creditado (9)

| Peça | Compositor | Compassos | Etapas | Arquivo | Observação |
| --- | --- | --- | --- | --- | --- |
| O Lago dos Cisnes (tema) | Tchaikovsky | 32 | 87 | `Swan_Lake.mxl` | redução para piano sem autor |
| Dança da Fada Açucarada | Tchaikovsky | 53 | 159 | `Dance_of_the_sugar_plum_fairy.mxl` | redução sem autor |
| Valsa das Flores | Tchaikovsky | 80 | 231 | `Waltz_of_the_Flowers.mxl` | redução sem autor |
| Lacrimosa (Réquiem) | Mozart | 32 | 99 | `Lacrimosa_-_Requiem.mxl` | redução sem autor |
| Ária na Corda Sol | Bach | 37 | 111 | `J._S._Bach_-_Air_on_the_G_String_Piano_arrangement.mxl` | arranjo para piano sem autor |
| Ave Maria (D. 839) | Schubert | 17 | 51 | `Ave_Maria_D839_-_Schubert_-_Solo_Piano_Arrg..mxl` | arranjo de Simon Ewers |
| Serenata (Ständchen) | Schubert/Liszt | 115 | 351 | `Schubert_Serenade_-_Standchen_-_By_Lizst.mxl` | transcrição de Liszt; título do arquivo “Song” |
| Minueto em Sol menor | Bach | 66 | 207 | `G_Minor_Bach_Original.mxl` | transcrito por “Lyo Ni” |
| Noturno Op. 9 nº 2 (fácil) | Chopin | 65 | 195 | `Nocturne_in_E-flat_Major_Op._9_No._2_Easy.mxl` | simplificação de Murilo Pedroza |

### Fora (26)

| Arquivo | Motivo |
| --- | --- |
| `Bella_Ciao.mxl` | arranjo de autor desconhecido; popular italiana, edição com direitos incertos |
| `Bella_Ciao_-_La_Casa_de_Papel.mxl` | selo de site (guestinpiano.fr) e arranjo da série |
| `Carol_of_the_Bells.mxl` | arranjo de Will Ross sobre obra de Leontovych/Wilhousky (letra e arranjo de 1936, protegidos) |
| `Carol_of_the_Bells_easy_piano.mxl` | idem |
| `Happy_Birthday_To_You_C_Major.mxl` | arranjo de terceiros (melodia só caiu em domínio público nos EUA em 2016) |
| `Happy_Birthday_To_You_Piano.mxl` | arranjo de Manjuprasad |
| `Mariage_dAmour.mxl` | Paul de Senneville (vivo): protegida |
| `Chopin_-_Spring_Waltz.mxl` | é Mariage d’Amour (Senneville), não Chopin |
| `Spring_Waltz_Mariage_dAmour_-_Chopin.mxl` | idem |
| `Hungarian_Sonata.mxl` | Richard Clayderman (vivo): protegida |
| `DANSE_VILLAGEOISE_Beethoven.mxl` | traz “©” nos direitos |
| `Fur_Elise_fingered.mxl` | selo de site (pianolessenassen.nl) e arranjo de “Verona” |
| `Greensleeves_for_Piano_easy_and_beautiful.mxl` | tradicional, mas o arranjo é de autor desconhecido |
| `Canon_in_D_3.mxl` | arranjo de Jacob Danao (2016) |
| `G_Minor_Bach.mxl` | selo “jvs” e 2 partes com pautas 1,2,3 (estrutura estranha) |
| `Passacaglia.mxl` | compositor não identificado |
| `Passacaglia2.mxl` | idem; cópia da anterior |
| `Minuet_in_G_Major_Bach.mxl` | duplicata do Minueto BWV Anh. 114 (este sem metadados) |
| `Erik_Satie_-_Gymnopedie_No.1.mxl` | duplicata (versão de MuseScore 1.3, menos completa) |
| `Clair_de_lune_-_Claude_Debussy.mxl` | duplicata |
| `Nocturne_No._20_in_C_Minor.mxl` | duplicata do Noturno em Dó# menor |
| `Prlude_Opus_28_No._4_in_E_Minor__Chopin.mxl` | duplicata do Prelúdio Op. 28 nº 4 |
| `Mozart_-_Piano_Sonata_No._16_-_Allegro.mxl` | duplicata da K. 545 (MuseScore 0.9, antiga) |
| `WA_Mozart_Marche_Turque_Turkish_March_fingered.mxl` | duplicata, com dedilhado de editor |
| `Sonate_No._14_Moonlight_3rd_Movement.mxl` | duplicata do 3º mov. da Ao Luar |
| `The_Entertainer_-_Scott_Joplin.mxl` | duplicata (a de 1902 declara domínio público) |

**Pedido:** aprovar (ou cortar/acrescentar) esta lista — A (34) + B (9) = 43 peças. Depois disso o B10 monta `dist/classicos.zywny`.
