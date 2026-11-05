# Pure Go and HikeC trampoline comparison

## Debug run

The sample was built without cgo and with optimizations disabled, then run
under Delve:

```sh
CGO_ENABLED=0 go build -gcflags='all=-N -l' \
  -o /tmp/triangle_vulkan_pure_go_dbg \
  ./examples/triangle_vulkan_pure_go
CGO_ENABLED=0 SDL3_LIBRARY=third_party/SDL/build/sdl-debug-shared/libSDL3.so \
  dlv exec /tmp/triangle_vulkan_pure_go_dbg
```

GDB was not installed in the environment. Delve 1.27.2 was used instead;
the runtime was Go 1.27.3 on Linux/amd64.

## Go cgo reference on Linux/amd64

To compare against Go's actual generated bridge, a temporary cgo package with
a single `C.add_one(int)` call was built on this host using Go 1.27.3. The
generated `_cgo_gotypes.go` wrapper is structurally:

```go
func _Cfunc_add_one(p0 _Ctype_int) (r1 _Ctype_int) {
    _cgo_runtime_cgocall(
        _cgo_add_one,
        uintptr(unsafe.Pointer(&p0)),
    )
    return
}
```

Compiler assembly for the generated `C.add_one` wrapper sets up the C-call
frame and calls `runtime.cgocall(SB)`; it does not call `add_one` directly
from the goroutine stack. Go's `runtime/cgocall.go` describes the next steps:

1. `runtime.cgocall` calls `entersyscall()` so the scheduler knows this M is
   executing foreign code and can schedule other goroutines.
2. It calls `runtime.asmcgocall`.
3. Linux/amd64 `runtime.asmcgocall` switches from the current goroutine stack
   to `m.g0`'s OS-thread stack, aligns it for the C ABI, and calls the
   generated C wrapper.
4. The C wrapper calls the actual C function and stores results in its
   argument/result frame. On return, `asmcgocall` restores the goroutine stack
   and `cgocall` calls `exitsyscall()`.

