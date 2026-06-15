# Минимальное ядро на Odin + Multiboot

Сборка загрузочного ядра для x86 (32‑бит) на языке Odin с использованием Multiboot, линковка через GNU ld и запуск в QEMU.

## Сборка

```bash
# 1. Ассемблирование заголовка Multiboot
as --32 header.s -o header.o

# 2. Компиляция ядра Odin в объектный файл
odin build kernel.odin -file -build-mode:obj -target:linux_i386 -no-crt -default-to-nil-allocator -no-thread-local

# 3. Линковка
ld -m elf_i386 -T linker.ld -nostdlib -o kernel.elf header.o kernel*.o
```

После успешной сборки получается файл kernel.elf, готовый к загрузке через Multiboot‑совместимый загрузчик.

## Запуск в QEMU

```bash
qemu-system-i386 -kernel kernel.elf
```

## Полезные команды
### Просмотр секций

```bash
readelf -S kernel.elf
```
Секция `text` должна быть по адресу `0x10000`.
> В нее включены заголовка для Multiboot в `header.s`

### Просмотр заголовков и кода
```
objdump -h kernel.elf      			  # заголовки секций
objdump -d kernel.elf      			  # дизассемблированный код
objdump -s -j .multiboot kernel.elf   # дамп заголовка Multiboot
```
## Отладка с GDB
1. Сборка ядра с отладочной информацией

```bash
odin build kernel.odin -file -build-mode:obj -target:linux_i386 -no-crt -default-to-nil-allocator -no-thread-local -debug
ld -m elf_i386 -T linker.ld -nostdlib -o kernel.elf header.o kernel*.o
```

2. Запуск QEMU в режиме ожидания GDB

```bash
qemu-system-i386 -cdrom kernel.iso -boot d -s -S
```
* `-s` открывает порт `1234` для GDB
* `-S` останавливает выполнение до подключения отладчика

3. В другом терминале необходимо запустить GDB:

```bash
gdb kernel.elf
(gdb) target remote :1234
(gdb) break _start
(gdb) continue   # или c
(gdb) stepi      # пошаговое выполнение инструкций
(gdb) info registers
```
