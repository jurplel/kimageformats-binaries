#! /usr/bin/pwsh

# Clone
git clone https://invent.kde.org/frameworks/karchive.git
cd karchive
git checkout $(git describe --abbrev=0).substring(0, 7)

if ($IsWindows) {
    if ([Environment]::Is64BitOperatingSystem) {
        $env:VCPKG_DEFAULT_TRIPLET = "x64-windows"
    }
    
    & "$env:VCPKG_ROOT/vcpkg.exe" install zlib
}

# vcvars on windows
if ($IsWindows) {
    & "$env:GITHUB_WORKSPACE\pwsh\vcvars.ps1"
}

# Build
cmake -G Ninja -DCMAKE_INSTALL_PREFIX="$PWD\installed\" -DCMAKE_BUILD_TYPE=Release -DCMAKE_TOOLCHAIN_FILE="$env:VCPKG_ROOT\scripts\buildsystems\vcpkg.cmake" .

ninja
ninja install

if ($IsWindows) {
    $env:KF5Archive_DIR = "$PWD\installed\lib\cmake\KF5Archive"
} else {
    $env:KF5Archive_DIR = "$PWD/installed/lib/x86_64-linux-gnu/cmake/KF5Archive"
}

cd ../