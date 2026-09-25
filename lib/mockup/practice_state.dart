/// Modo de estudo — mesmo vocabulário do painel de opções do artboard
/// (`Ouvir` / `Espera` / `Tempo real`) e do plano (`docs/plano/README.md`).
enum PracticeMode { ouvir, espera, tempoReal }

extension PracticeModeLabel on PracticeMode {
  String get label => switch (this) {
    PracticeMode.ouvir => 'Ouvir',
    PracticeMode.espera => 'Espera',
    PracticeMode.tempoReal => 'Tempo real',
  };

  /// Texto do selo "Esperando · mão dir." (`CelularTreino`).
  String get statusVerb => switch (this) {
    PracticeMode.ouvir => 'Ouvindo',
    PracticeMode.espera => 'Esperando',
    PracticeMode.tempoReal => 'Tempo real',
  };
}

enum Hand { esquerda, direita, ambas }

extension HandLabel on Hand {
  String get label => switch (this) {
    Hand.esquerda => 'Esquerda',
    Hand.direita => 'Direita',
    Hand.ambas => 'Ambas',
  };

  /// Abreviação usada no botão da barra lateral (`Dir.` / `Esq.` / `Ambas`).
  String get shortLabel => switch (this) {
    Hand.esquerda => 'Esq.',
    Hand.direita => 'Dir.',
    Hand.ambas => 'Ambas',
  };
}

/// Tamanho de exibição da partitura — estados `CelularEstudo` (padrão) ×
/// `CelularGrande` (ler da estante).
enum ScoreSize { padrao, grande }

extension ScoreSizeLabel on ScoreSize {
  String get label => switch (this) {
    ScoreSize.padrao => 'Padrão',
    ScoreSize.grande => 'Grande',
  };
}

/// O que a tela de biblioteca passa para a tela de estudo ao abrir uma
/// peça — vem tanto de uma linha da lista (estado inicial) quanto do card
/// "continuar" (retoma o estudo de onde parou).
class PracticeArgs {
  const PracticeArgs({
    required this.title,
    required this.composer,
    this.mode = PracticeMode.ouvir,
    this.hand = Hand.ambas,
    this.tempoPercent = 100,
    this.measure = 1,
    this.totalMeasures = 41,
    this.size = ScoreSize.padrao,
  });

  final String title;
  final String composer;
  final PracticeMode mode;
  final Hand hand;
  final int tempoPercent;
  final int measure;
  final int totalMeasures;
  final ScoreSize size;
}

/// Abaixo desta largura (px lógicos), a tela de estudo usa o layout
/// compacto de celular (barra lateral, painel escondido atrás de "⋯") — a
/// partir daqui, o layout largo de tablet/desktop (`Main.dc.html` /
/// `Treino.dc.html` / `TabletEstudo.dc.html`): barra de topo com título da
/// peça e barra de transporte inferior com todos os controles à vista.
/// O artboard `CelularEstudo` já usa 844 px (celular grande, paisagem);
/// 1000 dá margem acima disso (um telefone real em paisagem pode passar de
/// 844) e ainda fica bem abaixo do tablet (1194) e do desktop (1280).
const double kWidePracticeBreakpoint = 1000;

/// Separa "Little bird, op. 43 nº 4" em nome e catálogo, como o cabeçalho
/// largo (`Main.dc.html`) mostra o nome em destaque e ", op. 43 nº 4" como
/// legenda junto do compositor. Títulos sem vírgula (ex. "Gymnopédie nº 1")
/// voltam só o nome.
(String name, String? catalog) splitTitle(String title) {
  final i = title.indexOf(', ');
  if (i < 0) return (title, null);
  return (title.substring(0, i), title.substring(i + 2));
}
