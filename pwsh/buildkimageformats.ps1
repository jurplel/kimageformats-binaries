#!/usr/bin/env pwsh

$kde_vers = 'v5.108.0'

# Clone
git clone https://invent.kde.org/frameworks/kimageformats.git
cd kimageformats
git checkout $kde_vers



# dependencies
if ($IsWindows) {
    & "$env:GITHUB_WORKSPACE/pwsh/vcvars.ps1"
    choco install ninja pkgconfiglite
} elseif ($IsMacOS) {
    brew update
    brew install ninja
} else {
    sudo apt-get install ninja-build
}

& "$env:GITHUB_WORKSPACE/pwsh/buildecm.ps1" $kde_vers
# & "$env:GITHUB_WORKSPACE/pwsh/get-vcpkg-deps.ps1"
# don't bother building karchive on win32, doesn't work for whatever reason
# if ($env:forceWin32 -ne 'true') {
#     & "$env:GITHUB_WORKSPACE/pwsh/buildkarchive.ps1" $kde_vers
# }

# HEIF not necessary on macOS since it ships with HEIF support
if ($IsMacOS) {
    $heifOn = "OFF"
} else {
    $heifOn = "ON"
}
if ((qmake --version -split '\n')[1][17] -eq '6') {
    $qt6 = "ON"
} else {
    $qt6 = "OFF"
}

# (Try to) resolve pthread error
$env:CMAKE_CXX_FLAGS += ' -pthread'

Write-Host "Query qmake"
qmake -query

# TEMPORARY PLEASE REMOVE
cmake -G Ninja -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX="$PWD/installed" -DKIMAGEFORMATS_JXL=ON -DKIMAGEFORMATS_HEIF=$heifOn -DCMAKE_TOOLCHAIN_FILE="$env:VCPKG_ROOT/scripts/buildsystems/vcpkg.cmake" .

# Build kimageformats
cmake -G Ninja -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX="$PWD/installed" -DKIMAGEFORMATS_JXL=ON -DKIMAGEFORMATS_HEIF=$heifOn -DBUILD_WITH_QT6=$qt6 -DCMAKE_TOOLCHAIN_FILE="$env:VCPKG_ROOT/scripts/buildsystems/vcpkg.cmake" .

ninja
ninja install

# Build arm64 version as well and macos and lipo them together
if ($IsMacOS) {
    rm -rf CMakeFiles/
    rm -rf CMakeCache.txt

    cmake -G Ninja -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX="$PWD/installed_arm64" -DKIMAGEFORMATS_JXL=ON -DKIMAGEFORMATS_HEIF=$heifOn -DBUILD_WITH_QT6=$qt6 -DCMAKE_TOOLCHAIN_FILE="$env:VCPKG_ROOT/scripts/buildsystems/vcpkg.cmake" -DVCPKG_TARGET_TRIPLET="arm64-osx" -DCMAKE_OSX_ARCHITECTURES="arm64" .

    ninja
    ninja install

# Lipo stuff TODO
    mkdir -p installed_univ/

    $prefix = "installed"
    $prefix_arm = "installed_arm64/"
    $prefix_out = "installed_univ/"

    $files = Get-ChildItem "$prefix" -Recurse -Filter *.so # dylib? TODO
    foreach ($file in $files) {
        Write-Host $file
        # $name = $file.Name
        # lipo -create "$file" "$prefix2/$name" -output "universal/lib/$name"
        # lipo -info "universal/lib/$name"
        lipo -info "$file"
    }
}



# Copy stuff to output
if ($IsWindows) {
    cp karchive/bin/*.dll  bin/

    cp libjxl/installed/bin/*.dll bin/
    cp libjxl/build/third_party/brotli/*.dll bin/

    # TODO: Probably wrong
    cp libavif/build/installed/usr/local/lib/*.dll bin/

    cp openexr/installed/bin/*.dll bin/
} elseif ($IsMacOS) {
    cp karchive/bin/*.dylib  bin/

    cp libjxl/installed/lib/*.dylib  bin/

    cp libavif/build/installed/usr/local/lib/*.dylib bin/

    cp openexr/installed/lib/*.dylib  bin/
} else {
    $env:KF5LibLoc = Split-Path -Path (Get-Childitem -Include libKF5Archive.so.5 -Recurse -ErrorAction SilentlyContinue)[0]
    cp $env:KF5LibLoc/* bin/

    cp libjxl/installed/lib/*  bin/
    cp libjxl/build/third_party/brotli/* bin/

    # TODO: Possibly wrong
    cp libavif/build/installed/usr/local/lib/*.dll bin/
    cp libavif/build/installed/usr/local/lib/* bin/

    cp openexr/installed/lib/*  bin/
}
