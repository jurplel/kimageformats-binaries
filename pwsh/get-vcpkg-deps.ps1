#!/usr/bin/env pwsh

using namespace System.Runtime.InteropServices

$kfGitRef = $args[0]

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
    # Uninstall this because it can result in a non-working heif plugin,
    # but it might not be present, so silence stderr
    brew uninstall --ignore-dependencies webp 2>$null
} else {
    # (and bonus dependencies)
    sudo apt-get install nasm libxi-dev libgl1-mesa-dev libglu1-mesa-dev mesa-common-dev libxrandr-dev libxxf86vm-dev
}

# Set default triplet
$hostArch = [RuntimeInformation]::OSArchitecture
if ($IsWindows) {
    $env:VCPKG_DEFAULT_TRIPLET =
        $env:buildArch -eq 'X86' ? 'x86-windows' :
        $env:buildArch -eq 'Arm64' ? 'arm64-windows' :
        $hostArch -eq [Architecture]::X64 ? 'x64-windows' :
        $null
} elseif ($IsMacOS) {
    # For universal binaries, build x64 first; arm64 will come later
    $env:VCPKG_DEFAULT_TRIPLET =
        $env:buildArch -eq 'Universal' ? 'x64-osx' :
        $hostArch -eq [Architecture]::X64 ? 'x64-osx' :
        $hostArch -eq [Architecture]::Arm64 ? 'arm64-osx' :
        $null
} elseif ($IsLinux) {
    $env:VCPKG_DEFAULT_TRIPLET =
        $hostArch -eq [Architecture]::X64 ? 'x64-linux' :
        $null
} else {
    throw 'Unsupported platform.'
}
if (-not $env:VCPKG_DEFAULT_TRIPLET) {
    throw 'Unsupported architecture.'
}

# Get our dependencies using vcpkg!
if ($IsWindows) {
    $vcpkgexec = "vcpkg.exe"
} else {
    $vcpkgexec = "vcpkg"
}

# Create overlay triplet directory
$env:VCPKG_OVERLAY_TRIPLETS = "$env:GITHUB_WORKSPACE/vcpkg-overlay-triplets"
New-Item -ItemType Directory -Path $env:VCPKG_OVERLAY_TRIPLETS -Force

# Customizes a triplet by starting with the built-in one and appending extra commands
function WriteOverlayTriplet() {
    $srcPath = "$env:VCPKG_ROOT/triplets/$env:VCPKG_DEFAULT_TRIPLET.cmake"
    $dstPath = "$env:VCPKG_OVERLAY_TRIPLETS/$env:VCPKG_DEFAULT_TRIPLET.cmake"
    Copy-Item -Path $srcPath -Destination $dstPath

    function AppendLine($value) {
        Add-Content -Path $dstPath -Value $value
    }

    # Ensure trailing newline is present
    AppendLine ''

    # Skip debug builds
    AppendLine 'set(VCPKG_BUILD_TYPE release)'

    if ($IsWindows) {
        # Workaround for https://developercommunity.visualstudio.com/t/10664660
        AppendLine 'string(APPEND VCPKG_CXX_FLAGS " -D_DISABLE_CONSTEXPR_MUTEX_CONSTRUCTOR")'
        AppendLine 'string(APPEND VCPKG_C_FLAGS " -D_DISABLE_CONSTEXPR_MUTEX_CONSTRUCTOR")'
    }
}

# Create overlay ports directory
$env:VCPKG_OVERLAY_PORTS = "$env:GITHUB_WORKSPACE/vcpkg-overlay-ports"
New-Item -ItemType Directory -Path $env:VCPKG_OVERLAY_PORTS -Force

# Customizes ports by adding them to the overlay ports directory
function WriteOverlayPorts() {
    # Remove any existing files
    Remove-Item -Path "$env:VCPKG_OVERLAY_PORTS/*" -Recurse -Force

    # OpenEXR 3.3 introduced a change that's only compatible with KDE Frameworks 6.8+
    if ($kfGitRef -like 'v5.*' -or $kfGitRef -like 'v6.[0-7].*') {
        Copy-Item -Path "$env:GITHUB_WORKSPACE/util/overlay-openexr-3.2.4" -Destination "$env:VCPKG_OVERLAY_PORTS/openexr" -Recurse
    }
}

# This function will be called for each triplet being built
function InstallPackages() {
    WriteOverlayTriplet

    WriteOverlayPorts

    & "$env:VCPKG_ROOT/$vcpkgexec" install libjxl libavif[aom] libheif openexr zlib libraw
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
