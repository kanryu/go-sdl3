package main

import (
	"fmt"
	"log"
	"runtime"
	"time"

	"github.com/kanryu/go-sdl3/internal/sdl"
)

func cstring(value string) *byte {
	bytes := append([]byte(value), 0)
	return &bytes[0]
}

func main() {
	runtime.LockOSThread()

	if !sdl.Init(0x00000020) {
		log.Fatalf("SDL_Init failed: %s", sdl.GetError())
	}
	defer sdl.Quit()

	window := sdl.CreateWindow(cstring("GoSDL3 Typed Events"), 600, 400, 0)
	if window == nil {
		log.Fatalf("SDL_CreateWindow failed: %s", sdl.GetError())
	}
	defer sdl.DestroyWindow(window)
	if !sdl.StartTextInput(window) {
		log.Printf("SDL_StartTextInput failed: %s", sdl.GetError())
	}
	defer sdl.StopTextInput(window)

	fmt.Println("GoSDL3 typed event example started")
	for {
		event, ok := sdl.PollEventTyped()
		if !ok {
			time.Sleep(10 * time.Millisecond)
			continue
		}

		switch event := event.(type) {
		case sdl.QuitEvent:
			fmt.Println("quit requested")
			return
		case sdl.WindowEvent:
			fmt.Printf("window event: type=0x%04x data=(%d, %d)\n", event.Type, event.Data1, event.Data2)
			if event.Type == sdl.EventWindowClose {
				return
			}
		case sdl.KeyboardEvent:
			fmt.Printf("keyboard event: type=0x%04x keycode=%d key=%s scancode=%d down=%t repeat=%t\n", event.Type, event.Keycode, event.KeyName, event.Scancode, event.Down, event.Repeat)
		case sdl.TextEditingEvent:
			fmt.Printf("text editing: %q (start=%d length=%d)\n", event.Text, event.Start, event.Length)
		case sdl.TextInputEvent:
			fmt.Printf("text input: %q\n", event.Text)
		case sdl.MouseMotionEvent:
			fmt.Printf("mouse motion: (%0.1f, %0.1f)\n", event.X, event.Y)
		case sdl.MouseButtonEvent:
			fmt.Printf("mouse button: button=%d down=%t clicks=%d\n", event.Button, event.Down, event.Clicks)
		case sdl.MouseWheelEvent:
			fmt.Printf("mouse wheel: (%0.1f, %0.1f)\n", event.X, event.Y)
		case sdl.UnknownEvent:
			fmt.Printf("unknown event: type=0x%04x\n", event.Type)
		}
	}
}
