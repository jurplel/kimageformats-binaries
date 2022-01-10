git clone https://github.com/AcademySoftwareFoundation/openexr.git
cd openexr
git checkout v3.1.0

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
cmake -G Ninja -DCMAKE_INSTALL_PREFIX="$PWD\installed\" -DCMAKE_BUILD_TYPE=Release -DCMAKE_TOOLCHAIN_FILE="$env:VCPKG_ROOT\scripts\buildsystems\vcpkg.cmake" .

ninja
ninja install

if ($IsWindows) {
    $env:OpenEXR_DIR = "$PWD\installed\lib\cmake\OpenEXR"
    $env:Imath_DIR = "$PWD\installed\lib\cmake\Imath"
}

cd ../