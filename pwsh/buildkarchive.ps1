#! /usr/bin/pwsh

# Clone
git clone https://invent.kde.org/frameworks/karchive.git
cd karchive
git checkout $args[0]

if ($IsWindows) {
    if ([Environment]::Is64BitOperatingSystem -and ($env:forceWin32 -ne 'true')) {
        $env:VCPKG_DEFAULT_TRIPLET = "x64-windows"
    }
    # vcvars on windows
    & "$env:GITHUB_WORKSPACE\pwsh\vcvars.ps1"
}

# don't use homebrew zlib/zstd 
if ($env:universalBinary) {
    brew uninstall --ignore-dependencies zlib
    brew uninstall --ignore-dependencies zstd
}

if ((qmake --version -split '\n')[1][17] -eq '6') {
    $qt6flag = "-DBUILD_WITH_QT6=ON"
}

if ($env:universalBinary) {
    $univflag = '-DCMAKE_OSX_ARCHITECTURES="x86_64;arm64"'
}

# Build
cmake -G Ninja -DCMAKE_INSTALL_PREFIX="$PWD/installed/" -DCMAKE_BUILD_TYPE=Release $qt6flag $univflag -DCMAKE_TOOLCHAIN_FILE="$env:VCPKG_ROOT/scripts/buildsystems/vcpkg.cmake" .

ninja
ninja install

try {
    cd installed/ -ErrorAction Stop

    $env:KF5Archive_DIR = Split-Path -Path (Get-Childitem -Include KF5ArchiveConfig.cmake -Recurse -ErrorAction SilentlyContinue)[0]

    cd ../
} catch {}

cd ../
