#! /usr/bin/pwsh

# Clone
git clone https://invent.kde.org/frameworks/kimageformats.git
cd kimageformats
git checkout $(git describe --abbrev=0).substring(0, 7)


# Get dependencies
if ($IsWindows) {
    if ([Environment]::Is64BitOperatingSystem) {
        $env:VCPKG_DEFAULT_TRIPLET = "x64-windows"
    }
    
    & "$env:GITHUB_WORKSPACE/pwsh/buildecm.ps1"
    & "$env:GITHUB_WORKSPACE/pwsh/buildkarchive.ps1"
    & "$env:VCPKG_ROOT/vcpkg.exe" install libheif libavif
} else {
    brew update
    brew install nasm openexr libheif karchive

    # extra-cmake-modules isn't on linuxbrew and I can't remember why ninja is done throught apt
    if ($IsMacOS) {
        brew install ninja extra-cmake-modules
    } else {
        sudo apt-get install ninja-build
        & "$env:GITHUB_WORKSPACE/pwsh/buildecm.ps1"
    }

    # Build libavif dependency

    & "$env:GITHUB_WORKSPACE/pwsh/buildlibavif.ps1"

    $env:libavif_DIR = "libavif/build/installed/usr/local/lib/cmake/libavif/"
}


# Build

# vcvars on windows
if ($IsWindows) {
    & "$env:GITHUB_WORKSPACE/pwsh/vcvars.ps1"
}


cmake -G Ninja -DCMAKE_BUILD_TYPE=Release -DKIMAGEFORMATS_HEIF=ON -DCMAKE_TOOLCHAIN_FILE="$env:VCPKG_ROOT\scripts\buildsystems\vcpkg.cmake" .

ninja
ninja install