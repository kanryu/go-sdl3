param(
    [string]$SDLInclude = "third_party/SDL/include",
    [string]$Output = "internal/sdl/sdl.go.hike"
)

$ErrorActionPreference = "Stop"

$clang = Get-Command clang.exe -ErrorAction Stop
$header = Join-Path $SDLInclude "SDL3/SDL.h"
$text = (& $clang.Source -E -P -x c -I $SDLInclude $header 2>$null | Out-String)
$text = [regex]::Replace($text, "\s+", " ")

function Convert-Type([string]$type) {
    $type = $type.Trim()
    if ($type -eq "void") { return $null }
    if ($type -match "\*\s*$") {
        if ($type -match "char\s*\*") { return "cstring" }
        return "*byte"
    }
    switch -Regex ($type) {
        "^(bool|_Bool)$" { return "bool" }
        "^(float)$" { return "float32" }
        "^(double)$" { return "float64" }
        "^(Sint8|int8_t|signed char)$" { return "int8" }
        "^(Uint8|uint8_t|unsigned char)$" { return "uint8" }
        "^(Sint16|int16_t|short|signed short)$" { return "int16" }
        "^(Uint16|uint16_t|unsigned short)$" { return "uint16" }
        "^(Sint32|int32_t)$" { return "int32" }
        "^(Uint32|uint32_t)$" { return "uint32" }
        "^(Sint64|int64_t|long long|signed long long)$" { return "int64" }
        "^(Uint64|uint64_t|unsigned long long)$" { return "uint64" }
        "^(size_t|SDL_.*ID)$" { return "uint64" }
        "^(int|signed int)$" { return "int" }
        "^(unsigned int)$" { return "uint32" }
        default { return "int" }
    }
}

function Split-Parameters([string]$parameters) {
    if ([string]::IsNullOrWhiteSpace($parameters) -or $parameters.Trim() -eq "void") { return @() }
    return @($parameters -split ",")
}

$declarations = [System.Collections.Generic.List[string]]::new()
$pattern = "extern\s+(?<return>.+?)\s+SDL_(?<name>[A-Za-z0-9_]+)\s*\((?<params>.*?)\)\s*;"
foreach ($match in [regex]::Matches($text, $pattern)) {
    $name = "SDL_" + $match.Groups["name"].Value
    $return = Convert-Type $match.Groups["return"].Value
    $args = [System.Collections.Generic.List[string]]::new()
    $index = 0
    foreach ($parameter in (Split-Parameters $match.Groups["params"].Value)) {
        $parameter = $parameter.Trim()
        if ($parameter -match "^\.\.\.") { continue }
        $parameter = [regex]::Replace($parameter, "\s+", " ")
        $parameter = [regex]::Replace($parameter, "[A-Za-z_][A-Za-z0-9_]*$", "")
        $type = Convert-Type $parameter
        if ($null -ne $type) {
            $args.Add("arg$index $type")
            $index++
        }
    }
    $signature = "extern func $name(" + ($args -join ", ") + ")"
    if ($null -ne $return) { $signature += " $return" }
    $declarations.Add($signature)
}

$declarations = @($declarations | Sort-Object -Unique)
$lines = [System.Collections.Generic.List[string]]::new()
$lines.Add("// Code generated from SDL3 headers. DO NOT EDIT.")
$lines.Add("package sdl")
$lines.Add("")
foreach ($declaration in $declarations) {
    $lines.Add([string]$declaration)
}

$parent = Split-Path -Parent $Output
New-Item -ItemType Directory -Force $parent | Out-Null
[IO.File]::WriteAllLines((Join-Path (Get-Location) $Output), $lines)
Write-Output ("Generated {0} SDL3 declarations in {1}" -f $declarations.Count, $Output)
