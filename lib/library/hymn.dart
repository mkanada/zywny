import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

/// Um hino da biblioteca embutida — uma linha de `assets/hinos/indice.json`
/// (gerado por `tool/build_hymn_assets.py` a partir do Hymn_Grabber).
@immutable
class Hymn {
  const Hymn({
    required this.number,
    required this.title,
    required this.composer,
    this.lyricist,
    this.originalTitle,
    required this.titleKey,
    required this.composerKey,
    required this.searchKey,
  });

  factory Hymn.fromJson(Map<String, dynamic> json) => Hymn(
    number: json['n'] as int,
    title: json['t'] as String,
    composer: json['c'] as String,
    lyricist: json['l'] as String?,
    originalTitle: json['o'] as String?,
    titleKey: json['k'] as String,
    composerKey: json['ck'] as String,
    searchKey: json['q'] as String,
  );

  final int number;
  final String title;
  final String composer;

  /// Autor da letra, só quando não é o próprio compositor.
  final String? lyricist;
  final String? originalTitle;

  /// Chaves sem acento nem pontuação, prontas do índice: ordem por título,
  /// ordem por compositor e o texto onde a busca procura (número, títulos e
  /// autores).
  final String titleKey;
  final String composerKey;
  final String searchKey;

  /// "001" — como o hinário numera e como o arquivo se chama.
  String get paddedNumber => number.toString().padLeft(3, '0');

  String get assetPath => '${HymnCatalog.assetDir}/$paddedNumber.musicxml.gz';
}

/// Os hinos que o app traz embutidos. O app não importa partitura alguma:
/// esta lista é a biblioteca inteira.
class HymnCatalog {
  const HymnCatalog(this.hymns);

  static const assetDir = 'assets/hinos';

  final List<Hymn> hymns;

  static Future<HymnCatalog> load([AssetBundle? bundle]) async {
    final text = await (bundle ?? rootBundle).loadString(
      '$assetDir/indice.json',
    );
    final list = jsonDecode(text) as List<dynamic>;
    return HymnCatalog([
      for (final e in list) Hymn.fromJson(e as Map<String, dynamic>),
    ]);
  }

  /// Descompacta o hino para um arquivo e devolve o caminho — o Verovio só
  /// lê de disco (`VsbRenderRequest.inputPath`). Sempre regrava: é rápido e
  /// uma atualização do app pode ter trazido outra versão da partitura.
  static Future<String> extractScore(Hymn hymn, [AssetBundle? bundle]) async {
    final data = await (bundle ?? rootBundle).load(hymn.assetPath);
    final xml = gzip.decode(
      data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
    );
    final base = await getTemporaryDirectory();
    final dir = Directory('${base.path}/hinos');
    await dir.create(recursive: true);
    final file = File('${dir.path}/${hymn.paddedNumber}.musicxml');
    await file.writeAsBytes(xml, flush: true);
    return file.path;
  }
}

/// Minúsculas sem acento nem pontuação — o mesmo `fold` do
/// `tool/build_hymn_assets.py`, para o que o usuário digita na busca casar
/// com [Hymn.searchKey].
String foldForSearch(String text) {
  const from = 'áàâãäéèêëíìîïóòôõöúùûüçñ';
  const to = 'aaaaaeeeeiiiiooooouuuucn';
  final out = StringBuffer();
  for (final rune in text.toLowerCase().runes) {
    final ch = String.fromCharCode(rune);
    final i = from.indexOf(ch);
    out.write(i >= 0 ? to[i] : ch);
  }
  return out.toString().replaceAll(RegExp('[^a-z0-9]+'), ' ').trim();
}