The relevant documented source is
[`runtime/cgocall.go`](https://cs.opensource.google/go/go/+/go1.27.3:src/runtime/cgocall.go)
and the amd64 stack-switch implementation is in
[`runtime/asm_amd64.s`](https://cs.opensource.google/go/go/+/go1.27.3:src/runtime/asm_amd64.s).
This separates two responsibilities that should not be conflated: stack
switching protects the Go goroutine stack from foreign C stack use, while
`entersyscall`/`exitsyscall` integrate the foreign call with scheduler and
runtime accounting.

A breakpoint on `main.run` at the `SDL_Init` call, followed by a breakpoint
on `syscallX`, stopped in the native-call assembly with this stack:

```text
syscallX
runtime.asmcgocall
runtime.cgocall
bnema.dev/purego.syscall_SyscallN
bnema.dev/purego.RegisterFunc.func4
reflect.callReflect
reflect.makeFuncStub
main.run
```

Continuing the same breakpoint showed the SDL call sites for `SDL_Init`,
`SDL_Vulkan_LoadLibrary`, `SDL_CreateWindow`,
`SDL_Vulkan_GetInstanceExtensions`, and
`SDL_Vulkan_GetVkGetInstanceProcAddr`. They all enter the same `syscallX`
machine-code entry. The reflected function wrapper is not a separate
per-SDL-symbol assembly stub.

The Vulkan `vkCreateInstance` path was also checked in a separate Delve run.
Its stack at `syscallX` was:

```text
syscallX
runtime.asmcgocall
runtime.cgocall
bnema.dev/purego.syscall_SyscallN
bnema.dev/purego.Syscall15
bnema.dev/purego.Syscall6
vulkan.(*GlobalDispatch).CreateInstance
main.newRenderer
```

Unlike the SDL function fields, the generated Vulkan dispatch methods call
`purego.Syscall6` directly; they do not call `reflect.MakeFunc` for each
Vulkan command.

## Pure Go call bridge assembly

The no-cgo debug executable's `syscallX` symbol starts at `0x5b90c0` in that
build (491 bytes; address and size can change across builds). Delve stopped
at its entry, and `go tool objdump` was used to verify this full instruction
sequence. The listing below follows `sys_amd64.s`; `syscallArgs_*` are
structure fields addressed by the assembler using the offsets from
`go_asm.h`.

```asm
TEXT syscallX(SB), NOSPLIT, $224
    PUSHQ BP                   // assembler-generated frame prologue
    MOVQ SP, BP
    SUBQ $224, SP
    MOVQ DI, 216(SP)           // save syscallArgs pointer
    MOVQ DI, R11
    MOVQ 264(R11), X0           // f1-f8 -> SysV XMM argument registers
    MOVQ 272(R11), X1
    MOVQ 280(R11), X2
    MOVQ 288(R11), X3
    MOVQ 296(R11), X4
    MOVQ 304(R11), X5
    MOVQ 312(R11), X6
    MOVQ 320(R11), X7
    MOVQ 8(R11), DI             // a1-a6 -> SysV integer argument registers
    MOVQ 16(R11), SI
    MOVQ 24(R11), DX
    MOVQ 32(R11), CX
    MOVQ 40(R11), R8
    MOVQ 48(R11), R9
    MOVQ 56(R11), R12           // a7-a32 -> stack argument slots
    MOVQ R12, 0(SP)
    MOVQ 64(R11), R12
    MOVQ R12, 8(SP)
    MOVQ 72(R11), R12
    MOVQ R12, 16(SP)
    MOVQ 80(R11), R12
    MOVQ R12, 24(SP)
    MOVQ 88(R11), R12
    MOVQ R12, 32(SP)
    MOVQ 96(R11), R12
    MOVQ R12, 40(SP)
    MOVQ 104(R11), R12
    MOVQ R12, 48(SP)
    MOVQ 112(R11), R12
    MOVQ R12, 56(SP)
    MOVQ 120(R11), R12
    MOVQ R12, 64(SP)
    MOVQ 128(R11), R12
    MOVQ R12, 72(SP)
    MOVQ 136(R11), R12
    MOVQ R12, 80(SP)
    MOVQ 144(R11), R12
    MOVQ R12, 88(SP)
    MOVQ 152(R11), R12
    MOVQ R12, 96(SP)
    MOVQ 160(R11), R12
    MOVQ R12, 104(SP)
    MOVQ 168(R11), R12
    MOVQ R12, 112(SP)
    MOVQ 176(R11), R12
    MOVQ R12, 120(SP)
    MOVQ 184(R11), R12
    MOVQ R12, 128(SP)
    MOVQ 192(R11), R12
    MOVQ R12, 136(SP)
    MOVQ 200(R11), R12
    MOVQ R12, 144(SP)
    MOVQ 208(R11), R12
    MOVQ R12, 152(SP)
    MOVQ 216(R11), R12
    MOVQ R12, 160(SP)
    MOVQ 224(R11), R12
    MOVQ R12, 168(SP)
    MOVQ 232(R11), R12
    MOVQ R12, 176(SP)
    MOVQ 240(R11), R12
    MOVQ R12, 184(SP)
    MOVQ 248(R11), R12
    MOVQ R12, 192(SP)
    MOVQ 256(R11), R12
    MOVQ R12, 200(SP)
    XORL AX, AX                 // SysV variadic vector-register count = 0
    MOVQ 0(R11), R10            // target function address
    CALL R10                    // indirect call
    MOVQ 216(SP), DI
    MOVQ AX, 8(DI)              // r1
    MOVQ DX, 16(DI)             // r2
    MOVQ X0, 264(DI)            // floating-point return slots
    MOVQ X1, 272(DI)
    MOVQ $0, 24(DI)             // Linux: clear error result
    XORL AX, AX                 // return success to runtime.cgocall
    ADDQ $224, SP               // assembler-generated frame epilogue
    POPQ BP
    RET
```

`syscallX` is a shared generic ABI bridge, not machine code emitted separately
for every API. `TEXT $224` produces a 224-byte frame; the amd64 assembler's
prologue/epilogue preserve BP and reserve/release it. Its target address and
argument values are supplied in the `syscallArgs` record. Purego's
`runtime.cgocall`/`runtime.asmcgocall` arrange the g0/C-call context before
entering this assembly. The bridge puts up to six integer-class arguments in
SysV registers and the remaining slots on the C stack, calls the target via
R10, then records RAX/RDX and XMM0/XMM1. On Linux it clears the error slot.
The Vulkan `Syscall6` call observed here uses only the first six integer
arguments; the SDL `RegisterFunc` calls also use this generic bridge.

The SDL function-value side has an additional reflection path:
`reflect.makeFuncStub.abi0` enters `reflect.callReflect`, which invokes the
closure built by `purego.RegisterFunc`. The closure converts the typed Go
arguments into the generic record before calling `syscall_SyscallN`.

## HikeC SDL stub

The comparison target was the user-provided `stub_linux_amd64.s` snapshot
(1010 lines); its inspected functions also match the current generated file
at [`internal/sdl/stub_linux_amd64.s`](../../internal/sdl/stub_linux_amd64.s).
The snapshot contains 92 `TEXT` routines: 46 API-call stubs containing
`CALL c_<API>(SB)`, plus 46 `_hike_<API>Ptr` accessors. The API stubs use the
same stack-alignment/call/restore skeleton; the argument load and return
copy vary with each API's signature. For example, the file also uses
`MOVBQZX` for byte/bool arguments, `MOVLQSX` for signed 32-bit arguments,
and `MOVSS` for floating-point arguments and results.
`_hike_Init` has this sequence:

```asm
TEXT ·_hike_Init(SB), 0, $32-9
PCDATA $PCDATA_UnsafePoint, $-2
MOVQ SP, R11
ANDQ $15, R11
SUBQ R11, SP
MOVQ R11, 8(SP)
MOVQ 16(BP), DI
CALL c_Init(SB)
MOVQ 8(SP), R11
ADDQ R11, SP
PCDATA $PCDATA_UnsafePoint, $0
MOVB AX, ret+8(FP)
RET
```

The same user-provided snapshot defines these sample-related stubs:

| HikeC stub | Go ABI inputs -> C ABI | Native call | Go result |
|---|---|---|---|
| `_hike_Init` | `16(BP)` -> `DI` | `CALL c_Init(SB)` | `AX` -> byte result |
| `_hike_CreateWindow` | `16,24,32,40(BP)` -> `DI,SI,DX,CX` | `CALL c_CreateWindow(SB)` | `AX` -> pointer-sized result |
| `_hike_PollEvent` | `16(BP)` -> `DI` | `CALL c_PollEvent(SB)` | `AX` -> byte result |
| `_hike_DestroyWindow` | `16(BP)` -> `DI` | `CALL c_DestroyWindow(SB)` | no result |
| `_hike_Quit` | no arguments | `CALL c_Quit(SB)` | no result |

These are API-specific HikeC trampolines, but their common instruction
pattern is the same: mark the changing-SP interval unsafe, calculate the
16-byte stack adjustment into `R11`, subtract and save it at `8(SP)`, load
arguments directly from BP-relative Go ABI slots, call a statically named
`c_<API>` target, restore SP, reset the unsafe-point metadata, then copy AX
to the Go result slot when the function has a result. For `DestroyWindow`
and `Quit`, there is no return-value copy.

The inspected HikeC API stubs do not show the cgo sequence above: for
example, `_hike_Init` executes `CALL c_Init(SB)` directly. Its SP adjustment
aligns the current stack, and `PCDATA_UnsafePoint` describes an unsafe
interval, but neither instruction sequence performs the `g`/`g0` stack
switch nor the `entersyscall`/`exitsyscall` scheduler transition. Therefore
the current generated assembly does not establish that the C call runs on a
separate OS-thread stack. Unless another HikeC-generated layer performs that
transition before entering this stub (none appears in the inspected generated
Go wrapper or assembly), the cgo safety guarantees cannot be inferred from
stack alignment alone.

The `_hike_<API>Ptr` routines are different: they do not call the native
function or marshal arguments. Each uses `LEAQ c_<API>(SB), AX`, stores AX
in the Go return slot, and returns the native function address.

## Temporary Linux/amd64 bridge

For a runtime test before changing HikeC itself, the Linux SDL wrappers used
by `examples/simple` and `examples/triangle_vulkan` now call their existing
`_hike_<API>Ptr` accessor and pass the address to `runtime.cgocall`. This
includes window/event/quit operations and the triangle's SDL_GPU device,
shader, pipeline, render-pass, draw, and submission calls. A generic C-ABI
dispatcher appended to `stub_linux_amd64.s` runs on g0, forwards up to six
integer/pointer arguments to that target, and stores the result in its frame.
Other HikeC API wrappers still use their original direct-call stubs.

This is a temporary Linux/amd64 path, not a change to generated HikeC source.
The dispatcher only handles integer-class arguments and does not support C
callbacks; it must not be used for unrelated APIs without extending and
validating those cases. Both the simple SDL window sample and the SDL_GPU
Vulkan triangle were run through startup and their event/render loops with
this bridge.

The attached snapshot contains no Vulkan-named stubs. Therefore the
`vkCreateInstance` dispatch path has no corresponding `_hike_vkCreateInstance`
entry there to compare; the direct comparison is between Purego's generic
Vulkan call bridge and the snapshot's SDL API stubs.

## Comparison

| Property | Pure Go / purego | HikeC SDL stub |
|---|---|---|
| Per-API machine-code stub | No; typed reflected function values share the reflection entry and generic `syscallX` bridge | Yes; 46 `_hike_<API>` call stubs in the snapshot; separate `_hike_<API>Ptr` accessors return target addresses |
| Target selection | Function address loaded from `syscallArgs` and called indirectly through `R10` | Static `CALL c_<API>(SB)` |
| Go argument extraction | `RegisterFunc` uses a reflection closure to pack values into `syscallArgs`; `syscallX` loads its fields | BP-relative Go ABI argument slots are loaded directly into SysV registers |
| Runtime transition | `runtime.cgocall` performs `entersyscall`, then `runtime.asmcgocall` switches to g0 before the native call; `exitsyscall` restores runtime accounting | The inspected HikeC stub calls the native target directly; no equivalent transition is visible in the generated wrapper/stub |
| Stack handling | Fixed 224-byte frame with slots for `a1` through `a32`; this trace's Vulkan `Syscall6` uses only six integer arguments | Stub saves the dynamic SP alignment adjustment, aligns SP, then restores it after the call |
| Return handling | Generic bridge stores RAX/RDX and XMM0/XMM1 in the record; reflection converts typed results | Stub moves AX to the Go result slot when needed |
| Preemption metadata | Transition is visible in the runtime call path | Generated SDL stub marks the dynamic-SP interval unsafe with PCDATA |

Both paths marshal arguments and returns between Go and the SysV AMD64 C ABI.
The important distinction is that purego uses a generic runtime-mediated
indirect-call bridge, whereas HikeC generates a statically targeted trampoline
for each API. Go's cgo bridge shows that stack alignment alone is not the full
foreign-call boundary: stack switching and runtime syscall accounting are
separate parts of the transition. The HikeC-generated call stubs should be
reviewed against both requirements.
