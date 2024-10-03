import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:zywny/sheet_abstractions.dart';
import 'dart:isolate';

class _Stopwatch {
  Stopwatch watch = Stopwatch();

  int getElapsedMili() {
    return watch.elapsedMilliseconds;
  }

  void reset() {
    watch.reset();
  }

  void start() {
    watch.start();
  }

  void stop() {
    watch.stop();
  }
}

class _FakeStopwatch extends _Stopwatch {
  int elapsed = 0;
  bool isRunning = false;

  @override
  int getElapsedMili() {
    if (isRunning) elapsed++;
    return elapsed;
  }

  @override
  void reset() {
    elapsed = 0;
  }

  @override
  void start() {
    isRunning = true;
  }

  @override
  void stop() {
    isRunning = false;
  }
}

class _Waiter {
  Future<int> wait(_Stopwatch watch, int untilTimeInMilliseconds) async {
    var elapsed = watch.getElapsedMili() * 10;

    while (elapsed < untilTimeInMilliseconds) {
      int toWait = (untilTimeInMilliseconds - elapsed) ~/ 2;
      if (toWait > 5) {
        await Future.delayed(Duration(milliseconds: toWait), () {});
      }
      elapsed = watch.getElapsedMili() * 10;
    }

    return watch.getElapsedMili();
  }
}

class _FakeWaiter extends _Waiter {
  @override
  Future<int> wait(_Stopwatch watch, int toWait) async {
    while (watch.getElapsedMili() < (toWait - 1)) {
      {}
    }
    return watch.getElapsedMili();
  }
}

enum KillTime { immediate }

class TimeEvent {
  final int scheduled;
  final List<String> offNotes;
  final List<String> onNotes;

  TimeEvent(
      {required this.scheduled,
      required this.offNotes,
      required this.onNotes});
}

class TimemapRunner {
  final Timemap _timemap;
  List<void Function(TimeEvent)> listeners = <void Function(TimeEvent)>[];
  Isolate? isolate;

  void addListener(void Function(TimeEvent) onTime) {
    listeners.add(onTime);
  }

  _Stopwatch _watch = _Stopwatch();
  _Waiter _waiter = _Waiter();

  TimemapRunner(this._timemap);

  TimemapRunner.fake(this._timemap) {
    _watch = _FakeStopwatch();
    _waiter = _FakeWaiter();
  }

  set timemap(Timemap timemap) {
    this.timemap = timemap;
  }

  void _run(SendPort port) async {
    if (kDebugMode) {
      print('starting....');
    }
    _watch.stop();
    _watch.reset();
    _watch.start();


    if (kDebugMode) {
      print('timemap itens: ${_timemap.itens.length}');
    }

    for (var item in _timemap.itens) {

      await _waiter.wait(_watch, item.tstamp);

      port.send(TimeEvent(
          onNotes: item.on,
          offNotes: item.off,
          scheduled: item.tstamp));
    }

    port.send(KillTime.immediate);

    if (kDebugMode) {
      print('finished run');
    }
  }

  Future<void> spawn() async {
    var receiver = ReceivePort();
    receiver.listen((dynamic message) {
      if (message is TimeEvent) {
        for (var listener in listeners) {
          listener(message);
        }
      } else if (message is KillTime) {
        receiver.close();
      }
    });

    isolate = await Isolate.spawn(_run, receiver.sendPort);
  }

  void cancel() {
    isolate?.kill(priority: Isolate.immediate);
  }
}
