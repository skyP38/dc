nix-shell -p groovy
groovy main.groovy

Time to load hello.groovy: 228.961907 ms  # real time


nix-shell -p luajitPackages.tl
tl run main.tl
Time to load hello.tl: 5.850 ms  # cpu usage


tl gen main.tl hello.tl
Wrote: main.lua
Wrote: hello.lua

$ luajit main.lua 
Time to load hello.tl: 0.112 ms


$ lua main.lua 
Time to load hello.tl: 0.107 ms



загрузка 1 модуля:
Time to load hello.groovy: 228.961907 ms 

загрузка 1 модуля дважды в одни и те же переменнные
Time to load hello.groovy: 316.710745 ms

загрузка 1 модуля дважды в одни и разные переменные
Time to load hello.groovy: 315.078023 ms

загрузка 2 одинаковых модулей в разные переменные
Time to load hello.groovy: 286.87602 ms



for i in {1..10}; do cp hello.groovy "hello${i}.groovy"; done

groovy 10 files
Loaded hello1.groovy in 119.611 ms
Loaded hello2.groovy in 42.795 ms
Loaded hello3.groovy in 38.162 ms
Loaded hello4.groovy in 41.657 ms
Loaded hello5.groovy in 37.690 ms
Loaded hello6.groovy in 50.531 ms
Loaded hello7.groovy in 25.425 ms
Loaded hello8.groovy in 25.806 ms
Loaded hello9.groovy in 44.373 ms
Loaded hello10.groovy in 33.738 ms

Total loading time for 10 files: 563.637 ms






for i in {1..10}; do cp hello.tl "hello${i}.tl"; done


tl run main.tl
Loaded hello1.tl in 5.340 ms
Loaded hello2.tl in 5.670 ms
Loaded hello3.tl in 3.158 ms
Loaded hello4.tl in 2.612 ms
Loaded hello5.tl in 2.293 ms
Loaded hello6.tl in 2.132 ms
Loaded hello7.tl in 2.364 ms
Loaded hello8.tl in 2.302 ms
Loaded hello9.tl in 3.243 ms
Loaded hello10.tl in 3.386 ms

Total loading time for 10 files: 32.637 ms
Average loading time per file: 3.264 ms
Hello from Teal to Gopher
Hello, TealUser! This is from Teal.
Teal: Created Person Bob, age 25
Teal: New age after increment: 26
Record fields: name=David, age=35
Greet result: Record: Hello, I'm David, age 35

All tests passed successfully!
Time to load hello.tl: 3.028 ms


nix-shell -p dart
dart pub get
dart run main.dart

for i in {1..10}; do cp hello.dart "hello${i}.dart"; done

Loaded hello1.dart in 227.466 ms
Loaded hello2.dart in 10.649 ms
Loaded hello3.dart in 7.785 ms
Loaded hello4.dart in 5.735 ms
Record: Hello, I'm David, age 35
Loaded hello5.dart in 4.239 ms
Loaded hello6.dart in 6.285 ms
Loaded hello7.dart in 5.123 ms
Loaded hello8.dart in 4.791 ms
Loaded hello9.dart in 4.689 ms
Loaded hello10.dart in 4.844 ms

Total loading time for 10 files: 282.542 ms
Average loading time per file: 28.254 ms




for i in {1..10}; do tl gen "hello${i}.tl"; done
luajit main.lua
Loaded hello1.tl in 0.100 ms
Loaded hello2.tl in 0.060 ms
Loaded hello3.tl in 0.057 ms
Loaded hello4.tl in 0.085 ms
Loaded hello5.tl in 0.084 ms
Loaded hello6.tl in 0.044 ms
Loaded hello7.tl in 0.037 ms
Loaded hello8.tl in 0.038 ms
Loaded hello9.tl in 0.039 ms
Loaded hello10.tl in 0.040 ms

Total loading time for 10 files: 0.662 ms
Average loading time per file: 0.066 ms
