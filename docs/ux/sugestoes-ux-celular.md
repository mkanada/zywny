# Sugestões — telas do celular

Uma proposta para cada achado **alto** e **médio** do
[estudo de UX](estudo-ux-celular.md) (os baixos ficaram de fora). Os números
entre parênteses são as telas de `docs/telas/celular/`. Os planos de
execução estão na fase **U** de `docs/plano/`
([U00](../plano/U00-ux-do-celular.md)); a última linha de cada sugestão diz
em que passo ela entra.

Onde a proposta mexe em algo que você já decidiu (a faixa da trilha, o
desfoque da virada, a contagem sobre a pauta, as setas do artboard), ela vira
uma **decisão aberta** na tabela do `README` do plano, com a recomendação e a
alternativa. Nenhuma dessas é executada sem a sua resposta.

## Princípios

Três regras saem dos achados e valem para todas as propostas:

1. **A pauta é do aluno.** Nada fica por cima do que ele precisa ler: nem
   faixa, nem contagem, nem painel, nem desfoque.
2. **O que a tela mostra é o que vale agora.** Andamento, mão, acertos e
   número de compasso são os da etapa em curso, na régua do resultado.
3. **Sempre há um próximo passo.** Sem teclado, sem som, sem resultado na
   busca: a tela diz o que fazer e oferece o atalho.

---

## A — Partitura e trilha

### A1 · Sem teclado, a tela padrão é um beco

**Proposta.** Duas mudanças que se completam.

- **Ouvir o trecho** vira ação própria da trilha, sempre disponível: toca o
  intervalo da etapa selecionada, as duas mãos, no andamento da etapa (100%
  nas do modo espera), com som, sem avaliar nada, e para sozinho no fim. Fica
  na barra lateral, logo abaixo do play (ver A7).
- **Sem teclado, a tela avisa antes do toque.** O texto da etapa ganha um
  aviso — "Conecte o teclado para praticar" — que, tocado, abre o seletor de
  teclado. O play grande, sem teclado, **ouve o trecho** em vez de reclamar.
  A barra preta "conecte um teclado MIDI primeiro" some.

```
 ←  5  Jubilosos Te Adoramos      Trecho 1/6 · Notas da direita ▾   ⌨ Conecte o teclado
```

**Alternativa.** Manter o play exigindo teclado e só trocar a barra preta
por uma com o botão "Conectar". Resolve o beco, mas não dá o "ouvir".

**Resolveu quando.** Um aluno sem teclado abre um hino, aperta o play e ouve
o primeiro trecho; a tela 12 deixa de existir.

**Decisão:** D-OUVIR · **Passo:** [U03](../plano/U03-ouvir-o-trecho.md)

### A2 · O som nasce desligado, e nada avisa

**Proposta.**

- "Som do app" passa a nascer **ligado**. Quem já desligou continua
  desligado (a preferência gravada vale).
- Um alto-falante na barra do título mostra o estado e liga ou desliga com
  um toque (hoje isso está a três toques, nas configurações). Desligado, o
  ícone aparece riscado.
- Com a saída no teclado MIDI e nenhum teclado ligado, o ícone mostra o
  problema ("som no teclado: nenhum conectado") em vez de ficar mudo calado.

**Custo.** O motor já é aberto ao entrar no hino mesmo com o som desligado
(`_restoreSound`), então ligar por padrão não acrescenta espera.

**Resolveu quando.** Primeiro play de uma instalação nova soa; a tela 23
mostra o alto-falante.

**Decisão:** D-SOM · **Passo:** [U04](../plano/U04-som-ligado-e-indicador.md)

### A3 · A faixa da trilha cobre a partitura e os painéis

**Proposta.** A faixa sai de cima da pauta e entra **na barra do título**,
que em paisagem tem mais de 500 dp livres à direita do nome do hino.

```
 ←  5  Jubilosos Te Adoramos        Trecho 2/6 · Notas da direita · 98% ▾      72% · meta 90%
```

- O texto da etapa vira um botão na barra do título; um toque abre a gaveta
  da trilha, como hoje.
- O play da faixa some: é o mesmo do botão grande da barra lateral.
- A área da partitura fica inteira para a pauta e para os painéis; as cifras
  voltam a aparecer e os painéis de layout e de configurações abrem com o
  título à vista.
- No treino livre, o mesmo lugar mostra "Treino livre" — hoje nada na tela
  diz em que modo se está.

**Alternativa.** Manter a faixa onde está e reservar os 34 dp dela sempre
(também no treino livre, para não regravar a página ao alternar). Custa 10%
da altura útil.

