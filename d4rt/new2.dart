import 'package:d4rt/d4rt.dart';

class NativeCalculator {
  final String name;
  NativeCalculator(this.name);

  int add(int a, int b) {
    print('[$name] Сложение $a + $b = ${a + b}');
    return a + b;
  }

  void showMessage(String msg) {
    print('[$name] Сообщение: $msg');
  }
}

void main() {
  final interpreter = D4rt();

  // Регистрация моста
  final nativeBridge = BridgedClass(
    nativeType: NativeCalculator,
    name: 'NativeCalculator',
    constructors: {
      '': (visitor, positionalArgs, namedArgs) {
        if (positionalArgs.isNotEmpty && positionalArgs[0] is String) {
          return NativeCalculator(positionalArgs[0] as String);
        }
        throw ArgumentError('Конструктор ожидает name (String)');
      },
    },
    methods: {
      'add': (visitor, target, positionalArgs, namedArgs) {
        final calc = target as NativeCalculator;
        if (positionalArgs.length >= 2 && positionalArgs[0] is int && positionalArgs[1] is int) {
          return calc.add(positionalArgs[0] as int, positionalArgs[1] as int);
        }
        throw ArgumentError('add ожидает два целых числа');
      },
      'showMessage': (visitor, target, positionalArgs, namedArgs) {
        final calc = target as NativeCalculator;
        if (positionalArgs.isNotEmpty && positionalArgs[0] is String) {
          calc.showMessage(positionalArgs[0] as String);
          return null;
        }
        throw ArgumentError('showMessage ожидает строку');
      },
    },
  );

  interpreter.registerBridgedClass(nativeBridge, 'package:myapp/native_calculator.dart');

  const fullCode = '''
    import 'package:myapp/native_calculator.dart';

    class DynamicCounter {
      int _count = 0;

      void increment() {
        _count++;
        print('[DynamicCounter] Счётчик увеличен до \$_count');
      }

      int getValue() => _count;

      void useNative(NativeCalculator calc, int x, int y) {
        print('[DynamicCounter] Вызываем нативный калькулятор...');
        int result = calc.add(x, y);
        print('[DynamicCounter] Результат: \$result');
        calc.showMessage('Привет!');
      }
    }

    DynamicCounter? _globalCounter;

    void setCounter(DynamicCounter obj) {
      _globalCounter = obj;
    }

    void callIncrement() {
      _globalCounter?.increment();
    }

    int callGetValue() {
      return _globalCounter?.getValue() ?? 0;
    }

    void callUseNative(NativeCalculator calc, int x, int y) {
      _globalCounter?.useNative(calc, x, y);
    }

    DynamicCounter main() {
      print('--- Внутри интерпретатора ---');
      var counter = DynamicCounter();
      counter.increment();

      var nativeCalc = NativeCalculator('Калькулятор из интерпретатора');
      counter.useNative(nativeCalc, 10, 20);

      setCounter(counter);
      return counter;
    }
  ''';

  final dynamicCounter = interpreter.execute(source: fullCode);
  print('===== ИНТЕРПРЕТАТОР ВЕРНУЛ ОБЪЕКТ: $dynamicCounter =====');

  if (dynamicCounter is InterpretedInstance) {
    // Вызов глобальных функций
    print('\n--- Вызов callIncrement() ---');
    interpreter.eval('callIncrement();');

    print('\n--- Вызов callGetValue() ---');
    final value = interpreter.eval('callGetValue();');
    print('Значение счётчика: $value');

    print('\n--- Вызов callUseNative() с внешним нативным объектом ---');
    final externalNative = NativeCalculator('Внешний калькулятор');
    interpreter.eval('callUseNative(NativeCalculator("Внешний калькулятор"), 100, 200);');

    interpreter.eval('''
    void printMessage() {
      print('Дополнительная функция');
      if (_globalCounter != null) {
        print('Текущий счётчик: \${_globalCounter!.getValue()}');
      }
    }
    ''');
    print('\n--- Вызов дополнительной функции printMessage() ---');
    interpreter.eval('printMessage();');
  } else {
    print('Ошибка: ожидался InterpretedInstance, получен ${dynamicCounter.runtimeType}');
  }
}
