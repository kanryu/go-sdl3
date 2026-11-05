# Vulkan triangle

This example uses SDL_GPU with the Vulkan backend explicitly selected. It
requires a Vulkan-capable system and uses checked-in SPIR-V shaders.

To rebuild the shaders with `glslangValidator`:

```sh
glslangValidator -V --target-env vulkan1.0 -S vert -o shaders/triangle.vert.spv shaders/triangle.vert
glslangValidator -V --target-env vulkan1.0 -S frag -o shaders/triangle.frag.spv shaders/triangle.frag
```

Run from this directory with `go run .`.