**Resolveu quando.** As telas 11, 17 e 18 refeitas mostram a cifra inteira e
o cabeçalho dos painéis.

**Decisão:** D-FAIXA (o J00 pede "uma faixa fina na partitura") ·
**Passo:** [U01](../plano/U01-faixa-fora-da-pauta.md)

### A4 · A partitura não mostra o trecho da etapa

**Proposta.**

- Ao abrir o hino e a cada troca de etapa, a partitura vai para o primeiro
  compasso do trecho (a etapa parada, sem tocar).
- Os compassos do trecho ficam **marcados**: um traço na cor de destaque sob
  o sistema, do primeiro ao último compasso. Os compassos de fora ficam
  esmaecidos (um véu branco de 55%).
- A fase final (a música inteira) não marca nada.

A API já existe: `ScoreView.overlayIds`/`overlayBuilder` desenha um widget
sobre o retângulo de cada id, e o compasso tem id na cena.

**Resolveu quando.** A tela 30 refeita mostra os compassos 5–9 com a marca,
antes de qualquer play.

**Passo:** [U02](../plano/U02-a-pauta-mostra-o-trecho.md)

### A5 · O selo de acertos não prevê o resultado

**Proposta.** O selo passa a mostrar **a porcentagem corrente, na mesma
conta do resumo**, ao lado da meta.

```
   72% · meta 90%          (verde a partir de 90, âmbar abaixo)
```

- Na trilha: `acertos / avaliadas até aqui`, exatamente a conta do
  `StageResult` — fora do tempo e perdidas contam contra, como no resumo.
- No treino livre em tempo real e no de ritmo: a mesma porcentagem, sem
  meta ("72%").
- No treino livre em modo espera, que não tem resultado, ficam os dois
  contadores de hoje.

**Alternativa.** Quatro contadores, os do resumo (certas, fora do tempo,
erradas, perdidas). Mais informação do que dá para ler tocando.

**Resolveu quando.** O número do selo no último instante da etapa é o número
do resumo.

**Decisão:** D-SELO · **Passo:** [U05](../plano/U05-selo-na-regua-do-resultado.md)

### A6 · A virada de página esconde o que vem a seguir

**O que acontece hoje, medido no código.** No último compasso da página a
haste entra, para no começo dele e a página nova aparece à esquerda,
**desfocada durante o compasso inteiro**. O desfoque só começa a cair quando
o compasso acaba, e some a 30% da saída da haste — ou seja, a primeira nota
da página nova fica legível **depois** do instante em que deveria ser
tocada.

**Proposta.** Manter a ideia (o foco é o fim da página que ainda toca), mas
devolver a leitura à frente:

- o desfoque fica inteiro só até a **metade** do último compasso e cai a
  zero aos três quartos: no último quarto, a página nova está nítida;
- **pausado, não há desfoque**: a página nova aparece nítida à esquerda da
  haste (tela 25);
- a gaveta e os painéis nunca abrem sobre um borrão (tela 24).

**Alternativas.** (b) Tirar o desfoque de vez — a haste já separa as duas
páginas. (c) Deixar como está.

**Resolveu quando.** Um aluno toca a virada de página em tempo real sem
errar a primeira nota da página nova mais do que erra as outras. É o achado
que mais pede teste com gente.

**Decisão:** D-VIRADA · **Passo:** [U06](../plano/U06-virada-legivel.md)

### A7 · A barra lateral mostra o que a etapa não usa

**Proposta.** A barra tem dois desenhos, um por modo.

```
 Trilha                      Treino livre (como hoje)
 ┌──────┐                    ┌──────┐
 │  ▶   │ praticar           │  ▶   │
 │  ♪   │ ouvir (A1)         │  ⏮   │
 │  ⏮   │                    │ 12   │ de 56
 │  5   │ de 26              │ 80%  │ andamento
 │ 50%  │ da etapa           │ Dir. │ mão
 │  ⋯   │                    │  ⋯   │
 └──────┘                    └──────┘
```

- Na trilha, "andamento" mostra o **da etapa** ("50%", ou "livre" no modo
  espera) e não abre nada; "mão" sai — o nome da etapa já diz.
- O número do compasso, na trilha, conta os compassos do **caminho** (sem
  repetições), que é a numeração da gaveta e do resumo. Hoje a barra conta
  as ocorrências da música expandida ("de 56") e a trilha fala em compassos
  1–26: são duas numerações na mesma tela.

**Resolveu quando.** Na tela 37, a barra diz 50%.

**Passo:** [U07](../plano/U07-barra-lateral-da-trilha.md)

