package sdl

import (
	"runtime"
	"unsafe"

	internal "github.com/kanryu/go-sdl3/internal/sdl"
)

const (
	InitVideo       = 0x00000020
	WindowResizable uint64 = 0x0000000000000020
)

const (
	EventQuit = internal.EventQuit
	EventWindowShown = internal.EventWindowShown
	EventWindowHidden = internal.EventWindowHidden
	EventWindowExposed = internal.EventWindowExposed
	EventWindowMoved = internal.EventWindowMoved
	EventWindowResized = internal.EventWindowResized
	EventWindowPixelSize = internal.EventWindowPixelSize
	EventWindowMetalResize = internal.EventWindowMetalResize
	EventWindowMinimized = internal.EventWindowMinimized
	EventWindowMaximized = internal.EventWindowMaximized
	EventWindowRestored = internal.EventWindowRestored
	EventWindowMouseEnter = internal.EventWindowMouseEnter
	EventWindowMouseLeave = internal.EventWindowMouseLeave
	EventWindowFocusGained = internal.EventWindowFocusGained
	EventWindowFocusLost = internal.EventWindowFocusLost
	EventWindowClose = internal.EventWindowClose
	EventKeyDown = internal.EventKeyDown
	EventKeyUp = internal.EventKeyUp
	EventTextEditing = internal.EventTextEditing
	EventTextInput = internal.EventTextInput
	EventMouseMotion = internal.EventMouseMotion
	EventMouseButtonDown = internal.EventMouseButtonDown
	EventMouseButtonUp = internal.EventMouseButtonUp
)

type EventValue = internal.EventValue
type QuitEvent = internal.QuitEvent
type WindowEvent = internal.WindowEvent
type KeyboardEvent = internal.KeyboardEvent
type TextEditingEvent = internal.TextEditingEvent
type TextInputEvent = internal.TextInputEvent
type MouseMotionEvent = internal.MouseMotionEvent
type MouseButtonEvent = internal.MouseButtonEvent
type MouseWheelEvent = internal.MouseWheelEvent
type UnknownEvent = internal.UnknownEvent

type Window struct {
	ptr *byte
	title string
	width, height int
}

func Init(flags int) bool { return internal.Init(flags) }
func Quit() { internal.Quit() }
func GetError() string { return internal.GetError() }
func PollEventTyped() (EventValue, bool) { return internal.PollEventTyped() }
func KeyName(key int32) string { return internal.KeyName(key) }

func CreateWindow(title any, width, height int, flags int) *Window {
	var titlePtr *byte
	var bytes []byte
	switch value := title.(type) {
	case string:
		bytes = append([]byte(value), 0)
		titlePtr = &bytes[0]
	case *byte:
		titlePtr = value
	default:
		return nil
	}
	window := internal.CreateWindow(titlePtr, width, height, flags)
	runtime.KeepAlive(bytes)
	if window == nil { return nil }
	titleValue := ""
	if value, ok := title.(string); ok { titleValue = value }
	return &Window{ptr: window, title: titleValue, width: width, height: height}
}

func PollEvent(event *byte) bool { return internal.PollEvent(event) }
func DestroyWindow(window *Window) { if window != nil { window.Destroy() } }
func StartTextInput(window *Window) bool { return window != nil && internal.StartTextInput(window.ptr) }
func StopTextInput(window *Window) bool { return window != nil && internal.StopTextInput(window.ptr) }

func (w *Window) Destroy() { if w != nil && w.ptr != nil { internal.DestroyWindow(w.ptr); w.ptr = nil } }
func (w *Window) Title() string { if w == nil { return "" }; return w.title }
func (w *Window) SetTitle(title string) error { w.title = title; return nil }
func (w *Window) Size() (int, int) { if w == nil { return 0, 0 }; return w.width, w.height }
func (w *Window) SetSize(width, height int) error { if w == nil || w.ptr == nil { return nil }; w.width, w.height = width, height; return nil }
func (w *Window) NativeHandle() uintptr { if w == nil { return 0 }; return uintptr(unsafe.Pointer(w.ptr)) }
func (w *Window) Flags() uint64 { if w == nil || w.ptr == nil { return 0 }; return uint64(internal.GetWindowFlags(w.ptr)) }
func (w *Window) SetResizable(resizable bool) bool {
	return w != nil && w.ptr != nil && internal.SetWindowResizable(w.ptr, resizable)
}
func (w *Window) StartTextInput() error { if w == nil || !internal.StartTextInput(w.ptr) { return nil }; return nil }
func (w *Window) StopTextInput() error { if w == nil || !internal.StopTextInput(w.ptr) { return nil }; return nil }
