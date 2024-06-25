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
# Remove this package on macOS because it caues problems
    brew uninstall --ignore-dependencies webp # Avoid linking to homebrew stuff later
} else {
    # (and bonus dependencies)
    sudo apt-get install nasm libxi-dev libgl1-mesa-dev libglu1-mesa-dev mesa-common-dev libxrandr-dev libxxf86vm-dev
}

# Set up prefixes
if ($IsWindows) {
    & "$env:GITHUB_WORKSPACE\pwsh\vcvars.ps1"

    # Use environment variable to detect target platform
    $env:VCPKG_DEFAULT_TRIPLET =
        $env:buildArch -eq 'X86' ? 'x86-windows' :
        $env:buildArch -eq 'Arm64' ? 'arm64-windows' :
        'x64-windows'
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

# This function will be called for each triplet being built
function InstallPackages() {
    # libheif: Skip x265 on arm64-windows as it doesn't build (only needed for encoding)
    $libheif = $env:VCPKG_DEFAULT_TRIPLET -eq 'arm64-windows' ? 'libheif[core]' : 'libheif'

    & "$env:VCPKG_ROOT/$vcpkgexec" install libjxl libavif[aom] $libheif openexr zlib libraw
}

# Build for main triplet
InstallPackages

# Build arm64-osx dependencies separately--we'll have to combine stuff later.
if ($IsMacOS -and $env:buildArch -eq 'Universal') {
    $mainTriplet = $env:VCPKG_DEFAULT_TRIPLET
    $env:VCPKG_DEFAULT_TRIPLET = 'arm64-osx'

    InstallPackages

    $env:VCPKG_DEFAULT_TRIPLET = $mainTriplet
}
