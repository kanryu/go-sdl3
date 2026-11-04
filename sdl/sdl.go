package sdl

import (
	"runtime"
	"unsafe"

	internal "github.com/kanryu/go-sdl3/internal/sdl"
)

const (
	InitVideo              = 0x00000020
	WindowResizable uint64 = 0x0000000000000020
)

const (
	EventQuit              = internal.EventQuit
	EventWindowShown       = internal.EventWindowShown
	EventWindowHidden      = internal.EventWindowHidden
	EventWindowExposed     = internal.EventWindowExposed
	EventWindowMoved       = internal.EventWindowMoved
	EventWindowResized     = internal.EventWindowResized
	EventWindowPixelSize   = internal.EventWindowPixelSize
	EventWindowMetalResize = internal.EventWindowMetalResize
	EventWindowMinimized   = internal.EventWindowMinimized
	EventWindowMaximized   = internal.EventWindowMaximized
	EventWindowRestored    = internal.EventWindowRestored
	EventWindowMouseEnter  = internal.EventWindowMouseEnter
	EventWindowMouseLeave  = internal.EventWindowMouseLeave
	EventWindowFocusGained = internal.EventWindowFocusGained
	EventWindowFocusLost   = internal.EventWindowFocusLost
	EventWindowClose       = internal.EventWindowClose
	EventKeyDown           = internal.EventKeyDown
	EventKeyUp             = internal.EventKeyUp
	EventTextEditing       = internal.EventTextEditing
	EventTextInput         = internal.EventTextInput
	EventMouseMotion       = internal.EventMouseMotion
	EventMouseButtonDown   = internal.EventMouseButtonDown
	EventMouseButtonUp     = internal.EventMouseButtonUp
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
	ptr           *byte
	title         string
	width, height int
}

func Init(flags int) bool                { return internal.Init(flags) }
func Quit()                              { internal.Quit() }
func GetError() string                   { return internal.GetError() }
func PollEventTyped() (EventValue, bool) { return internal.PollEventTyped() }
func KeyName(key int32) string           { return internal.KeyName(key) }

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
	if window == nil {
		return nil
	}
	titleValue := ""
	if value, ok := title.(string); ok {
		titleValue = value
	}
	return &Window{ptr: window, title: titleValue, width: width, height: height}
}

func PollEvent(event *byte) bool { return internal.PollEvent(event) }
func DestroyWindow(window *Window) {
	if window != nil {
		window.Destroy()
	}
}
func StartTextInput(window *Window) bool { return window != nil && internal.StartTextInput(window.ptr) }
func StopTextInput(window *Window) bool  { return window != nil && internal.StopTextInput(window.ptr) }

func (w *Window) Destroy() {
	if w != nil && w.ptr != nil {
		internal.DestroyWindow(w.ptr)
		w.ptr = nil
	}
}
func (w *Window) Title() string {
	if w == nil {
		return ""
	}
	return w.title
}
func (w *Window) SetTitle(title string) error { w.title = title; return nil }
func (w *Window) Size() (int, int) {
	if w == nil {
		return 0, 0
	}
	return w.width, w.height
}
func (w *Window) SetSize(width, height int) error {
	if w == nil || w.ptr == nil {
		return nil
	}
	w.width, w.height = width, height
	return nil
}
func (w *Window) NativeHandle() uintptr {
	if w == nil {
		return 0
	}
	return uintptr(unsafe.Pointer(w.ptr))
}
func (w *Window) Flags() uint64 {
	if w == nil || w.ptr == nil {
		return 0
	}
	return uint64(internal.GetWindowFlags(w.ptr))
}
func (w *Window) SetResizable(resizable bool) bool {
	return w != nil && w.ptr != nil && internal.SetWindowResizable(w.ptr, resizable)
}
func (w *Window) StartTextInput() error {
	if w == nil || !internal.StartTextInput(w.ptr) {
		return nil
	}
	return nil
}
func (w *Window) StopTextInput() error {
	if w == nil || !internal.StopTextInput(w.ptr) {
		return nil
	}
	return nil
}

// Renderer is SDL3's GPU-backed 2D renderer and its managed backbuffer.
type Renderer struct {
	ptr *byte
}

type PointF struct {
	X, Y float32
}

// Vertex is the layout expected by SDL_RenderGeometry.
type Vertex struct {
	PositionX float32
	PositionY float32
	ColorR    float32
	ColorG    float32
	ColorB    float32
	ColorA    float32
	TexCoordX float32
	TexCoordY float32
}

// CreateRenderer creates an SDL renderer. Use driver "gpu" to explicitly
// select SDL's GPU-backed renderer.
func CreateRenderer(window *Window, driver string) *Renderer {
	if window == nil || window.ptr == nil {
		return nil
	}
	name := append([]byte(driver), 0)
	renderer := internal.CreateRenderer(window.ptr, &name[0])
	runtime.KeepAlive(name)
	if renderer == nil {
		return nil
	}
	return &Renderer{ptr: renderer}
}

// CreateRendererFromWindowHandle creates an SDL renderer for a native SDL
// window handle obtained from Window.NativeHandle.
func CreateRendererFromWindowHandle(handle uintptr) *Renderer {
	if handle == 0 {
		return nil
	}
	renderer := internal.CreateRenderer((*byte)(unsafe.Pointer(handle)), nil)
	if renderer == nil {
		return nil
	}
	return &Renderer{ptr: renderer}
}

// WrapRendererHandle wraps a renderer created by SDL_CreateGPURenderer or
// another SDL API.
func WrapRendererHandle(handle uintptr) *Renderer {
	if handle == 0 {
		return nil
	}
	return &Renderer{ptr: (*byte)(unsafe.Pointer(handle))}
}

func (r *Renderer) SetDrawColor(red, green, blue, alpha uint8) bool {
	return r != nil && r.ptr != nil && internal.SetRenderDrawColor(r.ptr, red, green, blue, alpha)
}

func (r *Renderer) Clear() bool { return r != nil && r.ptr != nil && internal.RenderClear(r.ptr) }

func (r *Renderer) Line(x1, y1, x2, y2 float32) bool {
	return r != nil && r.ptr != nil && internal.RenderLine(r.ptr, x1, y1, x2, y2)
}

func (r *Renderer) Lines(points []PointF) bool {
	if r == nil || r.ptr == nil || len(points) == 0 {
		return false
	}
	return internal.RenderLines(r.ptr, (*byte)(unsafe.Pointer(&points[0])), len(points))
}

func (r *Renderer) Geometry(vertices []Vertex) bool {
	if r == nil || r.ptr == nil || len(vertices) == 0 {
		return false
	}
	return internal.RenderGeometry(r.ptr, nil, (*byte)(unsafe.Pointer(&vertices[0])), len(vertices), nil, 0)
}

func (r *Renderer) Present() bool { return r != nil && r.ptr != nil && internal.RenderPresent(r.ptr) }

func (r *Renderer) Handle() uintptr {
	if r == nil || r.ptr == nil {
		return 0
	}
	return uintptr(unsafe.Pointer(r.ptr))
}

func (r *Renderer) Destroy() {
	if r != nil && r.ptr != nil {
		internal.DestroyRenderer(r.ptr)
		r.ptr = nil
	}
}
