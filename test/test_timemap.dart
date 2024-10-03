//import 'package:test/test.dart';
import 'package:flutter/foundation.dart';
import 'package:zywny/sheet_abstractions.dart';
import 'package:zywny/timemap_runner.dart';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

void main() async {
    var f = File('test/Chopin_-_Raindrop_Prelude.timemap.json');
    var str = f.readAsStringSync();
    var map = jsonDecode(str);
    var timeMap = Timemap.fromJson(map);
    var runner = TimemapRunner(timeMap);

    if (kDebugMode) {
      print('main isolate: ${Isolate.current.hashCode}');
    }

    runner.addListener((TimeEvent event) {
        if (kDebugMode) {
          print('event scheduled: ${event.scheduled}');
        }

        for(var offNote in event.offNotes) {
            if (kDebugMode) {
              print('  off note: $offNote');
            }
        }
        for(var onNote in event.onNotes) {
            if (kDebugMode) {
              print('  on  note: $onNote');
            }
        }
    });

    await runner.spawn();
    if (kDebugMode) {
      print('after runner.spawn');
    }
}