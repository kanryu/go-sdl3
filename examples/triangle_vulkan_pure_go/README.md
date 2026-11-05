# Pure Go Vulkan triangle

This example creates its window with the SDL3 shared library and calls Vulkan
directly through Go Vulkan bindings. It does not import this repository's SDL
package, link the SDL static archive, use SDL_GPU, or require cgo.

It requires:

- The SDL3 shared library built by the `sdl-debug-shared` CMake configuration.
- `libvulkan.so.1` and a Vulkan driver that supports Vulkan 1.3 dynamic
  rendering and presentation to the SDL window.

Run from the repository root:

```sh
CGO_ENABLED=0 SDL3_LIBRARY=third_party/SDL/build/sdl-debug-shared/libSDL3.so \
  go run ./examples/triangle_vulkan_pure_go
```

`SDL3_LIBRARY` is optional if `libSDL3.so.0` is available to the system dynamic
loader. The example uses a fixed-size window and one frame in flight to keep
the swapchain and synchronization setup small.

The SPIR-V files are the same triangle shaders used by
[`triangle_vulkan`](../triangle_vulkan). To rebuild them:

```sh
glslangValidator -V --target-env vulkan1.0 -S vert -o shaders/triangle.vert.spv ../triangle_vulkan/shaders/triangle.vert
glslangValidator -V --target-env vulkan1.0 -S frag -o shaders/triangle.frag.spv ../triangle_vulkan/shaders/triangle.frag
```
