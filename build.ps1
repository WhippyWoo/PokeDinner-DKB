# Builds the emulator. Run from this folder:
#   powershell -ExecutionPolicy Bypass -File .\build.ps1          (build; sets up the first time)
#   powershell -ExecutionPolicy Bypass -File .\build.ps1 -Clean   (delete build\ first, start over)
param([switch]$Clean)
$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot

# 1. Find the newest Visual Studio with C++ tools and load its 64-bit compiler.
$vswhere = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
$vsPath = & $vswhere -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath
if (-not $vsPath) { throw "No Visual Studio with C++ tools found." }
Write-Host "Using Visual Studio at $vsPath"
& "$vsPath\Common7\Tools\Launch-VsDevShell.ps1" -Arch amd64 -HostArch amd64 -SkipAutomaticLocation | Out-Null

# 2. Use Visual Studio's own CMake and Ninja (ahead of devkitPro's).
$tools = "$vsPath\Common7\IDE\CommonExtensions\Microsoft\CMake"
$env:Path = "$tools\CMake\bin;$tools\Ninja;" + $env:Path

# 3. Find patch.exe (used to patch downloaded libraries).
$patch = @("C:\Program Files\Git\usr\bin\patch.exe", "C:\devkitPro\msys2\usr\bin\patch.exe") |
    Where-Object { Test-Path $_ } | Select-Object -First 1
if (-not $patch) { throw "patch.exe not found: install Git for Windows." }

# 4. Configure (first time, or after -Clean), then build.
if ($Clean -and (Test-Path build)) { Remove-Item -Recurse -Force build }
if (-not (Test-Path build\build.ninja)) {
    cmake -S . -B build -G Ninja -DCMAKE_BUILD_TYPE=Release -DYUZU_TESTS=OFF -DENABLE_WERROR=OFF `
        -DCMAKE_C_COMPILER=cl -DCMAKE_CXX_COMPILER=cl "-DPATCH_EXE=$patch"
    if ($LASTEXITCODE -ne 0) { throw "Configure failed." }
}
cmake --build build
if ($LASTEXITCODE -ne 0) { throw "Build failed." }
Write-Host "Done: build\bin\eglantine.exe"
