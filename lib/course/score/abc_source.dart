import 'dart:convert';
import 'dart:typed_data';

import '../format/course_model.dart';

/// ABC pronto para o Verovio. Um [body] que começa com `X:` é ABC completo
/// e passa intacto; senão é só o corpo das notas e o app monta o cabeçalho:
///
/// ```
/// X:1
/// T:lesson
/// L:1/4            ← cada letra sem número vale uma semínima
/// M:<time>         ← omitido sem `time`: sem fórmula de compasso na pauta
/// K:<key> clef=<treble|bass>
/// <body>
/// ```
///
/// Não existe `M:none`: o Verovio desenha um "0" no lugar da fórmula; sem a
/// linha `M:` a pauta sai limpa e o `midi.json` sai igual.
/// O `T:` evita o aviso "Title field missing" (o título não aparece: o
/// bridge liga o cabeçalho em `none`).
///
/// O leitor de ABC do fork **não** faz várias vozes ou pautas juntas (as
/// vozes saem uma depois da outra), por isso `clef: grand` não existe aqui:
/// duas pautas só por `.musicxml` ou pelos sorteios.
String abcSource(
  String body, {
  Clef clef = Clef.treble,
  String? key,
  String? time,
  String unit = '1/4',
}) {
  if (abcIsComplete(body)) return body;
  if (clef == Clef.grand) {
    throw ArgumentError.value(
      clef,
      'clef',
      'o ABC não desenha duas pautas; use um .musicxml',
    );
  }
  final header = StringBuffer()
    ..writeln('X:1')
    ..writeln('T:lesson')
    ..writeln('L:$unit');
  if (time != null) header.writeln('M:$time');
  header.writeln('K:${key ?? 'C'} clef=${clef.wire}');
  final text = body.trim();
  return '$header$text\n';
}

/// Os bytes (UTF-8) de um texto (ABC ou MusicXML), para o
/// `ScoreRenderRequest`.
Uint8List utf8Bytes(String abc) => Uint8List.fromList(utf8.encode(abc));
