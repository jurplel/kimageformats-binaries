#! /usr/bin/pwsh

# Clone
git clone https://invent.kde.org/frameworks/karchive.git
cd karchive
git checkout $(git describe --abbrev=0).substring(0, 7)

if ($IsWindows) {
    if ([Environment]::Is64BitOperatingSystem -and ($env:forceWin32 -ne 'true')) {
        $env:VCPKG_DEFAULT_TRIPLET = "x64-windows"
    }
    
    & "$env:VCPKG_ROOT/vcpkg.exe" install zlib
}

# vcvars on windows
if ($IsWindows) {   
    & "$env:GITHUB_WORKSPACE\pwsh\vcvars.ps1"
}

if ($IsMacOS) {
    brew uninstall zlib zstd # don't use system zlib so we can make universal binary
}

# Build
cmake -G Ninja -DCMAKE_INSTALL_PREFIX="$PWD/installed/" -DCMAKE_BUILD_TYPE=Release -DCMAKE_TOOLCHAIN_FILE="$env:VCPKG_ROOT\scripts\buildsystems\vcpkg.cmake" -DCMAKE_OSX_ARCHITECTURES="x86_64;arm64" -DBUILD_WITH_QT6=ON .

ninja
ninja install

$env:KF5Archive_DIR = "$PWD/installed/lib/cmake/KF5Archive"

cd ../