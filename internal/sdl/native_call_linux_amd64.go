//go:build linux && amd64

package sdl

import (
	"fmt"
	"runtime"
	"unsafe"
)

//go:linkname runtimeCgocall runtime.cgocall
func runtimeCgocall(fn, arg unsafe.Pointer) int32

type nativeCallFrame struct {
	function uintptr
	args     [6]uintptr
	result   uintptr
}

//go:uintptrescapes
func nativeCall(function uintptr, args ...uintptr) uintptr {
	if function == 0 {
		panic("sdl: native function pointer is nil")
	}
	if len(args) > len(nativeCallFrame{}.args) {
		panic("sdl: native call has more than six arguments")
	}

	frame := nativeCallFrame{function: function}
	copy(frame.args[:], args)
	if status := runtimeCgocall(unsafe.Pointer(nativeCallDispatchPtr()), unsafe.Pointer(&frame)); status != 0 {
		panic(fmt.Sprintf("sdl: runtime.cgocall failed with status %d", status))
	}
	runtime.KeepAlive(&frame)
	return frame.result
}

func nativeCallDispatchPtr() uintptr
