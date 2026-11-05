//go:build linux && amd64

package main

import (
	_ "embed"
	"errors"
	"fmt"
	"log"
	"runtime"
	"unsafe"
)

//go:embed shaders/triangle.vert.spv
var vertexShader []byte

//go:embed shaders/triangle.frag.spv
var fragmentShader []byte

func main() {
	if err := run(); err != nil {
		log.Fatal(err)
	}
}

func run() (err error) {
	runtime.LockOSThread()

	sdl, err := loadSDL()
	if err != nil {
		return err
	}
	defer sdl.close()

	if !sdl.initVideo(sdlInitVideo) {
		return fmt.Errorf("SDL_Init failed: %s", sdl.errorString())
	}
	defer sdl.quit()

	if !sdl.vulkanLoadLibrary(nil) {
		return fmt.Errorf("SDL_Vulkan_LoadLibrary failed: %s", sdl.errorString())
	}
	defer sdl.vulkanUnloadLibrary()

	window := sdl.createWindow("Go SDL3 direct Vulkan triangle", 800, 600, sdlWindowVulkan)
	if window == 0 {
		return fmt.Errorf("SDL_CreateWindow failed: %s", sdl.errorString())
	}
	defer sdl.destroyWindow(window)

	extensionCount := uint32(0)
	extensionArray := sdl.vulkanGetInstanceExtensions(&extensionCount)
	if extensionArray == nil || extensionCount == 0 {
		return fmt.Errorf("SDL_Vulkan_GetInstanceExtensions failed: %s", sdl.errorString())
	}
	extensions := unsafe.Slice(extensionArray, int(extensionCount))
	if sdl.vulkanGetVkGetInstanceProcAddr() == 0 {
		return fmt.Errorf("SDL_Vulkan_GetVkGetInstanceProcAddr failed: %s", sdl.errorString())
	}

	renderer, err := newRenderer(sdl, window, extensions, vertexShader, fragmentShader)
	if err != nil {
		return err
	}
	defer func() {
		if closeErr := renderer.close(); closeErr != nil {
			err = errors.Join(err, closeErr)
		}
	}()

	fmt.Println("Direct Vulkan triangle sample started (pure Go, SDL3 shared library)")
	var event [16]uint64
	for {
		for sdl.pollEvent(unsafe.Pointer(&event[0])) {
			eventType := uint32(event[0])
			if eventType == sdlEventQuit || eventType == sdlEventWindowCloseRequested {
				return nil
			}
		}

		if err := renderer.drawFrame(); err != nil {
			return err
		}
	}
}
