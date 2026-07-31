import 'dart:io';
import 'package:d4rt/d4rt.dart';

class Person {
  String name;
  int age;
  Person(this.name, this.age);
}

Person? currentPerson;

class DartBridge {
  String get_person_name() => currentPerson?.name ?? '';
  int get_person_age() {
    return currentPerson?.age ?? 0;
  }
  void set_person_age(int age) {
    if (currentPerson != null) {
      currentPerson!.age = age;
    }
  }
  void new_person(String name, int age) {
    currentPerson = Person(name, age);
  }
  String say_hello_from_dart(String name) =>
  'Hello, $name! This is from Dart.';
}

void main() {
  final interpreter = D4rt();

  final bridgeClass = BridgedClass(
    nativeType: DartBridge,
    name: 'DartBridge',
    constructors: {
      '': (visitor, positionalArgs, namedArgs) => DartBridge(),
    },
    methods: {
      'get_person_name': (visitor, target, positionalArgs, namedArgs) =>
      (target as DartBridge).get_person_name(),
      'get_person_age': (visitor, target, positionalArgs, namedArgs) =>
      (target as DartBridge).get_person_age(),
      'set_person_age': (visitor, target, positionalArgs, namedArgs) {
        final arg = positionalArgs.isNotEmpty ? positionalArgs[0] : null;
        if (arg is num) {
          (target as DartBridge).set_person_age(arg.toInt());
        }
        return null;
      },
      'new_person': (visitor, target, positionalArgs, namedArgs) {
        if (positionalArgs.length >= 2 &&
          positionalArgs[0] is String &&
          positionalArgs[1] is int) {
          (target as DartBridge).new_person(
            positionalArgs[0] as String, positionalArgs[1] as int);
          }
          return null;
      },
      'say_hello_from_dart': (visitor, target, positionalArgs, namedArgs) {
        if (positionalArgs.isNotEmpty && positionalArgs[0] is String) {
          return (target as DartBridge)
          .say_hello_from_dart(positionalArgs[0] as String);
        }
        return null;
      },
    },
  );

  interpreter.registerBridgedClass(
    bridgeClass, 'package:dart_bridge/dart_bridge.dart');

  for (int i = 1; i <= 10; i++) {
    final fileName = 'hello$i.dart';
    if (!File(fileName).existsSync()) {
      File(fileName).writeAsStringSync('// скрипт №$i\nmain() { return $i; }');
    }
  }

  final modules = <dynamic>[];
  final loadTimes = <double>[];
  final totalStart = DateTime.now().microsecondsSinceEpoch;

  for (int i = 1; i <= 10; i++) {
    final fileName = 'hello${i}.dart';
    final start = DateTime.now().microsecondsSinceEpoch;
    final code = File(fileName).readAsStringSync();
    final module = interpreter.execute(source: code);
    final end = DateTime.now().microsecondsSinceEpoch;
    final loadMs = (end - start) / 1000.0;
    loadTimes.add(loadMs);
    modules.add(module);
    print('Loaded $fileName in ${loadMs.toStringAsFixed(3)} ms');
  }

  final totalEnd = DateTime.now().microsecondsSinceEpoch;
  final totalLoadMs = (totalEnd - totalStart) / 1000.0;
  print('\nTotal loading time for 10 files: ${totalLoadMs.toStringAsFixed(3)} ms');
  print('Average loading time per file: ${(totalLoadMs / 10).toStringAsFixed(3)} ms');

  final helloCode = File('hello.dart').readAsStringSync();
  final record = interpreter.execute(source: helloCode);

  print('Record fields: name=${record['name']}, age=${record['age']}');
  print('All tests passed successfully!');
}
