package main

import (
	"fmt"
	"math"
	"runtime"
	"unsafe"

	"github.com/kanryu/go-sdl3/internal/sdl"
)

const (
	initVideo              = 0x00000020
	windowResizable        = 0x00000020
	logicalLetterbox       = 2
	eventQuit              = 0x100
	alphaOpaque      uint8 = 255
)

type point struct {
	x float32
	y float32
}

func main() {
	runtime.LockOSThread()

	if !sdl.Init(initVideo) {
		panic(sdl.GetError())
	}
	defer sdl.Quit()

	title := cstring("examples/renderer/lines")
	empty := cstring("")
	window := sdl.CreateWindow(&title[0], 640, 480, windowResizable)
	if window == nil {
		panic(sdl.GetError())
	}
	defer sdl.DestroyWindow(window)

	renderer := sdl.CreateRenderer(window, &empty[0])
	if renderer == nil {
		panic(sdl.GetError())
	}
	defer sdl.DestroyRenderer(renderer)

	if !sdl.SetRenderLogicalPresentation(renderer, 640, 480, logicalLetterbox) {
		panic(sdl.GetError())
	}

	points := []point{
		{100, 354}, {220, 230}, {140, 230}, {320, 100},
		{500, 230}, {420, 230}, {540, 354}, {400, 354}, {100, 354},
	}

	var event [128]byte
	for {
		quit := false
		for sdl.PollEvent((*byte)(unsafe.Pointer(&event[0]))) {
			eventType := *(*uint32)(unsafe.Pointer(&event[0]))
			if eventType == eventQuit {
				quit = true
			}
		}
		if quit {
			return
		}

		draw(renderer, points)
	}
}

func cstring(value string) []byte {
	return append([]byte(value), 0)
}

func draw(renderer *byte, points []point) {
	if !sdl.SetRenderDrawColor(renderer, 100, 100, 100, alphaOpaque) ||
		!sdl.RenderClear(renderer) {
		panic(sdl.GetError())
	}

	if !sdl.SetRenderDrawColor(renderer, 127, 49, 32, alphaOpaque) {
		panic(sdl.GetError())
	}
	for _, line := range [][4]float32{
		{240, 450, 400, 450},
		{240, 356, 400, 356},
		{240, 356, 240, 450},
		{400, 356, 400, 450},
	} {
		if !sdl.RenderLine(renderer, line[0], line[1], line[2], line[3]) {
			panic(sdl.GetError())
		}
	}

	if !sdl.SetRenderDrawColor(renderer, 0, 255, 0, alphaOpaque) ||
		!sdl.RenderLines(renderer, (*byte)(unsafe.Pointer(&points[0])), len(points)) {
		panic(sdl.GetError())
	}

	for i := 0; i < 360; i++ {
		const size = 30.0
		const x = 320.0
		const y = 95.0 - size/2.0
		r := float64(i) * (math.Pi / 180.0)
		if !sdl.SetRenderDrawColor(renderer, uint8(sdl.Rand(256)), uint8(sdl.Rand(256)), uint8(sdl.Rand(256)), alphaOpaque) ||
			!sdl.RenderLine(renderer, float32(x), float32(y), float32(x+math.Cos(r)*size), float32(y+math.Sin(r)*size)) {
			panic(sdl.GetError())
		}
	}

	if !sdl.RenderPresent(renderer) {
		panic(fmt.Sprintf("SDL_RenderPresent: %s", sdl.GetError()))
	}
}
