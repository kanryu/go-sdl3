# go-sdl3

`go-sdl3` provides Go bindings for [SDL3](https://www.libsdl.org/), the
Simple DirectMedia Layer. It exposes SDL's low-level access to windows,
audio, keyboard, mouse, gamepads, events, and graphics hardware through Go.

The bindings are generated from SDL3's C API with Go-Hike and integrate SDL's
native static library through the Go package build.

## About SDL3

[Simple DirectMedia Layer](https://www.libsdl.org/) is a cross-platform
development library designed to provide low-level access to audio, keyboard,
mouse, joystick, and graphics hardware. It is used by video playback software,
emulators, and games.

SDL officially supports Windows, macOS, Linux, iOS, Android, Xbox,
PlayStation, Nintendo Switch, and other platforms. SDL is written in C and
works natively with C++.

The SDL source is included as a Git submodule at
[`third_party/SDL`](third_party/SDL). SDL is distributed under the zlib
license; see the SDL submodule's license files for the original terms.

For more information, see the [SDL wiki](https://wiki.libsdl.org/) and the
[SDL issue tracker](https://github.com/libsdl-org/SDL/issues).

## Event handling by event ID

The original raw event API remains available through `PollEvent`. It writes an
SDL event into a caller-provided 128-byte buffer, allowing applications to
dispatch directly from the SDL event ID.

```go
var raw [128]byte
for sdl.PollEvent(&raw[0]) {
    eventType := binary.LittleEndian.Uint32(raw[:4])
    switch eventType {
    case sdl.EventKeyDown:
        // Handle a key press.
    case sdl.EventWindowClose:
        return
    }
}
```

## Typed events

`PollEventTyped` provides Go event values that can be dispatched with a type
switch while preserving the raw `PollEvent` API.

```go
event, ok := sdl.PollEventTyped()
if ok {
    switch event := event.(type) {
    case sdl.WindowEvent:
        log.Printf("window event: type=0x%04x", event.Type)
    case sdl.KeyboardEvent:
        log.Printf("key=%s code=%d", event.KeyName, event.Keycode)
    case sdl.TextInputEvent:
        log.Printf("text=%q", event.Text)
    case sdl.MouseMotionEvent:
        log.Printf("mouse: %0.1f, %0.1f", event.X, event.Y)
    case sdl.QuitEvent:
        return
    case sdl.UnknownEvent:
        log.Printf("unknown event: 0x%04x", event.Type)
    }
}
```

Typed event values currently cover quit, window, keyboard, text editing,
text input, mouse motion, mouse button, and mouse wheel events. Events that are
not decoded yet are preserved as `UnknownEvent` values.

## Keyboard and IME input

Keyboard events include the SDL keycode, physical scancode, modifier state,
pressed/released state, repeat state, and an ASCII key name. Common control
keys use stable names such as `Enter`, `Tab`, `Space`, `Backspace`, `Escape`,
and `Delete`.

Enable SDL text input for a window to receive committed UTF-8 text and IME
composition events:

```go
sdl.StartTextInput(window)
defer sdl.StopTextInput(window)

switch event := event.(type) {
case sdl.TextEditingEvent:
    log.Printf("composing: %q", event.Text)
case sdl.TextInputEvent:
    log.Printf("committed: %q", event.Text)
}
```

## Building SDL3

SDL is built with CMake from the SDL source directory. The project keeps
Debug and Release outputs under `third_party/SDL/build`.

The current Windows development configuration uses the MINGW64 GCC toolchain.
MSVC, `clang-cl`, and UCRT64 GCC are not used for the SDL build.

```powershell
Set-Location third_party/SDL

cmake -S . -B build/sdl-debug -G Ninja `
  -DCMAKE_BUILD_TYPE=Debug `
  -DCMAKE_C_COMPILER=C:/local/gnu/msys64/mingw64/bin/gcc.exe `
  -DCMAKE_CXX_COMPILER=C:/local/gnu/msys64/mingw64/bin/g++.exe `
  -DSDL_SHARED=OFF -DSDL_STATIC=ON -DSDL_HIDAPI=OFF

cmake --build build/sdl-debug --target SDL3-static
```

The Release configuration uses the same options with
`-DCMAKE_BUILD_TYPE=Release` and `build/sdl-release`.

Application builds do not require compiler flags in the example command:

```powershell
go run ./examples/simple
go run ./examples/event_types
```

## Examples

- `examples/simple`: raw SDL event IDs, keyboard input, control-key names,
  window events, and IME text input.
- `examples/event_types`: typed event dispatch using a Go type switch,
  keyboard input, mouse events, and IME text input.
- `examples/lines`: SDL renderer line drawing example.

## Verification

```powershell
go test ./...
```

## License

This project is distributed under the MIT license. See [LICENSE](LICENSE).
The bundled SDL3 source remains governed by its own license terms, as
described in the SDL submodule.
