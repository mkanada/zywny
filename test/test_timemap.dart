//import 'package:test/test.dart';
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

    print('main isolate: ${Isolate.current.hashCode}');

    runner.addListener((TimeEvent event) {
        print('event scheduled: ${event.scheduled}');

        for(var offNote in event.offNotes) {
            print('  off note: $offNote');
        }
        for(var onNote in event.onNotes) {
            print('  on  note: $onNote');
        }
    });

    await runner.spawn();
    print('after runner.spawn');
}