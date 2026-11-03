module github.com/kanryu/go-sdl3

hike 1.0

package ./internal/sdl {
    target windows {
        hike-object: "none"
        link: "third_party/SDL/build/sdl-debug/libSDL3.a"
        link: "-lmingw32"
        link: "-luser32"
        link: "-lgdi32"
        link: "-lwinmm"
        link: "-limm32"
        link: "-lole32"
        link: "-loleaut32"
        link: "-luuid"
        link: "-lversion"
        link: "-lsetupapi"
        link: "-lshell32"
        link: "-lshlwapi"
        link: "-lws2_32"
    }
}
