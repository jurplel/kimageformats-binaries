#! /usr/bin/pwsh

$kde_vers = 'v5.89.0'

# Clone
git clone https://invent.kde.org/frameworks/kimageformats.git
cd kimageformats
git checkout $kde_vers


# Get dependencies
if ($IsWindows) {
    if ([Environment]::Is64BitOperatingSystem) {
        $env:VCPKG_DEFAULT_TRIPLET = "x64-windows"
    }
    
    & "$env:GITHUB_WORKSPACE/pwsh/buildecm.ps1" $kde_vers
    & "$env:GITHUB_WORKSPACE/pwsh/buildkarchive.ps1"
    & "$env:GITHUB_WORKSPACE/pwsh/buildopenexr.ps1"
    & "$env:VCPKG_ROOT/vcpkg.exe" install libheif libavif libjxl openexr
} else {
    brew update
    brew install nasm libheif openexr jpeg-xl

    # extra-cmake-modules isn't on linuxbrew and I can't remember why ninja is done throught apt
    if ($IsMacOS) {
        brew install ninja extra-cmake-modules karchive
    } else {
        $env:PKG_CONFIG_PATH += ":/home/linuxbrew/.linuxbrew/lib/pkgconfig"
        brew install openexr
        sudo apt-get install ninja-build
        & "$env:GITHUB_WORKSPACE/pwsh/buildecm.ps1"
        & "$env:GITHUB_WORKSPACE/pwsh/buildkarchive.ps1"
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


# Move some dependencies around
if ($IsMacOS || $IsLinux) {
    mv libavif/build/installed/libavif.dylib ./bin/
    mv libavif/build/installed/libavif.so ./bin/

    mv karchive/bin/*.dylib ./bin/
    mv karchive/bin/*.so ./bin/
} elseif ($IsWindows) {
    mv kimageformats/bin/imageformats/aom.dll kimageformats/bin/
    mv kimageformats/bin/imageformats/avif.dll kimageformats/bin/
    mv kimageformats/bin/imageformats/heif.dll kimageformats/bin/
    mv kimageformats/bin/imageformats/libde265.dll kimageformats/bin/
    mv kimageformats/bin/imageformats/libx265.dll kimageformats/bin/
}

tree