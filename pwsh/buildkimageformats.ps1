#! /usr/bin/pwsh

$kde_vers = 'v5.90.0'

# Clone
git clone https://invent.kde.org/frameworks/kimageformats.git
cd kimageformats
git checkout $kde_vers



# dependencies
if ($IsWindows) {
    & "$env:GITHUB_WORKSPACE/pwsh/vcvars.ps1"
    choco install ninja
} elseif ($IsMacOS) {
    brew update
    brew install ninja
} else {
    sudo apt-get install ninja-build
}

& "$env:GITHUB_WORKSPACE/pwsh/buildecm.ps1" $kde_vers
& "$env:GITHUB_WORKSPACE/pwsh/buildkarchive.ps1"
& "$env:GITHUB_WORKSPACE/pwsh/buildlibjxl.ps1"
& "$env:GITHUB_WORKSPACE/pwsh/buildopenexr.ps1"

# Build kimageformats

if ((qmake --version -split '\n')[1][17] -eq '6') {
    cmake -G Ninja -DCMAKE_BUILD_TYPE=Release -DKIMAGEFORMATS_JXL=ON -DCMAKE_TOOLCHAIN_FILE="$env:VCPKG_ROOT\scripts\buildsystems\vcpkg.cmake" -DCMAKE_OSX_ARCHITECTURES="x86_64;arm64" -DBUILD_WITH_QT6=ON .
} else {
    cmake -G Ninja -DCMAKE_BUILD_TYPE=Release -DKIMAGEFORMATS_JXL=ON -DCMAKE_TOOLCHAIN_FILE="$env:VCPKG_ROOT\scripts\buildsystems\vcpkg.cmake" .
}
ninja

# Copy stuff to output
if ($IsWindows) {
    cp karchive/bin/*.dll  bin/
} elseif ($IsMacOS) {
    cp karchive/bin/libKF5Archive.dylib  bin/

    cp libjxl/installed/lib/libjxl.dylib  bin/
    cp libjxl/installed/lib/libjxl_threads.dylib  bin/

    cp openexr/installed/lib/libOpenEXR.dylib  bin/
    cp openexr/installed/lib/libImath.dylib  bin/
}