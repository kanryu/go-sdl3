param(
    [string]$SDLInclude = "third_party/SDL/include",
    [string]$Output = "internal/sdltypes/types.go.hike"
)

$ErrorActionPreference = "Stop"
$clang = Get-Command clang.exe -ErrorAction Stop
$header = Join-Path $SDLInclude "SDL3/SDL.h"
$text = (& $clang.Source -E -P -x c -I $SDLInclude $header 2>$null | Out-String)
$text = [regex]::Replace($text, "\s+", " ")

$aliases = [ordered]@{}
$opaque = [ordered]@{}
$enums = [ordered]@{}

foreach ($m in [regex]::Matches($text, "typedef\s+struct\s+(SDL_[A-Za-z0-9_]+)\s+\1\s*;")) {
    $opaque[$m.Groups[1].Value] = $true
}
foreach ($m in [regex]::Matches($text, "typedef\s+struct\s+(SDL_[A-Za-z0-9_]+)\s*\*\s*(SDL_[A-Za-z0-9_]+)\s*;")) {
    $opaque[$m.Groups[2].Value] = $true
}
foreach ($m in [regex]::Matches($text, "typedef\s+enum(?:\s+SDL_[A-Za-z0-9_]+)?\s*\{.*?\}\s*(SDL_[A-Za-z0-9_]+)\s*;")) {
    $enums[$m.Groups[1].Value] = $true
}

function Convert-Scalar([string]$type) {
    switch -Regex ($type.Trim()) {
        "^(Sint8|int8_t|signed char)$" { return "int8" }
        "^(Uint8|uint8_t|unsigned char)$" { return "uint8" }
        "^(Sint16|int16_t|short|signed short)$" { return "int16" }
        "^(Uint16|uint16_t|unsigned short)$" { return "uint16" }
        "^(Sint32|int32_t|int|signed int)$" { return "int32" }
        "^(Uint32|uint32_t|unsigned int|unsigned)$" { return "uint32" }
        "^(Sint64|int64_t|long long|signed long long)$" { return "int64" }
        "^(Uint64|uint64_t|unsigned long long|size_t|uintptr_t)$" { return "uint64" }
        "^(float)$" { return "float32" }
        "^(double)$" { return "float64" }
        "^(bool|_Bool)$" { return "bool" }
        default { return $null }
    }
}

foreach ($m in [regex]::Matches($text, "typedef\s+([^;{}]+?)\s+(SDL_[A-Za-z0-9_]+)\s*;")) {
    $goType = Convert-Scalar $m.Groups[1].Value
    if ($null -ne $goType) { $aliases[$m.Groups[2].Value] = $goType }
}

$lines = [System.Collections.Generic.List[string]]::new()
$lines.Add("// Code generated from SDL3 headers. DO NOT EDIT.")
$lines.Add("package sdltypes")
$lines.Add("")
$lines.Add("// Opaque SDL handles are represented as native pointers.")
foreach ($name in ($opaque.Keys | Sort-Object)) {
    $lines.Add("type $name = *byte")
}
$lines.Add("")
$lines.Add("// SDL enum storage types.")
foreach ($name in ($enums.Keys | Sort-Object)) {
    if (-not $opaque.Contains($name)) { $lines.Add("type $name = int32") }
}
$lines.Add("")
$lines.Add("// SDL scalar typedefs.")
foreach ($name in ($aliases.Keys | Sort-Object)) {
    if (-not $opaque.Contains($name) -and -not $enums.Contains($name)) {
        $lines.Add("type $name = $($aliases[$name])")
    }
}

$parent = Split-Path -Parent $Output
New-Item -ItemType Directory -Force $parent | Out-Null
[IO.File]::WriteAllLines((Join-Path (Get-Location) $Output), $lines)
Write-Output ("Generated {0} SDL opaque/scalar types in {1}" -f (($opaque.Count + $enums.Count + $aliases.Count)), $Output)
