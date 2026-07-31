import 'package:dart_bridge/dart_bridge.dart';

main() {
  var bridge = DartBridge();
  var get_person_name = bridge.get_person_name;
  var get_person_age = bridge.get_person_age;
  var set_person_age = bridge.set_person_age;
  var new_person = bridge.new_person;
  var say_hello_from_dart = bridge.say_hello_from_dart;

  var say_hello = (String name) {
    print('Hello from Dart script to $name');
  };

  var call_dart_function = () {
    final msg = bridge.say_hello_from_dart('DartUser');
    print(msg);
  };

  var create_and_process = (String name, int age) {
    bridge.new_person(name, age);
    final n = bridge.get_person_name();
    final a = bridge.get_person_age();
    print('Dart: Created Person $n, age $a');
    bridge.set_person_age(a + 1);
    print('Dart: New age after increment: ${bridge.get_person_age()}');
  };

  var create_record = (String name, int age) {
    final rec = {
      'name': name,
      'age': age,
    };
    print('Record: Hello, I\'m ${rec['name']}, age ${rec['age']}');
    return rec;
  };

  say_hello('Gopher');
  call_dart_function();
  create_and_process('Bob', 25);
  var record = create_record('David', 35);
  return record;
}
