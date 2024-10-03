class Timemap {
  List<TimeItem> itens;

  Timemap({required this.itens});

  factory Timemap.fromJson(List<dynamic> json) {
    List<TimeItem> itens = <TimeItem>[];

    if (json.isNotEmpty) {
      for (int i = 0; i < json.length; i++) {
        var item = TimeItem.fromJson(json[i]);
        itens.add(item);
      }
    }

    return Timemap(itens: itens);
  }

  List<dynamic> toJson() => itens;
}

class TimeItem {
  double qstamp;
  int tstamp;
  double? tempo;
  List<String> on;
  List<String> off;

  TimeItem(
      {required this.qstamp,
        required this.tstamp,
        this.tempo,
        this.on = const <String>[],
        this.off = const <String>[]});

  factory TimeItem.fromJson(Map<String, dynamic> json) {
    var qstamp = (json['qstamp'] as num).toDouble();
    var tstamp = (json['tstamp'] as num).toInt();

    double? tempo;
    if (json.containsKey('tempo')) {
      String tempoStr = json['tempo'].toString();
      String newStr = tempoStr.replaceAll(',', '.');
      tempo = double.tryParse(newStr);
    }

    List<String> on = <String>[];
    if (json.containsKey('on') && json['on'].length > 0) {
      for (dynamic s in json['on']) {
        on.add(s as String);
      }
    }

    List<String> off = <String>[];
    if (json.containsKey('off') && json['off'].length > 0) {
      for (dynamic s in json['off']) {
        off.add(s as String);
      }
    }

    return TimeItem(
        qstamp: qstamp, tstamp: tstamp, on: on, off: off, tempo: tempo);
  }

  Map<String, dynamic> toJson() => {
    'qstamp': qstamp,
    'tstamp': tstamp,
    'tempo': tempo,
    'on': on,
    'off': off
  };
}

class Note {
  String id;
  int pitch;
  int duration;
  int time;

  Note(
      {required this.id,
        required this.pitch,
        required this.duration,
        required this.time});

  factory Note.fromJson(String id, Map<String, dynamic> json) {
    return Note(
      id: id,
      pitch: json['pitch'],
      duration: json['duration'],
      time: json['time'],
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'pitch': pitch,
    'duration': duration,
    'time': time,
  };
}

class NoteMap {
  Map<String, Note> map = <String, Note>{};

  void addNote(Note note) {
    map[note.id] = note;
  }

  Map<String, dynamic> toJson() => map;
}
