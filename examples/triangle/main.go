package main

import (
	"fmt"
	"log"
	"runtime"
	"time"

	"github.com/kanryu/go-sdl3/sdl"
)

func main() {
	runtime.LockOSThread()

	if !sdl.Init(sdl.InitVideo) {
		log.Fatalf("SDL_Init failed: %s", sdl.GetError())
	}
	defer sdl.Quit()

	window := sdl.CreateWindow("GoSDL3 GPU triangle", 800, 600, int(sdl.WindowResizable))
	if window == nil {
		log.Fatalf("SDL_CreateWindow failed: %s", sdl.GetError())
	}
	defer sdl.DestroyWindow(window)

	// The explicit "gpu" driver selects SDL's GPU-backed renderer.
	renderer := sdl.CreateRenderer(window, "gpu")
	if renderer == nil {
		log.Fatalf("SDL_CreateRenderer(gpu) failed: %s", sdl.GetError())
	}
	defer renderer.Destroy()

	vertices := []sdl.Vertex{
		{PositionX: 400, PositionY: 90, ColorR: 1, ColorG: 0.15, ColorB: 0.1, ColorA: 1},
		{PositionX: 160, PositionY: 510, ColorR: 0.1, ColorG: 1, ColorB: 0.2, ColorA: 1},
		{PositionX: 640, PositionY: 510, ColorR: 0.1, ColorG: 0.35, ColorB: 1, ColorA: 1},
	}

	fmt.Println("GoSDL3 GPU triangle sample started")
	for {
		for {
			event, ok := sdl.PollEventTyped()
			if !ok {
				break
			}
			switch event := event.(type) {
			case sdl.QuitEvent:
				return
			case sdl.WindowEvent:
				if event.Type == sdl.EventWindowClose {
					return
				}
			}
		}

		if !renderer.SetDrawColor(16, 20, 32, 255) || !renderer.Clear() || !renderer.Geometry(vertices) || !renderer.Present() {
			log.Fatalf("GPU triangle rendering failed: %s", sdl.GetError())
		}
		time.Sleep(time.Millisecond * 16)
	}
}
