//go:build linux && amd64

package main

import (
	"errors"
	"fmt"
	"os"
	"path/filepath"
	"unsafe"

	"bnema.dev/purego"
)

const (
	sdlInitVideo                 = 0x00000020
	sdlWindowVulkan              = 0x0000000010000000
	sdlEventQuit                 = 0x100
	sdlEventWindowCloseRequested = 0x210
)

type sdlAPI struct {
	library uintptr

	initVideo                      func(uint32) bool
	quit                           func()
	getError                       func() *byte
	createWindow                   func(string, int32, int32, uint64) uintptr
	destroyWindow                  func(uintptr)
	pollEvent                      func(unsafe.Pointer) bool
	vulkanLoadLibrary              func(*byte) bool
	vulkanUnloadLibrary            func()
	vulkanGetInstanceExtensions    func(*uint32) **byte
	vulkanGetVkGetInstanceProcAddr func() uintptr
	vulkanCreateSurface            func(uintptr, uintptr, uintptr, *uint64) bool
	getWindowSizeInPixels          func(uintptr, *int32, *int32) bool
}

func loadSDL() (*sdlAPI, error) {
	candidates := []string{
		os.Getenv("SDL3_LIBRARY"),
		filepath.Join("third_party", "SDL", "build", "sdl-debug-shared", "libSDL3.so"),
		filepath.Join("..", "..", "third_party", "SDL", "build", "sdl-debug-shared", "libSDL3.so"),
		"libSDL3.so.0",
		"libSDL3.so",
	}

	var (
		library uintptr
		errs    []error
	)
	for _, path := range candidates {
		if path == "" {
			continue
		}
		handle, err := purego.Dlopen(path, purego.RTLD_NOW|purego.RTLD_GLOBAL)
		if err == nil {
			library = handle
			break
		}
		errs = append(errs, fmt.Errorf("%s: %w", path, err))
	}
	if library == 0 {
		return nil, fmt.Errorf("load SDL3 shared library: %w", errors.Join(errs...))
	}

	api := &sdlAPI{library: library}
	functions := []struct {
		name string
		ptr  any
	}{
		{"SDL_Init", &api.initVideo},
		{"SDL_Quit", &api.quit},
		{"SDL_GetError", &api.getError},
		{"SDL_CreateWindow", &api.createWindow},
		{"SDL_DestroyWindow", &api.destroyWindow},
		{"SDL_PollEvent", &api.pollEvent},
		{"SDL_Vulkan_LoadLibrary", &api.vulkanLoadLibrary},
		{"SDL_Vulkan_UnloadLibrary", &api.vulkanUnloadLibrary},
		{"SDL_Vulkan_GetInstanceExtensions", &api.vulkanGetInstanceExtensions},
		{"SDL_Vulkan_GetVkGetInstanceProcAddr", &api.vulkanGetVkGetInstanceProcAddr},
		{"SDL_Vulkan_CreateSurface", &api.vulkanCreateSurface},
		{"SDL_GetWindowSizeInPixels", &api.getWindowSizeInPixels},
	}
	for _, function := range functions {
		address, err := purego.Dlsym(library, function.name)
		if err != nil {
			_ = purego.Dlclose(library)
			return nil, fmt.Errorf("resolve %s: %w", function.name, err)
		}
		purego.RegisterFunc(function.ptr, address)
	}
	return api, nil
}

func (s *sdlAPI) errorString() string {
	if message := s.getError(); message != nil {
		return cString(message)
	}
	return "unknown SDL error"
}

func (s *sdlAPI) close() {
	if s.library != 0 {
		if err := purego.Dlclose(s.library); err != nil {
			fmt.Fprintf(os.Stderr, "close SDL3 shared library: %v\n", err)
		}
		s.library = 0
	}
}

func cString(value *byte) string {
	if value == nil {
		return ""
	}
	length := 0
	for *(*byte)(unsafe.Add(unsafe.Pointer(value), length)) != 0 {
		length++
	}
	return unsafe.String(value, length)
}
