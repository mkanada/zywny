// I05 — `zywny-audio`: tocador compacto (play/pausa, barra, tempo, legenda).

import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';

import '../../ui/theme.dart';
import '../format/course_files.dart';
import '../format/course_model.dart';
import 'lesson_audio.dart';

/// Tocador da marca `zywny-audio`: bytes da [CourseFiles], play/pausa, barra
/// de progresso, tempo e legenda. Um só toca por vez na lição ([coordinator]).
class AudioMarkView extends StatefulWidget {
  const AudioMarkView({
    super.key,
    required this.mark,
    required this.files,
    required this.coordinator,
    this.playerFactory,
  });

  final AudioMark mark;
  final CourseFiles files;
  final SingleAudioPlay coordinator;

  /// Para teste: cria o [LessonAudioPlayer] (falso) em vez do real.
  final LessonAudioPlayer Function()? playerFactory;

  @override
  State<AudioMarkView> createState() => _AudioMarkViewState();
}

class _AudioMarkViewState extends State<AudioMarkView> {
  LessonAudioPlayer? _player;
  String? _error;
  bool _playing = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  final List<StreamSubscription> _subscriptions = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant AudioMarkView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.mark.file != widget.mark.file) {
      _stopSilently();
      _load();
    }
  }

  Future<void> _load() async {
    try {
      final bytes = await widget.files.read(widget.mark.file);
      if (!mounted) return;
      final player =
          (widget.playerFactory ?? () => AudioplayersLessonPlayer()).call();
      await player.setBytes(LessonAudioBytes(bytes, widget.mark.file));
      if (!mounted) {
        await player.dispose();
        return;
      }
      _subscriptions.addAll([
        player.state.listen((state) {
          if (!mounted) return;
          setState(() => _playing = state == PlayerState.playing);
        }),
        player.position.listen((position) {
          if (!mounted) return;
          setState(() => _position = position);
        }),
        player.duration.listen((duration) {
          if (!mounted || duration == null) return;
          setState(() => _duration = duration);
        }),
      ]);
      setState(() {
        _player = player;
        _error = null;
      });
    } on Object catch (e) {
      if (!mounted) return;
      setState(() => _error = '$e');
    }
  }

  void _pauseFromCoordinator() {
    _player?.pause();
  }

  Future<void> _toggle() async {
    final player = _player;
    if (player == null) return;
    if (_playing) {
      await player.pause();
      widget.coordinator.stopped(_pauseFromCoordinator);
    } else {
      widget.coordinator.started(_pauseFromCoordinator);
      await player.play();
    }
  }

  void _stopSilently() {
    for (final subscription in _subscriptions) {
      subscription.cancel();
    }
    _subscriptions.clear();
    final player = _player;
    _player = null;
    if (player != null) {
      widget.coordinator.stopped(_pauseFromCoordinator);
      player.stop();
      player.dispose();
    }
    _playing = false;
    _position = Duration.zero;
    _duration = Duration.zero;
  }

  @override
  void dispose() {
    _stopSilently();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: kSurface,
        border: Border.all(color: kBorderSoft),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              IconButton(
                tooltip: _playing ? 'Pausar' : 'Tocar',
                onPressed: _player == null ? null : _toggle,
                icon: Icon(
                  _playing ? Icons.pause : Icons.play_arrow,
                  color: kAccent,
                ),
              ),
              Expanded(
                child: Slider(
                  min: 0,
                  max: _duration.inMilliseconds > 0
                      ? _duration.inMilliseconds.toDouble()
                      : 1,
                  value: _position.inMilliseconds
                      .clamp(0, _duration.inMilliseconds)
                      .toDouble()
                      .clamp(
                        0,
                        _duration.inMilliseconds > 0
                            ? _duration.inMilliseconds.toDouble()
                            : 1,
                      ),
                  onChanged: _duration.inMilliseconds > 0
                      ? (value) => _player?.seek(
                          Duration(milliseconds: value.round()),
                        )
                      : null,
                ),
              ),
              SizedBox(
                width: 96,
                child: Text(
                  '${_format(_position)} / ${_format(_duration)}',
                  textAlign: TextAlign.end,
                  style: const TextStyle(fontSize: 12, color: kInkCaption),
                ),
              ),
            ],
          ),
          if (_error != null)
            Text(
              'Não consegui abrir o áudio ${widget.mark.file}: $_error',
              style: const TextStyle(fontSize: 13, color: kBadColor),
            )
          else if (widget.mark.caption != null &&
              widget.mark.caption!.isNotEmpty)
            Text(
              widget.mark.caption!,
              style: const TextStyle(fontSize: 13, color: kInkCaption),
            ),
        ],
      ),
    );
  }

  static String _format(Duration duration) {
    final total = duration.inSeconds;
    final minutes = total ~/ 60;
    final seconds = total % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }
}
