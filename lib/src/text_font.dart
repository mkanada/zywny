// Fonte de texto comum (R04a).
//
// O campo `family` do formato (§5.4) NÃO é nome de fonte instalável: no
// corpus vale só `"Times"` (294 runs, de `FontInfo::GetFaceName()`) ou
// `"Times, serif"` (123 runs, fallback do exportador — o mesmo default do
// `font-family` da raiz `<svg class="definition-scale">`). No SVG de
// referência nenhum `<text>` carrega `font-family`: todos herdam o da raiz
// e o `svg_render` resolve o genérico `serif` com
// `set_serif_family("Liberation Serif")`.
//
// Conclusão: no Flutter, `"Times"`, `"Times, serif"` e qualquer valor
// desconhecido significam a mesma serifada do projeto, Liberation Serif
// (embutida em `fonts/` deste pacote). Usar `family` cru como `fontFamily`
// do `TextStyle` faria o Flutter procurar uma "Times" inexistente e cair no
// fallback do sistema sem avisar — por isso há um ponto único de decisão.
library;

/// Família registrada no `pubspec.yaml` deste pacote (os 4 estilos).
const kScoreTextFamily = 'Liberation Serif';

/// Pacote que contém os assets da fonte (para `TextStyle(package: ...)`
/// fora deste pacote, ex. no app `compare`).
const kScoreTextFamilyPackage = 'score_bridge';

/// Resolve o `family` do `.vsb` (§5.4) para a família carregada.
///
/// `"Times"`, `"Times, serif"` e desconhecidos devolvem todos
/// [kScoreTextFamily]: o mapeamento é deliberado (ver comentário acima),
/// nunca `family` cru.
String resolveFamily(String vsbFamily) => kScoreTextFamily;
