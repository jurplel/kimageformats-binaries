#!/usr/bin/env pwsh

git clone https://github.com/AcademySoftwareFoundation/openexr.git
cd openexr
git checkout v3.1.3

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

# Build
cmake -G Ninja -DCMAKE_INSTALL_PREFIX="$PWD\installed\" -DOPENEXR_INSTALL_EXAMPLES=OFF -DOPENEXR_INSTALL_TOOLS=OFF -DBUILD_TESTING=OFF -DCMAKE_BUILD_TYPE=Release -DCMAKE_TOOLCHAIN_FILE="$env:VCPKG_ROOT\scripts\buildsystems\vcpkg.cmake" -DCMAKE_OSX_ARCHITECTURES="x86_64;arm64" .

ninja
ninja install

$env:OpenEXR_DIR = "$PWD/installed/lib/cmake/OpenEXR"
$env:Imath_DIR = "$PWD/installed/lib/cmake/Imath"

cd ../

