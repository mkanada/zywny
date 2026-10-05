// I05 — `zywny-audio`: tocador compacto de `.ogg`/`.mp3` a partir de bytes.
//
// Escolha do pacote (medida nas quatro plataformas, como pede o I05):
//
// - Pacote: `audioplayers` (`BytesSource`; 6.8.1, pub.dev, MIT, Blue Fire).
// - Por que ele: é o único com `Source` em bytes em **todas** as plataformas
//   (Android ExoPlayer, Linux GStreamer, Web WebAudio/HTML5, Windows WASAPI)
//   sem gravar arquivo temporário — na Web não há arquivo, então `file:`
//   tem de sair da memória.
// - Linux (Pop!_OS do usuário, GStreamer 1.24.2): `libgstogg`, `libgstvorbis`
//   e `libav` (mp3) já vêm instalados (`gst-inspect-1.0` os lista) — toca sem
//   instalar nada. Sem eles, o `audioplayers_linux` falharia em silêncio e a
//   caixa de áudio mostraria o erro (ver `AudioMarkView`).
// - Android: ExoPlayer toca `.ogg` (Vorbis) e `.mp3` de bytes; precisa de
//   `INTERNET`? Não — bytes locais não pedem permissão.
// - Web: o `audioplayers_web` monta um Blob dos bytes (mime `audio/ogg` ou
//   `audio/mpeg`); o Safari toca `.mp3`, o Chrome/Edge tocam os dois.
// - Windows (quando houver build): `audioplayers_windows` toca os dois de
//   bytes (Media Foundation).
//
// Conclusão: **nenhuma restrição a `.mp3`** — `.ogg` e `.mp3` valem na v1,
// como já diz o validador (I01). Se algum aparelho futuro ficar mudo com
// `.ogg`, a saída é restringir a especificação a `.mp3` (I01) em vez de
// aceitar áudio mudo.
//
// `flutter_markdown`/`just_audio` foram considerados e descartados: o primeiro
// está descontinuado (ver `markdown_view.dart`); o segundo não tem fonte em
// bytes em todas as plataformas sem adaptador próprio.

import 'dart:async';
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart' show VoidCallback;

/// Fonte de áudio da lição: bytes + extensão (o `mimeType` sai da extensão).
class LessonAudioBytes {
  const LessonAudioBytes(this.bytes, this.fileName);

  final Uint8List bytes;
  final String fileName;

  String? get mimeType {
    final lower = fileName.toLowerCase();
    if (lower.endsWith('.ogg')) return 'audio/ogg';
    if (lower.endsWith('.mp3')) return 'audio/mpeg';
    return null;
  }

  Source toSource() => BytesSource(bytes, mimeType: mimeType);
}

/// Tocador mínimo usado pelo `AudioMarkView`: play/pausa a partir de bytes,
/// posição e duração. A implementação real usa `audioplayers`; o teste usa
/// um falso (ver `test/lesson_view_test.dart`).
abstract class LessonAudioPlayer {
  Future<void> setBytes(LessonAudioBytes audio);
  Future<void> play();
  Future<void> pause();
  Future<void> stop();
  Stream<Duration> get position;
  Stream<Duration?> get duration;
  Stream<PlayerState> get state;
  Future<void> seek(Duration position);
  Future<void> dispose();
}

/// `LessonAudioPlayer` sobre `audioplayers` (ver escolha acima).
class AudioplayersLessonPlayer implements LessonAudioPlayer {
  AudioplayersLessonPlayer({AudioPlayer? player})
    : _player = player ?? AudioPlayer();

  final AudioPlayer _player;

  @override
  Future<void> setBytes(LessonAudioBytes audio) =>
      _player.setSource(audio.toSource());

  @override
  Future<void> play() => _player.resume();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> stop() => _player.stop();

  @override
  Stream<Duration> get position => _player.onPositionChanged;

  @override
  Stream<Duration?> get duration => _player.onDurationChanged;

  @override
  Stream<PlayerState> get state => _player.onPlayerStateChanged;

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> dispose() => _player.dispose();
}

/// Garante que um só áudio toca por vez na lição (I05, item 5).
///
/// Cada `AudioMarkView` registra seu `pause` aqui ao dar play; quem começa
/// pausa o anterior. Sem `BuildContext`: o `LessonView` cria um e repassa.
class SingleAudioPlay {
  VoidCallback? _pauseCurrent;

  /// Registra [pauseCurrent] como o que toca agora, pausando o anterior.
  void started(VoidCallback pauseCurrent) {
    final previous = _pauseCurrent;
    _pauseCurrent = pauseCurrent;
    if (previous != null && previous != pauseCurrent) previous();
  }

  void stopped(VoidCallback pauseCurrent) {
    if (_pauseCurrent == pauseCurrent) _pauseCurrent = null;
  }
}
