//go:build windows && amd64

package cflatnative

// #cgo windows,amd64 LDFLAGS: -lmingw32 -luser32 -lgdi32 -lwinmm -limm32 -lole32 -loleaut32 -luuid -lversion -lsetupapi -lshell32 -lshlwapi -lws2_32
import "C"