### A8 · A primeira nota acende na cor de "certa"

**Proposta.**

- **Defeito.** A cor de "esperada" é aplicada depois do `seek` e do
  `play()`; a primeira nota fica com a cor da reprodução. Aplicar antes.
- **Mão do app.** Nas etapas de uma mão, as notas que o app toca acendem
  num cinza discreto, não no azul de "toque esta".
- **Legenda.** Seis cores têm significado (esperada, certa, fora do tempo,
  errada, perdida e a fantasma) e nenhuma legenda fora das configurações.
  Uma linha de legenda na gaveta da trilha e no resumo.
- **Não depender só de cor** (E3): a errada já tem a nota fantasma; a
  perdida ganha um "×" pequeno sobre a nota.

**Resolveu quando.** A tela 32 refeita mostra o primeiro acorde em azul; a
33 mostra a mão esquerda em cinza.

**Passo:** [U08](../plano/U08-cores-do-destaque.md)

### A9 · A contagem cobre os compassos que o aluno precisa ler

**Proposta.** Manter o número grande — é o que se enxerga do banco do
piano —, mas tirá-lo de cima do que se lê:

- fica na **metade direita** da pauta (a etapa começa à esquerda);
- não cresce nem desfoca: aparece, e some com opacidade máxima de 50%;
- nada acende na pauta durante a contagem (junto com A8).

**Alternativa.** Quatro pontos de pulso na barra do título, que se apagam um
a um. Não cobre nada, mas é pequeno para a distância do piano.

**Resolveu quando.** Na tela 37, o primeiro compasso está inteiro à vista
durante a contagem.

**Decisão:** D-CONTAGEM · **Passo:** [U09](../plano/U09-contagem-fora-do-primeiro-compasso.md)

### A10 · Sobra tela e falta música

**Proposta, em três degraus.**

1. **Modo imersivo** na tela da partitura: a barra de status some e devolve
   ~24 dp (6% da altura). Sem risco.
2. **Centralizar** o sistema na vertical quando só cabe um: a página passa a
   ter a altura do conteúdo e a vista a centraliza na caixa.
3. **Dois sistemas por página.** Medir antes de decidir: com a notação em
   9–10 (hoje 12), quantos sistemas e compassos cabem numa tela de
   914×411 dp, e se a nota continua legível a 60 cm. Dobrar a música visível
   também reduz pela metade as viradas de página (A6).

**Resolveu quando.** A tela 11 refeita não tem o terço de baixo vazio.

**Decisão:** D-SISTEMAS (só o degrau 3) ·
**Passo:** [U10](../plano/U10-aproveitar-a-tela.md)

### A11 · O modelo de modos da gaveta é confuso

**Proposta.**

