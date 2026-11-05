//go:build linux && amd64

package cflatnative

// #cgo linux,amd64 LDFLAGS: -lm
import "C"

// Native system libraries are deferred to the final Go external link.
