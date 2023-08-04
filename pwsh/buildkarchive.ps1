#! /usr/bin/pwsh

# Clone
git clone https://invent.kde.org/frameworks/karchive.git
cd karchive
git checkout $args[0]

if ($IsWindows) {
    if ([Environment]::Is64BitOperatingSystem -and ($env:forceWin32 -ne 'true')) {
        $env:VCPKG_DEFAULT_TRIPLET = "x64-windows"
    }
    
    git -C "$env:VCPKG_ROOT" pull
    & "$env:VCPKG_ROOT/vcpkg.exe" install zlib
}

# vcvars on windows
if ($IsWindows) {   
    & "$env:GITHUB_WORKSPACE\pwsh\vcvars.ps1"
}

# don't use homebrew zlib/zstd so we can make universal binary
if ($IsMacOS) {
    brew uninstall --ignore-dependencies zlib
    brew uninstall --ignore-dependencies zstd
}

# Build
if ((qmake --version -split '\n')[1][17] -eq '6') {
    cmake -G Ninja -DCMAKE_INSTALL_PREFIX="$PWD/installed/" -DCMAKE_BUILD_TYPE=Release -DCMAKE_OSX_ARCHITECTURES="x86_64;arm64" -DBUILD_WITH_QT6=ON .
} else {
    cmake -G Ninja -DCMAKE_INSTALL_PREFIX="$PWD/installed/" -DCMAKE_BUILD_TYPE=Release -DCMAKE_TOOLCHAIN_FILE="$env:VCPKG_ROOT\scripts\buildsystems\vcpkg.cmake" .
}

ninja
ninja install

try {
    cd installed/

    $env:KF5Archive_DIR = Split-Path -Path (Get-Childitem -Include KF5ArchiveConfig.cmake -Recurse -ErrorAction SilentlyContinue)[0]

    cd ../
} catch { "Failed to cd installed/ after karchive (build probably failed D:)"}

cd ../