- **Um seletor só**, de quatro opções, no lugar do "Ouvir | Espera" e dos
  dois interruptores:

  ```
  MODO   [ Ouvir ] [ Espera ] [ Tempo real ] [ Ritmo ]
  ```

  com uma linha de explicação sob o escolhido ("a música espera você
  acertar", "a música não espera", "qualquer tecla, no tempo").
- **Na trilha**, a gaveta abre com o que vale ali: o alternador "Treino
  livre", o tamanho da notação, o metrônomo e as configurações. Modo, mão e
  andamento só aparecem no treino livre.
- "Voltar à biblioteca" sai da gaveta (a seta do topo já faz isso).

**Resolveu quando.** Com "Tempo real" escolhido, nada na gaveta diz
"Espera".

**Decisão:** D-MODOS · **Passo:** [U11](../plano/U11-gaveta-de-opcoes.md)

---

## B — Resumos e progresso

### B1 · "Faltou 80%" não diz o que faltou

**Proposta.** Dizer a meta, não a diferença:

```
   10%
   Precisa de 90% para passar
```

e, aprovado, "Aprovado · meta 90%". A meta aparece também no selo (A5).

**Passo:** [U05](../plano/U05-selo-na-regua-do-resultado.md)

### B2 · Os compassos com erro são só uma lista de números

**Proposta.**

- Os compassos com erro ficam **marcados na pauta** (fundo vermelho bem
  claro) enquanto o resumo está aberto e até o próximo play.
- O resumo, em paisagem, entra **pela lateral** (ver E2): a pauta com as
  marcas fica visível ao lado.
- **Defeito a investigar.** Numa etapa do trecho "compassos 1–5" o resumo
  listou erro no compasso 6: um veredito está sendo atribuído ao compasso
  seguinte ao fim do intervalo.

**Passo:** [U12](../plano/U12-resumos-legiveis.md)

### B3 · O resumo do treino livre fala em milissegundos

**Proposta.** Frases no lugar dos números; os números ficam atrás de
"detalhes".

```
   Precisão 7%
   Você está entrando atrasado.
   Deram mais trabalho: compassos 4, 1 e 2.
   [ Repetir esses compassos ]        detalhes ▾
```

| Medida | Frase |
| --- | --- |
| média dentro de ±30 ms | "No tempo." |
| média acima de +30 ms | "Você está entrando atrasado." |
| média abaixo de −30 ms | "Você está entrando adiantado." |
| desvio-padrão acima de 60 ms | "O pulso está irregular." (soma-se à anterior) |

**Passo:** [U12](../plano/U12-resumos-legiveis.md)

### B4 · A trilha é longa e não mostra o todo

**Proposta.** Uma barra de progresso da trilha inteira no topo da gaveta
("13 de 75 etapas"), com as puladas num tom mais claro. A mesma barra, em
miniatura, vai para a linha do hino na biblioteca (C1).

**Passo:** [U13](../plano/U13-progresso-a-vista.md)

---

## C — Biblioteca

### C1 · A linha do hino corta justamente o progresso

**Proposta.** O progresso sai da linha de texto e ocupa a coluna da direita;
quem encolhe é o compositor.

```
  5   Jubilosos Te Adoramos                         ▓▓░░░░░░  13/75
      Ludwig van Beeth… · nível 1 · hoje · melhor 78%

  1   Santo, Santo, Santo!                          ▓▓▓▓▓▓▓▓  ✓
      John B. Dykes · nível 1 · ontem · melhor 94%

  3   O Deus Eterno Reina
      Hart P. Danks · nível 2
```

No cartão "Continuar", a etapa ganha uma linha só dela ("Trecho 2/6 · Notas
da direita").

**Passo:** [U13](../plano/U13-progresso-a-vista.md)

### C2 · A bolinha e o número à direita não têm legenda

**Proposta.** A pontuação vira texto na segunda linha, com rótulo ("melhor
94%"), e só existe quando há pontuação. Hino nunca estudado não mostra nada
à direita — acabam as 600 linhas de "● —". A cor deixa de ser a única pista.

**Passo:** [U13](../plano/U13-progresso-a-vista.md)

### C3 · A seta da ordenação não indica a direção

**Proposta.** A seta mostra a ordem real: "↑" crescente (1→600, A→Z, fácil→
difícil), "↓" decrescente. A direção inicial de cada critério continua a de
hoje — só o desenho da seta muda. E a fila ganha um esmaecido na borda
direita, para avisar que há mais pastilhas.

**Alternativa.** Manter como no artboard ("↓" = direção padrão).

**Decisão:** D-ORDEM · **Passo:** [U14](../plano/U14-ordenar-e-buscar.md)

### C4 · A busca não explica o que achou

**Proposta.**

- Títulos primeiro: o que casa no título vem antes do que casa só no autor,
  no letrista ou no título original.
- O termo aparece em negrito onde casou.
- Quando o casamento não está no título nem no compositor, a segunda linha
  mostra o campo: "letra: Reginald Heber", "original: Holy, Holy, Holy".
- Sem resultado: "Nenhum hino com 'chopin'" e um botão "Limpar a busca".

**Passo:** [U14](../plano/U14-ordenar-e-buscar.md)

### C5 · Conectar o teclado é um diálogo sem saída

**Proposta.**

- Diálogo vazio com orientação e saída:

  ```
  Nenhum teclado encontrado

  Ligue o teclado ao celular com um cabo USB (pode ser preciso um
  adaptador). Ele conecta sozinho.
  Teclados por Bluetooth ainda não funcionam.

                                   [ Procurar de novo ]   Fechar
  ```
- O tipo do aparelho em português ("USB", "Bluetooth", "rede") no lugar de
  "native".
- Um nome só no app inteiro: **Teclado MIDI**.
- Na biblioteca, o botão diz o estado com ícone e palavra — "Conectar" com o
  teclado riscado, "Teclado ✓" conectado —, não com um ponto colorido.

**Passo:** [U15](../plano/U15-conectar-o-teclado.md)

### C6 · O primeiro uso não apresenta nada

**Proposta.** Enquanto nenhum hino foi aberto, o lugar do cartão "Continuar"
mostra um cartão de começo:

```
  COMECE POR AQUI
  Escolha um hino fácil e ligue o teclado.
  [ Ver os mais fáceis ]   [ Conectar teclado ]
```

"Ver os mais fáceis" ordena por dificuldade. O cartão some no primeiro hino
aberto. E "nível 1" passa a dizer a escala: "nível 1 de 5".

**Passo:** [U16](../plano/U16-primeiro-uso.md)

---

## D — Configurações

### D1 · Vocabulário de quem fez, não de quem usa

**Proposta.** Trocar os rótulos; nenhuma mudança de comportamento.

| Hoje | Passa a ser |
| --- | --- |
| Som do app — toca a partitura; desligado, só destaca as notas | Som — o app toca a música |
| `Sintetizador \| Teclado MIDI` (sem rótulo) | "O som sai por" · `Celular \| Teclado` |
| Instrumentos da partitura — manda Program Change ao teclado | Trocar o timbre do teclado — usa o instrumento da partitura |
| Soundfont do sintetizador · TimGM6mb (padrão) · trocar | Timbre do piano · padrão · **Trocar** |
| Voltar ao soundfont padrão | Voltar ao timbre padrão |
| Dispositivo · nenhum conectado · escolher | Teclado MIDI · nenhum conectado · **Conectar** |
| Monitor MIDI — o teclado soa pelo app (teclado sem som) | Ouvir o que eu toco pelo celular — para teclado sem som próprio |
| Latência do teclado · não calibrada · calibrar | Atraso do teclado · não ajustado · **Ajustar** |
| Painel do monitor MIDI | Ver as teclas que chegam |
| Compassos por trecho | Compassos por trecho da trilha |
| "Mudar o padrão?" / "Os hinos sem N próprio recomeçam a trilha." | "Mudar o tamanho dos trechos?" / "Os hinos que usam o padrão recomeçam a trilha do começo." |
| Usar o padrão da trilha (5) | Trechos de 5 compassos (padrão) |
| Nota destacada — na reprodução e, no treino, a nota certa | Nota certa — e a nota que soa ao ouvir |
| Treino: nota em espera | Nota esperada |
| Treino: nota errada — pisca na nota esperada mais próxima | Nota errada |
| Haste de virada — a barra que varre a página | Barra de virada de página |
| Largura do halo | Brilho em volta da nota |
| Calibrar latência / "Aperte qualquer tecla de Teclado digital junto com cada um, no pulso." | Ajustar o atraso / "Vão soar 8 cliques. Aperte qualquer tecla do teclado junto com cada um." |
| Layout deste hino (avançado) | Ajustes da partitura (avançado) |

As ações à direita ("trocar", "escolher", "calibrar") ganham inicial
maiúscula e a cor de destaque, para lerem como botão (D2 do estudo, de
carona).

**Passo:** [U17](../plano/U17-vocabulario.md)

---

## E — Geral

### E1 · Dois visuais no mesmo app

**Proposta.** Um `ColorScheme` escrito à mão a partir da paleta de
`lib/ui/theme.dart`, no lugar do gerado pela semente: `primary` = azul
`kAccent`, `surface` = branco, contêineres nos beges da biblioteca. Diálogos,
folhas, botões, interruptores e controles deslizantes passam a herdar daí; os
`activeColor: kAccent` espalhados somem.

**Resolveu quando.** O botão principal tem a mesma cor nas telas 20, 27 e
34.

**Passo:** [U18](../plano/U18-um-visual-so.md)

### E2 · Quatro tipos de superfície para a mesma função

**Proposta.** Uma regra para a tela da partitura no celular:

| O que é | Como aparece |
| --- | --- |
| Ajusta ou mostra algo **da partitura** (opções, trilha, layout, configurações, ir para compasso, repetir trecho, resumos) | painel pela **direita**, largura 400 dp — a pauta continua visível à esquerda |
| Pede uma resposta antes de continuar (confirmar, escolher teclado, ajustar atraso) | diálogo central |

As folhas inferiores saem da tela da partitura. "Ir para o compasso" e
"Repetir um trecho" ganham, de quebra, a pauta à vista enquanto se escolhe.

**Passo:** [U18](../plano/U18-um-visual-so.md)

### E3 · Estado só por cor

Distribuído: notas em A8 (U08), pontuação em C2 (U13), teclado em C5 (U15).
Nos três, a regra é a mesma — cor **e** forma ou palavra.

---

## Ordem

O que destrava mais com menos: **U01 → U02 → U03/U04 → U05**. São os cinco
achados altos que não dependem de decisão difícil. U06 (virada) é o mais
arriscado e o que mais ganha com um teste com alunos antes e depois. O resto
é independente entre si; a tabela de passos do U00 dá as dependências.

No fim, [U19](../plano/U19-refazer-as-telas.md) refaz as 46 telas e confere
achado por achado.
