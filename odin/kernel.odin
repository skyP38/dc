package main

VGA_ADDRESS :: 0xB8000
VGA_WIDTH   :: 80
VGA_HEIGHT  :: 25

print :: proc(str: string, row, col: int) {
    video := cast([^]u16)uintptr(VGA_ADDRESS)
    offset := row * VGA_WIDTH + col
    for i in 0 ..< len(str) {
        c := u16(str[i])
        video[offset + i] = c | (u16(0x0F) << 8)
    }
}

@(export, link_name="__umoddi3")
__umoddi3 :: proc "c" (a, b: u64) -> u64 { return 0 }

@(export, link_name="__udivdi3")
__udivdi3 :: proc "c" (a, b: u64) -> u64 { return 0 }

@(export, link_name="__moddi3")
__moddi3 :: proc "c" (a, b: i64) -> i64 { return 0 }

@(export, link_name="__divdi3")
__divdi3 :: proc "c" (a, b: i64) -> i64 { return 0 }

@(export, link_name="kernel_main")
kernel_main :: proc () {
    print("Minimal Kernel Initialized! v0.0.1", 12, 27);
    for { }
}


@(export, link_name="__$startup_runtime")
startup_runtime :: proc "c" () {}

@(export, link_name="__$cleanup_runtime")
cleanup_runtime :: proc "c" () {}
