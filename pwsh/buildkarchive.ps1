#!/usr/bin/env pwsh

# Clone
git clone https://invent.kde.org/frameworks/karchive.git
cd karchive
git checkout $args[0]

# NOTE: This script assumes VCPKG_DEFAULT_TRIPLET is already set (e.g. by get-vcpkg-deps.ps1 running prior)

if ($IsWindows) {
    # vcvars on windows
    & "$env:GITHUB_WORKSPACE\pwsh\vcvars.ps1"
}

# don't use homebrew zlib/zstd 
if ($IsMacOS) {
    brew uninstall --ignore-dependencies zlib
    brew uninstall --ignore-dependencies zstd
}

if ((qmake --version -split '\n')[1][17] -eq '6') {
    $qt6flag = "-DBUILD_WITH_QT6=ON"
}

# Build
cmake -G Ninja -DCMAKE_INSTALL_PREFIX="$PWD/installed/" -DCMAKE_BUILD_TYPE=Release $qt6flag -DCMAKE_TOOLCHAIN_FILE="$env:VCPKG_ROOT/scripts/buildsystems/vcpkg.cmake" .

ninja
ninja install

# Build arm64 version as well and macos and lipo them together
if ($IsMacOS -and $env:buildArch -eq 'Universal') {
    Write-Host "Building arm64 binaries"

    rm -rf CMakeFiles/
    rm -rf CMakeCache.txt

    cmake -G Ninja -DCMAKE_INSTALL_PREFIX="$PWD/installed_arm64/" -DCMAKE_BUILD_TYPE=Release $qt6flag -DCMAKE_OSX_ARCHITECTURES="arm64" -DCMAKE_TOOLCHAIN_FILE="$env:VCPKG_ROOT/scripts/buildsystems/vcpkg.cmake" -DVCPKG_TARGET_TRIPLET="arm64-osx" .

    ninja
    ninja install
}


try {
    cd installed/ -ErrorAction Stop

    $env:KF5Archive_DIR = Split-Path -Path (Get-Childitem -Include KF5ArchiveConfig.cmake -Recurse -ErrorAction SilentlyContinue)[0]

    cd ../

    if ($IsMacOS -and $env:buildArch -eq 'Universal') {
        cd installed_arm64/ -ErrorAction Stop

        $env:KF5Archive_DIR_ARM = Split-Path -Path (Get-Childitem -Include KF5ArchiveConfig.cmake -Recurse -ErrorAction SilentlyContinue)[0]

        cd ../
    }
} catch {}

cd ../
