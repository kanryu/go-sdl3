package main

import (
	"encoding/binary"
	"fmt"
	"log"
	"runtime"
	"time"
	"unsafe"

	"github.com/kanryu/go-sdl3/sdl"
)

const (
	sdlInitVideo              = 0x00000020
	sdlWindowResizable        = 0x0000000000000020
	sdlEventQuit              = 0x0100
	sdlEventWindowShown       = 0x0202
	sdlEventWindowHidden      = 0x0203
	sdlEventWindowExposed     = 0x0204
	sdlEventWindowMoved       = 0x0205
	sdlEventWindowResized     = 0x0206
	sdlEventWindowPixelSize   = 0x0207
	sdlEventWindowMetalResize = 0x0208
	sdlEventWindowMinimized   = 0x0209
	sdlEventWindowMaximized   = 0x020A
	sdlEventWindowRestored    = 0x020B
	sdlEventWindowMouseEnter  = 0x020C
	sdlEventWindowMouseLeave  = 0x020D
	sdlEventWindowFocusGained = 0x020E
	sdlEventWindowFocusLost   = 0x020F
	sdlEventWindowClose       = 0x0210
	sdlEventKeyDown           = 0x0300
	sdlEventKeyUp             = 0x0301
	sdlEventTextEditing       = 0x0302
	sdlEventTextInput         = 0x0303
	sdlEventMouseMotion       = 0x0400
	sdlEventMouseButtonDown   = 0x0401
	sdlEventMouseButtonUp     = 0x0402
	sdlEventMouseWheel        = 0x0403
)

const eventBufferSize = 128

func cstring(value string) *byte {
	bytes := append([]byte(value), 0)
	return &bytes[0]
}

func eventName(eventType uint32) string {
	if eventType == sdlEventQuit {
		return "QUIT"
	}
	switch eventType {
	case sdlEventWindowShown:
		return "WINDOW_SHOWN"
	case sdlEventWindowHidden:
		return "WINDOW_HIDDEN"
	case sdlEventWindowExposed:
		return "WINDOW_EXPOSED"
	case sdlEventWindowMoved:
		return "WINDOW_MOVED"
	case sdlEventWindowResized:
		return "WINDOW_RESIZED"
	case sdlEventWindowPixelSize:
		return "WINDOW_PIXEL_SIZE_CHANGED"
	case sdlEventWindowMetalResize:
		return "WINDOW_METAL_VIEW_RESIZED"
	case sdlEventWindowMinimized:
		return "WINDOW_MINIMIZED"
	case sdlEventWindowMaximized:
		return "WINDOW_MAXIMIZED"
	case sdlEventWindowRestored:
		return "WINDOW_RESTORED"
	case sdlEventWindowMouseEnter:
		return "WINDOW_MOUSE_ENTER"
	case sdlEventWindowMouseLeave:
		return "WINDOW_MOUSE_LEAVE"
	case sdlEventWindowFocusGained:
		return "WINDOW_FOCUS_GAINED"
	case sdlEventWindowFocusLost:
		return "WINDOW_FOCUS_LOST"
	case sdlEventWindowClose:
		return "WINDOW_CLOSE_REQUESTED"
	case sdlEventKeyDown:
		return "KEY_DOWN"
	case sdlEventKeyUp:
		return "KEY_UP"
	case sdlEventTextEditing:
		return "TEXT_EDITING"
	case sdlEventTextInput:
		return "TEXT_INPUT"
	case sdlEventMouseMotion:
		return "MOUSE_MOTION"
	case sdlEventMouseButtonDown:
		return "MOUSE_BUTTON_DOWN"
	case sdlEventMouseButtonUp:
		return "MOUSE_BUTTON_UP"
	case sdlEventMouseWheel:
		return "MOUSE_WHEEL"
	default:
		return "UNKNOWN"
	}
}

func readEventCString(event []byte, offset int) string {
	if offset < 0 || offset+8 > len(event) {
		return ""
	}
	ptr := *(*uintptr)(unsafe.Pointer(&event[offset]))
	if ptr == 0 {
		return ""
	}
	bytes := unsafe.Slice((*byte)(unsafe.Pointer(ptr)), 1<<20)
	for i, value := range bytes {
		if value == 0 {
			return string(bytes[:i])
		}
	}
	return ""
}

func keyLabel(keycode int32) string {
	return sdl.KeyName(keycode)
}

func printKeyboardEvent(event []byte, eventType uint32) {
	// SDL_KeyboardEvent on Windows amd64:
	// type(0), reserved(4), timestamp(8), windowID(16), which(20),
	// scancode(24), keycode(28), mod(32), raw(34), down(36), repeat(37).
	scancode := int32(binary.LittleEndian.Uint32(event[24:28]))
	keycode := int32(binary.LittleEndian.Uint32(event[28:32]))
	mod := binary.LittleEndian.Uint16(event[32:34])
	repeat := event[37] != 0
	state := "released"
	if eventType == sdlEventKeyDown {
		state = "pressed"
	}
	fmt.Printf("keyboard: %s keycode=%d key=%s scancode=%d mod=0x%04x repeat=%t\n",
		state, keycode, keyLabel(keycode), scancode, mod, repeat)
}

func main() {
	runtime.LockOSThread()

	if !sdl.Init(sdlInitVideo) {
		log.Fatalf("SDL_Init failed: %s", sdl.GetError())
	}
	defer sdl.Quit()

	window := sdl.CreateWindow(cstring("GoSDL3 Simple"), 800, 600, int(sdl.WindowResizable))
	if window == nil {
		log.Fatalf("SDL_CreateWindow failed: %s", sdl.GetError())
	}
	defer sdl.DestroyWindow(window)
	if !window.SetResizable(true) {
		log.Printf("SDL_SetWindowResizable failed: %s", sdl.GetError())
	}
	fmt.Printf("window flags: 0x%016x\n", window.Flags())
	if !sdl.StartTextInput(window) {
		log.Printf("SDL_StartTextInput failed: %s", sdl.GetError())
	}
	defer sdl.StopTextInput(window)

	fmt.Println("GoSDL3 simple window started")
	fmt.Println("Close the window or press Ctrl+C to exit.")

	event := make([]byte, eventBufferSize)
	for {
		hadEvent := false
		for sdl.PollEvent((*byte)(unsafe.Pointer(&event[0]))) {
			hadEvent = true
			eventType := binary.LittleEndian.Uint32(event[:4])
			fmt.Printf("event: %s (0x%04x)\n", eventName(eventType), eventType)
			switch eventType {
			case sdlEventKeyDown, sdlEventKeyUp:
				printKeyboardEvent(event, eventType)
			case sdlEventTextEditing, sdlEventTextInput:
				// SDL_TextInputEvent: type(0), reserved(4), timestamp(8),
				// windowID(16), alignment padding(20), text pointer(24).
				fmt.Printf("text: %q\n", readEventCString(event, 24))
			}

			if eventType == sdlEventQuit || eventType == sdlEventWindowClose {
				return
			}
		}
		if !hadEvent {
			time.Sleep(10 * time.Millisecond)
		}
	}
}
