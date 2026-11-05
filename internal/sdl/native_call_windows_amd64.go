//go:build windows && amd64

package sdl

import (
	"fmt"
	"syscall"
)

//go:uintptrescapes
func nativeCall(function uintptr, args ...uintptr) uintptr {
	if function == 0 {
		panic("sdl: native function pointer is nil")
	}
	result, _, errno := syscall.SyscallN(function, args...)
	if errno != 0 {
		panic(fmt.Sprintf("sdl: native call failed with errno %d", errno))
	}
	return result
}
