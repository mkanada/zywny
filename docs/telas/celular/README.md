# Telas no celular

Índice visual com todas as fotos: [`../INDICE.md`](../INDICE.md).

Fotos do app de verdade rodando num celular Android (emulador
`Medium_Phone_2`, 1080×2400, 411×914 dp): a biblioteca em retrato e a
partitura em paisagem. Servem de referência do que o aluno vê hoje — o
estudo de UX em `docs/ux/` parte delas.

## Como refazer

    emulator -avd Medium_Phone_2 -read-only -no-window -no-audio &
    just telas

O roteiro é `integration_test/telas_celular_test.dart`; quem grava os PNGs é
`test_driver/telas_celular.dart`. Precisa do mesmo preparo do `just build-apk`
(`.so` do Verovio e do áudio em `jniLibs/`, hinos e `verovio_data.zip`).

### Em retrato e em paisagem

As pastas [`retrato/`](retrato/) e [`paisagem/`](paisagem/) têm as mesmas
telas numa orientação só (lado a lado em [`../ORIENTACAO.md`](../ORIENTACAO.md);
análise em [`../../ux/estudo-ux-orientacao.md`](../../ux/estudo-ux-orientacao.md)).
O roteiro fixa o tamanho da tela no Flutter, não no Android:

    adb push dist/hinos.zywny /data/local/tmp/hinos.zywny
    TELAS_DIR=docs/telas/celular/retrato just telas \
        --dart-define=ZYWNY_TEST_LIBRARY=/data/local/tmp/hinos.zywny \
        --dart-define=ZYWNY_TELAS_ORIENTACAO=retrato

(idem com `paisagem`). A partitura só existe em paisagem: na passagem em
retrato ela abre deitada e não é fotografada. Em paisagem a biblioteca não
mostra a lista, e o roteiro gira para retrato só para tocar no hino.

O que as fotos **não** mostram:

- a barra de status e a de navegação do Android (a foto é só da área do
  Flutter; desde o U10 a partitura é imersiva, sem a faixa branca do topo);
- o teclado virtual: nas telas de busca, o espaço vazio embaixo da lista é
  onde ele estaria;
- um teclado MIDI de verdade: o da 2ª passagem é falso (toca as notas que a
  etapa espera e erra algumas de propósito).

## 1ª passagem — primeiro uso, sem teclado

| Arquivo | Tela |
|---|---|
| `01-abertura` | Splash |
| `02-biblioteca-primeiro-uso` | Biblioteca sem histórico |
| `03-biblioteca-busca` | Busca com resultados ("santo") |
| `04-biblioteca-busca-sem-resultado` | Busca sem resultado |
| `05-biblioteca-por-dificuldade` | Ordenada por dificuldade |
| `06-teclado-midi-nenhum` | Seletor de teclado MIDI, vazio |
| `07-configuracoes` | Configurações gerais (tela cheia) |
| `08-configuracoes-mudar-o-padrao` | Confirmação "Mudar o tamanho dos trechos?" (o nome do arquivo guarda o rótulo antigo) |
| `09-seletor-de-cor` | Seletor de cor |
| `10-hino-abrindo` | Partitura sendo gravada |
| `11-trilha-sem-teclado` | Partitura na trilha: etapa na barra do título, aviso de teclado, alto-falante, trecho marcado |
| `12-ouvindo-o-trecho` | Play na trilha sem teclado: ouve o trecho |
| `13-gaveta-da-trilha` | Gaveta da trilha, nada feito |
| `14`–`16-opcoes-de-estudo…` | Gaveta de opções (começo, meio e fim) |
| `17-layout-do-hino` | Painel "Ajustes da partitura" |
| `18-configuracoes-na-partitura` | Configurações gerais sobre a partitura |
| `19-ir-para-compasso` | Ir para um compasso |
| `20-repetir-um-trecho` | Repetir um trecho (loop) |
| `21-treino-livre` | Treino livre, parado |
| `22-contagem` | Contagem regressiva antes de tocar |
| `23-tocando` | Tocando, na virada de página |
| `24-opcoes-modo-espera` | Opções com o modo "Espera" escolhido |
| `25-espera-sem-teclado` | Modo espera sem teclado |
| `26-biblioteca-continuar` | Biblioteca com o cartão "Continuar" |

