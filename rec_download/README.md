$ go build -tags luajitter -o app_luajitter
$ ./app_luajitter 
Hello from Teal to Gopher
Hello from Go to TealUser
Teal: Created Person Alice, age 25
Teal: New age after increment: 26
2026/07/14 20:11:21 Age after processing: 26
2026/07/14 20:11:21 Teal script executed successfully!



в `vendor/modulrs.txt` добавить + `vendor` из luajit-go
```
# github.com/cannibalvox/luajitter v1.1.8
## explicit
github.com/cannibalvox/luajitter
```


go doc github.com/folays/luajit-go.State

$ go build -mod=vendor -tags luajit -o app_luajit
$ ./app_luajit
Hello from Teal to Gopher
Hello from Go to TealUser
Teal: Created Person Alice, age 25
Teal: New age after increment: 26
2026/07/15 19:10:40 Age after processing: 26
Record fields: name=Bob, age=30
Greeting from record: Record: Hello, I'm Bob, age 30
2026/07/15 19:10:40 Teal script executed successfully!
потом можно go build  -tags luajit -o app_luajit


для переключения из го в джиттер надо go build -tags luajitter -o app_luajitter -mod=mod
для обратного из go.mod надо удалить 
require github.com/baohavan/go-pointer v0.0.0-20181113050700-6f48d0300d21 // indirect
и запустить с -mod=vendor


 
go doc -all ./lua




Сборка с luajit-go
bash

go build -mod=vendor -tags luajit -o app_luajit
./app_luajit <package-name>

Сборка с luajitter
bash

go build -tags luajitter -o app_luajitter -mod=mod
./app_luajitter <package-name>

