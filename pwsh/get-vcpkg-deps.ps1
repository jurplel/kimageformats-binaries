#!/usr/bin/env pwsh

# Install vcpkg if we don't already have it
if ($env:VCPKG_ROOT -eq $null) {
  git clone https://github.com/microsoft/vcpkg
  $env:VCPKG_ROOT = "$PWD/vcpkg/"
}

# Bootstrap VCPKG again
if ($IsWindows) {
    & "$env:VCPKG_ROOT/bootstrap-vcpkg.bat"
} else {
    & "$env:VCPKG_ROOT/bootstrap-vcpkg.sh"
}

# Install NASM
if ($IsWindows) {
    & "$env:GITHUB_WORKSPACE/pwsh/vcvars.ps1"
    choco install nasm
} elseif ($IsMacOS) {
    brew install nasm
} else {
    # (and bonus dependencies)
    sudo apt-get install nasm libxi-dev libgl1-mesa-dev libglu1-mesa-dev mesa-common-dev libxrandr-dev libxxf86vm-dev
}

if ($IsWindows) {
    & "$env:GITHUB_WORKSPACE\pwsh\vcvars.ps1"
    
    # Use environment variable to detect if we're building for 64-bit or 32-bit Windows 
    if ([Environment]::Is64BitOperatingSystem -and ($env:forceWin32 -ne 'true')) {
        $env:VCPKG_DEFAULT_TRIPLET = "x64-windows"
    }
} elseif ($IsMacOS) {
    # Makes things more reproducible for testing on M1 machines
    $env:VCPKG_DEFAULT_TRIPLET = "x64-osx"
}

# Get our dependencies using vcpkg!
if ($IsWindows) {
    $vcpkgexec = "vcpkg.exe"
} else {
    $vcpkgexec = "vcpkg"
}
& "$env:VCPKG_ROOT/$vcpkgexec" install --keep-going libjxl libavif openexr zlib


# No point to building libheif on mac since Qt has built-in support for HEIF on macOS. Also, this avoids CI problems.
if (-Not $IsMacOS) {
    & "$env:VCPKG_ROOT/$vcpkgexec" install libheif
}

if ($IsWindows) {
    # Windows has no problems with libraw unlike mac/linux, so we can build it here.
    & "$env:VCPKG_ROOT/$vcpkgexec" install libraw
}

# Build arm64-osx dependencies separately--we'll have to combine stuff later.
if ($env:universalBinary) {
    & "$env:VCPKG_ROOT/$vcpkgexec" install --keep-going libjxl:arm64-osx libavif:arm64-osx openexr:arm64-osx zlib:arm64-osx
}



