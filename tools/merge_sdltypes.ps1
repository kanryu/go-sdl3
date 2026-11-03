$ErrorActionPreference = "Stop"

$sdlHike = (Resolve-Path "internal/sdl/sdl.go.hike").Path
$typesHike = (Resolve-Path "internal/sdltypes/types.go.hike").Path
$sdlText = Get-Content $sdlHike -Raw
$typesText = Get-Content $typesHike -Raw

$typesBody = [regex]::Replace($typesText, "^\s*// Code generated[^\r\n]*\r?\n", "")
$typesBody = [regex]::Replace($typesBody, "^\s*package\s+sdltypes\s*\r?\n", "")
$typesBody = $typesBody.Trim()

if ($sdlText -notmatch "SDL3 type declarations") {
    $sdlText = $sdlText.TrimEnd() + "`r`n`r`n// SDL3 type declarations generated from the SDL3 headers.`r`n" + $typesBody + "`r`n"
    [IO.File]::WriteAllText($sdlHike, $sdlText)
}

Write-Output "Merged SDL type declarations into internal/sdl/sdl.go.hike"
