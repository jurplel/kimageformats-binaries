#! /usr/bin/pwsh

# Clone
git clone https://invent.kde.org/frameworks/karchive.git
cd karchive
git checkout $(git describe --abbrev=0).substring(0, 7)

if ($IsWindows) {
    & "$env:VCPKG_ROOT/vcpkg.exe" install zlib
}

# vcvars on windows
if ($IsWindows) {
    & "$env:GITHUB_WORKSPACE\pwsh\vcvars.ps1"
}

# Build
cmake -G Ninja -DCMAKE_INSTALL_PREFIX="$PWD\installed\" -DCMAKE_BUILD_TYPE=Release -DCMAKE_TOOLCHAIN_FILE="$env:VCPKG_ROOT\scripts\buildsystems\vcpkg.cmake" .

ninja

if ($IsWindows) {
    $env:KF5Archive_DIR = "$PWD\installed\lib\cmake\KF5Archive"
}

cd ../