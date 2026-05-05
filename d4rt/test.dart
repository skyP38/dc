import 'package:d4rt/d4rt.dart';

void main() {
  final interpreter = D4rt();

  final code = '''
    int fib(int n) {
      if (n <= 1) return n;
      return fib(n - 1) + fib(n - 2);
    }

    main() {
      return fib(10);
    }
  ''';

  final result = interpreter.execute(source: code);
  print('Результат выполнения: $result');
}