## 2ª passagem — com histórico e teclado MIDI

| Arquivo | Tela |
|---|---|
| `27-biblioteca-com-historico` | Biblioteca com pontuações e trilhas em andamento |
| `28-biblioteca-por-pontuacao` | Ordenada por pontuação |
| `29-teclado-midi-conectado` | Seletor de teclado MIDI, conectado |
| `30-trilha-retomada` | Partitura retomando a trilha no 2º trecho |
| `31-gaveta-da-trilha-com-progresso` | Gaveta da trilha com um trecho feito |
| `32-etapa-espera` | Etapa do modo espera, começando |
| `33-etapa-nota-errada` | Etapa com uma tecla errada (nota fantasma) |
| `34-resumo-da-etapa` | Resumo de etapa aprovada (painel lateral) |
| `35-proxima-etapa` | Etapa seguinte selecionada |
| `36-gaveta-etapas-concluidas` | Gaveta com as etapas do trecho concluído |
| `37-etapa-contagem` | Contagem de uma etapa com tempo |
| `38-etapa-tempo-real` | Etapa em tempo real |
| `39-resumo-da-etapa-reprovada` | Resumo de etapa reprovada |
| `40-opcoes-treino-em-tempo-real` | Opções do treino livre em tempo real |
| `41-treino-livre-tempo-real` | Treino livre em tempo real |
| `42-resumo-do-treino` | Resumo de precisão do treino livre |
| `43-configuracoes-com-teclado` | Configurações gerais com o teclado ligado |
| `44-calibrar-latencia` | "Ajustar o atraso" (o nome do arquivo guarda o rótulo antigo) |
| `45-monitor-midi` | Painel "Teclas que chegam" |
| `46-biblioteca-depois-do-estudo` | Biblioteca ao voltar do estudo |

## 3ª passagem — cursos da fase I

| Arquivo | Tela |
|---|---|
| `47-curso-inicial-sem-biblioteca` | Sem biblioteca: cartão "Comece pelo curso inicial" |
| `48-licao-1-pelo-cartao` | Lição 1 aberta pelo cartão |
| `49-biblioteca-com-cursos` | Biblioteca com a linha "Cursos" |
| `50-lista-de-cursos` | Lista de cursos |
| `51-tela-do-curso` | Tela do curso: uma feita, uma aberta, o resto bloqueado |
| `52-licao-2-topo` | Lição 2, começo (retrato) |
| `53-licao-2-partitura` | Lição 2, rolada até a partitura |
| `54-licao-2-exercicio` | Lição 2, cartão do exercício ("Precisa do teclado") |
| `55-exercicio-conecte-o-teclado` | Exercício sem teclado: "Conecte o teclado" |
| `56-exercicio-name-note` | Exercício `name-note` (botões) |
| `57-licao-8-choice-cartao` | Lição 8, cartão do `choice` |
| `58-exercicio-choice` | Exercício `choice` |
| `59-exercicio-play-notes-antes` | Exercício `play-notes` antes da rodada (paisagem) |
| `60-exercicio-play-notes-depois` | Exercício `play-notes` aprovado (100%) |

## O que mudou na fase U

Fotos refeitas no fim da fase U (passos U01–U18). Mudaram de nome: `12` (era
`12-trilha-pede-teclado`). Os resumos (19, 20, 34, 39, 42) e as gavetas (13–16,
31) agora são painéis à direita; o seletor de teclado (06, 29) e as
configurações (07, 43) usam o vocabulário e o tema novos. A conferência achado a
achado está em `docs/ux/estudo-ux-celular.md`, seção "Depois da fase U".
